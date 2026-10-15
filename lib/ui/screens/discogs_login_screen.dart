import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/retro_text.dart';
import '../../l10n/l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/discogs/discogs_auth_service.dart';
import '../../services/discogs/discogs_config.dart';
import '../theme/app_theme.dart';
import '../widgets/lean_browser.dart';

/// Tela de login do Discogs no navegador do app ([LeanBrowser]). Retorna `true` quando a conta foi
/// conectada e guardada.
///
/// Com as chaves do app cadastradas ([DiscogsConfig.hasAppKeys]): login OAuth na própria página do
/// Discogs, e o retorno é capturado automaticamente. Sem elas: abre a página da conta, e o token pessoal
/// é lido da página; o campo de colar só aparece se a leitura não der certo.
class DiscogsLoginScreen extends StatefulWidget {
  final DiscogsAuthService auth;
  const DiscogsLoginScreen({super.key, required this.auth});

  @override
  State<DiscogsLoginScreen> createState() => _DiscogsLoginScreenState();
}

class _DiscogsLoginScreenState extends State<DiscogsLoginScreen> {
  WebViewController? _web;
  DiscogsRequestToken? _requestToken;
  final TextEditingController _tokenField = TextEditingController();
  Uri? _url;
  int _attempt = 0; // tentar de novo recria o navegador
  bool _busy = false;
  String? _error;

  bool get _oauth => widget.auth.supportsOAuthLogin;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _tokenField.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _url = null;
      _attempt++;
    });
    try {
      String url = DiscogsConfig.personalTokenPage;
      if (_oauth) {
        _requestToken = await widget.auth.requestToken();
        url = _requestToken!.authorizeUrl;
      }
      if (mounted) setState(() => _url = Uri.parse(url));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', '') /* l10n-ignore */);
    }
  }

  /// Retorno do login OAuth: o app conclui e a página não abre.
  bool _intercept(String url) {
    final verifier = DiscogsAuthService.verifierFromCallback(url);
    if (verifier != null) {
      _finishOAuth(verifier);
      return true;
    }
    if (url.startsWith(DiscogsConfig.callbackUrl)) {
      // Retorno sem verificador: o usuário recusou a autorização
      Navigator.of(context).pop(false);
      return true;
    }
    return false;
  }

  Future<void> _finishOAuth(String verifier) async {
    if (_busy || _requestToken == null) return;
    setState(() => _busy = true);
    try {
      await widget.auth.completeOAuth(_requestToken!, verifier);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '') /* l10n-ignore */;
        });
      }
    }
  }

  /// As instruções de gerar o token já foram mostradas nesta tela (não repete a cada recarga).
  bool _helpShown = false;

  /// Campo de colar o token: escondido enquanto a captura automática pode resolver.
  bool _showPastePanel = false;

  /// Depois do login, o Discogs abre a página de desenvolvedor: o app lê o token na própria página,
  /// preenche o campo e conecta sozinho. Sem token na página, explica como gerar (ou copiar e colar);
  /// quando a página recarrega com o token novo, ele é capturado.
  Future<void> _captureTokenFromPage(String url) async {
    final web = _web;
    if (web == null || _busy || !Uri.parse(url).path.startsWith(Uri.parse(DiscogsConfig.personalTokenPage).path)) return;
    String text;
    try {
      // O Discogs mostra o token em <code><span class="select-all">…</span></code>, depois de "Token atual:";
      // sem esse elemento (página mudou), lê o texto visível inteiro
      final raw = await web.runJavaScriptReturningResult(
        "(function(){var s=document.querySelector('code .select-all');" // l10n-ignore
        "if(s&&s.textContent.trim())return 'Token: '+s.textContent.trim();" // l10n-ignore
        "var t=document.body?document.body.innerText:'';" // l10n-ignore
        "document.querySelectorAll('input,textarea,code').forEach(function(e){t+='\\n'+(e.value||e.textContent||'');});" // l10n-ignore
        'return t;})()', // l10n-ignore
      );
      text = raw is String && raw.startsWith('"') ? (jsonDecode(raw) as String) : raw.toString();
    } catch (e) {
      debugPrint('[DiscogsLogin] Não foi possível ler a página: $e');
      return;
    }
    if (!mounted) return;
    final token = DiscogsAuthService.tokenFromPageText(text);
    if (token != null) {
      _tokenField.text = token;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.discogsTokenCaptured, style: const TextStyle(color: Colors.white)),
      ));
      await _savePersonalToken();
      return;
    }
    if (_helpShown) return;
    _helpShown = true;
    setState(() => _showPastePanel = true); // captura não deu: o campo de colar aparece
    // Mostra onde tocar: rola até o aceite dos termos e destaca a caixa e o botão de gerar
    // (o aceite é do usuário; o app não marca a caixa por ele)
    try {
      await web.runJavaScript(
        "(function(){var c=document.getElementById('token_api_tos_checkbox');" // l10n-ignore
        "var b=document.getElementById('generate_token_button');" // l10n-ignore
        "if(c){c.scrollIntoView({block:'center'});c.parentElement.style.outline='3px solid #f28c28';" // l10n-ignore
        "c.parentElement.style.borderRadius='6px';}" // l10n-ignore
        "if(b){b.style.outline='3px solid #f28c28';}})()", // l10n-ignore
      );
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: RetroText(l10n.discogsTokenHelpTitle, fontSize: 24, depth: 2, maxLines: 2),
        content: Text(l10n.discogsTokenHelpBody, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
      ),
    );
  }

  Future<void> _savePersonalToken() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.loginWithPersonalToken(_tokenField.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _showPastePanel = true;
          _error = e.toString().replaceFirst('Exception: ', '') /* l10n-ignore */;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _error == null
        ? null
        : Container(
            width: double.infinity,
            color: Colors.red.withValues(alpha: 0.18),
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                TextButton(onPressed: _start, child: Text(l10n.tryAgain)),
              ],
            ),
          );
    final url = _url;
    if (url == null) {
      // Preparando o login (OAuth pede um token ao Discogs antes de abrir a página)
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(children: [
            if (banner != null) banner,
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.cream))),
          ]),
        ),
      );
    }
    return LeanBrowser(
      key: ValueKey(_attempt),
      url: url,
      busy: _busy,
      interceptNavigation: _intercept,
      onCreated: (web) => _web = web,
      onPageFinished: (_, pageUrl) => _oauth ? null : _captureTokenFromPage(pageUrl),
      banner: banner,
      bottom: (!_oauth && _showPastePanel) ? _personalTokenPanel() : null,
    );
  }

  /// Sem chaves do app e sem captura automática: o usuário copia o token da página e cola aqui.
  Widget _personalTokenPanel() {
    return SafeArea(
      top: false,
      child: Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.discogsTokenHint,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenField,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.discogsTokenField,
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.carveLight),
                      ),
                    ),
                    onSubmitted: (_) => _savePersonalToken(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy ? null : _savePersonalToken,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.cream, foregroundColor: Colors.black),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
