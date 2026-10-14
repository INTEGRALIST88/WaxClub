import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../services/account/account_service.dart';
import '../../../services/plugins/plugin_catalog.dart';
import '../../../services/plugins/plugin_links.dart';
import '../../theme/app_theme.dart';
import 'auth_screens.dart';
import 'profile_form_screen.dart';

/// Porta de entrada: sem conta → login; conta sem nome de usuário/local → completar o perfil; senão, o app.
/// A sessão fica salva no aparelho, então o login só aparece de novo depois de sair da conta.
/// Um plugin pedido pelo site antes do login fica guardado (aviso no alto) e é instalado depois.
class AuthGate extends StatefulWidget {
  final AccountService account;
  final Widget Function(BuildContext context) app;
  final Future<String?> Function()? googleSignIn;

  const AuthGate({super.key, required this.account, required this.app, this.googleSignIn});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.account.load();
    PluginLinks.instance.start();
  }

  /// "Entre ou crie sua conta para instalar o plugin X" acima da tela de login/cadastro.
  Widget _withPendingPlugin(Widget screen) {
    return ValueListenableBuilder<String?>(
      valueListenable: PluginLinks.instance.pending,
      builder: (context, id, _) {
        if (id == null) return screen;
        final name = PluginCatalog.builtIn.where((p) => p.id == id).map((p) => '${p.code} · ${p.name}').firstOrNull ?? id;
        return Material(
          color: AppTheme.background,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: AppTheme.orange,
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.extension, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.pluginInstallAfterSignIn(name),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: screen)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.account,
      builder: (context, _) {
        final a = widget.account;
        if (!a.isLoaded) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator(color: AppTheme.orange)),
          );
        }
        if (!a.isSignedIn) return _withPendingPlugin(SignInScreen(account: a, googleSignIn: widget.googleSignIn));
        if (!a.account!.profileComplete) return _withPendingPlugin(ProfileFormScreen(account: a));
        return widget.app(context);
      },
    );
  }
}
