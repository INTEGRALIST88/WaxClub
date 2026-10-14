import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud/cloud_folder.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_text.dart';

/// Login de um serviço de nuvem dentro do app (Dropbox, OneDrive — plugin S5). Retorna `true` quando a
/// conta foi conectada: o WaxClub passa a ler só a pasta do app nesse serviço.
class CloudLoginScreen extends StatefulWidget {
  final WebLoginCloudFolder folder;
  const CloudLoginScreen({super.key, required this.folder});

  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
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
          if (widget.folder.isCallback(request.url)) {
            _finish(Uri.parse(request.url));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.folder.authorizeUrl());
  }

  Future<void> _finish(Uri callback) async {
    if (_finishing) return;
    if (callback.queryParameters['error'] != null) { // l10n-ignore
      Navigator.of(context).pop(false); // o usuário recusou
      return;
    }
    setState(() => _finishing = true);
    final ok = await widget.folder.finishLogin(callback);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _finishing = false;
        _error = l10n.cloudLoginFailed(widget.folder.serviceName);
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
        title: RetroText(l10n.cloudConnect(widget.folder.serviceName), fontSize: 24, depth: 2),
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
