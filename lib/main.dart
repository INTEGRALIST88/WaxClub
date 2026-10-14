import 'package:flutter/material.dart';
import 'app_info.dart';
import 'package:flutter/services.dart';
import 'services/account/account_service.dart';
import 'services/account/google_auth.dart';
import 'ui/screens/auth/auth_gate.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'l10n/l10n.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura a barra de status e navegação do sistema para imersão Dark Mode OLED
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,),
  );

  runApp(const WaxClubApp());
}

/// Aplicação principal WaxClub. Antes do app, a conta WaxClub (login obrigatório).
class WaxClubApp extends StatefulWidget {
  /// Conta já criada (testes); sem ela, o app cria a sua.
  final AccountService? account;

  const WaxClubApp({super.key, this.account});

  @override
  State<WaxClubApp> createState() => _WaxClubAppState();
}

class _WaxClubAppState extends State<WaxClubApp> {
  late final AccountService _account = widget.account ?? (AccountService()..onSignedOut = GoogleAuth.signOut);

  @override
  void dispose() {
    if (widget.account == null) _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Motor e serviços (fora da árvore de widgets) usam o mesmo idioma da interface
      builder: (context, child) {
        L10n.update(Localizations.localeOf(context));
        return child ?? const SizedBox.shrink();
      },
      home: AuthGate(
        account: _account,
        app: (_) => HomeScreen(account: _account),
        googleSignIn: widget.account == null ? GoogleAuth.signIn : null,
      ),
    );
  }
}
