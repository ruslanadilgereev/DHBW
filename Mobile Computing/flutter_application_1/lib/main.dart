// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registration_screen.dart'; // Importiere die RegistrationScreen
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const TrainingCalendarApp(),
    ),
  );
}

class TrainingCalendarApp extends StatelessWidget {
  const TrainingCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Füge die Lokalisierungsdelegates und unterstützten Sprachen hinzu
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', 'DE'), // Deutsch
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/register': (context) => const RegistrationScreen(),
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
          return const HomeScreen(); // Entferne 'const' hier
        } else {
          return LoginScreen(); // Entferne 'const' hier
        }
      },
    );
  }
}