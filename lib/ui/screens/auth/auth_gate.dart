import 'package:flutter/material.dart';
import '../../../services/account/account_service.dart';
import '../../theme/app_theme.dart';
import 'auth_screens.dart';
import 'profile_form_screen.dart';

/// Porta de entrada: sem conta → login; conta sem nome de usuário/local → completar o perfil; senão, o app.
/// A sessão fica salva no aparelho, então o login só aparece de novo depois de sair da conta.
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
        if (!a.isSignedIn) return SignInScreen(account: a, googleSignIn: widget.googleSignIn);
        if (!a.account!.profileComplete) return ProfileFormScreen(account: a);
        return widget.app(context);
      },
    );
  }
}
