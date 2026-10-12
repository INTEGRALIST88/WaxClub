import 'package:flutter/material.dart';
import 'app_info.dart';
import 'package:flutter/services.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

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
      home: const HomeScreen(),
    );
  }
}
