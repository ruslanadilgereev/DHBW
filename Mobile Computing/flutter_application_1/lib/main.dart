// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeService = ThemeService(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider.value(value: themeService),
      ],
      child: const TrainingCalendarApp(),
    ),
  );
}

class TrainingCalendarApp extends StatelessWidget {
  const TrainingCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Training Calendar',
          theme: themeService.currentTheme,
          // Füge die Lokalisierungsdelegates und unterstützten Sprachen hinzu
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('de', 'DE'), // Deutsch
          ],
          initialRoute: '/welcome',
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/': (context) => const MainWrapper(),
            '/register': (context) => const RegistrationScreen(),
            '/login': (context) => LoginScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated) {
          return const HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
