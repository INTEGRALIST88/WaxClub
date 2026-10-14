import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../l10n/l10n.dart';
import '../../services/dropbox/dropbox_service.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_text.dart';

/// Login do Dropbox dentro do app (plugin S5). Retorna `true` quando a conta foi conectada: o WaxClub
/// passa a ler só a pasta do app (`Dropbox/Apps/WaxClub`).
class DropboxLoginScreen extends StatefulWidget {
  final DropboxService dropbox;
  const DropboxLoginScreen({super.key, required this.dropbox});

  @override
  State<DropboxLoginScreen> createState() => _DropboxLoginScreenState();
}

class _DropboxLoginScreenState extends State<DropboxLoginScreen> {
  late final WebViewController _web;
  bool _loading = true;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => mounted ? setState(() => _loading = true) : null,
        onPageFinished: (_) => mounted ? setState(() => _loading = false) : null,
        onNavigationRequest: (request) {
          if (DropboxService.isCallback(request.url)) {
            _finish(Uri.parse(request.url));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.dropbox.authorizeUrl());
  }

  Future<void> _finish(Uri callback) async {
    if (_finishing) return;
    if (callback.queryParameters['error'] != null) { // l10n-ignore
      Navigator.of(context).pop(false); // o usuário recusou
      return;
    }
    setState(() => _finishing = true);
    final ok = await widget.dropbox.finishLogin(callback);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _finishing = false;
        _error = l10n.dropboxLoginFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: RetroText(l10n.dropboxConnect, fontSize: 24, depth: 2),
      ),
      body: Column(
        children: [
          if (_loading || _finishing) const LinearProgressIndicator(color: AppTheme.orange, minHeight: 2),
          if (_error != null)
            Container(
              width: double.infinity,
              color: AppTheme.rust,
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            ),
          Expanded(child: WebViewWidget(controller: _web)),
        ],
      ),
    );
  }
}
