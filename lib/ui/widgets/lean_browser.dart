import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Navegador do WaxClub para logins e páginas de terceiros (Discogs, nuvens do S5 e os próximos
/// plugins). A página ocupa a tela inteira; em cima, só uma barra fina com voltar, avançar, recarregar
/// e fechar (volta para onde o usuário estava no app). Sem barra de endereço. Enquanto ele está aberto,
/// as barras do Android ficam escondidas (aparecem ao deslizar a borda), para nenhum botão da página
/// ficar embaixo delas.
class LeanBrowser extends StatefulWidget {
  final Uri url;

  /// Chamado antes de abrir cada endereço: `true` quando o app tratou o endereço (ex.: retorno do login)
  /// e a página não deve abrir.
  final bool Function(String url)? interceptNavigation;

  /// Página terminou de carregar (ex.: ler o token na página).
  final FutureOr<void> Function(WebViewController web, String url)? onPageFinished;

  /// O navegador foi criado (para quem precisa rodar scripts nele depois).
  final void Function(WebViewController web)? onCreated;

  /// Faixa de aviso/erro logo abaixo da barra (opcional).
  final Widget? banner;

  /// Painel embaixo da página (ex.: campo de colar o token), só quando não for nulo.
  final Widget? bottom;

  /// Mostra a linha de progresso (ex.: conectando a conta).
  final bool busy;

  /// Botão fechar: padrão volta para a tela anterior com `false` (nada conectado).
  final VoidCallback? onClose;

  const LeanBrowser({
    super.key,
    required this.url,
    this.interceptNavigation,
    this.onPageFinished,
    this.onCreated,
    this.banner,
    this.bottom,
    this.busy = false,
    this.onClose,
  });

  @override
  State<LeanBrowser> createState() => _LeanBrowserState();
}

class _LeanBrowserState extends State<LeanBrowser> {
  late final WebViewController _web;
  bool _loading = true;
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
          _refreshHistory();
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _loading = false);
          _refreshHistory();
          widget.onPageFinished?.call(_web, url);
        },
        onNavigationRequest: (request) =>
            (widget.interceptNavigation?.call(request.url) ?? false) ? NavigationDecision.prevent : NavigationDecision.navigate,
      ))
      ..loadRequest(widget.url);
    widget.onCreated?.call(_web);
  }

  @override
  void dispose() {
    // Volta as barras do Android como no resto do app
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    final back = await _web.canGoBack();
    final forward = await _web.canGoForward();
    if (mounted && (back != _canBack || forward != _canForward)) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _close() => widget.onClose != null ? widget.onClose!() : Navigator.of(context).pop(false);

  Widget _tool(IconData icon, String tip, VoidCallback? onTap) => IconButton(
        icon: Icon(icon, size: 22),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        color: AppTheme.cream,
        disabledColor: Colors.white24,
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // Voltar do Android: volta uma página; na primeira, fecha
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else if (mounted) {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 40,
                color: AppTheme.surface,
                child: Row(
                  children: [
                    _tool(Icons.arrow_back_rounded, l10n.back, _canBack ? () => _web.goBack() : null),
                    _tool(Icons.arrow_forward_rounded, l10n.browserForward, _canForward ? () => _web.goForward() : null),
                    _tool(Icons.refresh_rounded, l10n.reload, () => _web.reload()),
                    const Spacer(),
                    _tool(Icons.close_rounded, l10n.close, _close),
                  ],
                ),
              ),
              SizedBox(
                height: 2,
                child: (_loading || widget.busy)
                    ? const LinearProgressIndicator(minHeight: 2, color: AppTheme.orange, backgroundColor: Colors.transparent)
                    : null,
              ),
              if (widget.banner != null) widget.banner!,
              Expanded(child: WebViewWidget(controller: _web)),
              if (widget.bottom != null) widget.bottom!,
            ],
          ),
        ),
      ),
    );
  }
}
