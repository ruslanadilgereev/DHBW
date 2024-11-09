// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registration_screen.dart'; // Importiere die RegistrationScreen

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: TrainingCalendarApp(),
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
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
        '/register': (context) => RegistrationScreen(),
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
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
