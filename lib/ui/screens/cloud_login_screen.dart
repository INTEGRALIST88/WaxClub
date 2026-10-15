import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud/cloud_folder.dart';
import '../theme/app_theme.dart';
import '../widgets/lean_browser.dart';

/// Login de um serviço de nuvem no navegador do app (Dropbox, OneDrive — plugin S5). Retorna `true`
/// quando a conta foi conectada: o WaxClub passa a ler só a pasta do app nesse serviço.
class CloudLoginScreen extends StatefulWidget {
  final WebLoginCloudFolder folder;
  const CloudLoginScreen({super.key, required this.folder});

  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  bool _finishing = false;
  String? _error;

  /// Retorno do login: o app conclui e a página não abre.
  bool _intercept(String url) {
    if (!widget.folder.isCallback(url)) return false;
    _finish(Uri.parse(url));
    return true;
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
    return LeanBrowser(
      url: widget.folder.authorizeUrl(),
      busy: _finishing,
      interceptNavigation: _intercept,
      banner: _error == null
          ? null
          : Container(
              width: double.infinity,
              color: AppTheme.rust,
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            ),
    );
  }
}
