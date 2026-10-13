import 'package:flutter/material.dart';
import 'app_info.dart';
import 'package:flutter/services.dart';
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
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const WaxClubApp());
}

/// Aplicação principal WaxClub.
class WaxClubApp extends StatelessWidget {
  const WaxClubApp({super.key});

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
      home: const HomeScreen(),
    );
  }
}
