// screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginScreen({super.key});

  void _login(BuildContext context) async {
    try {
      await Provider.of<AuthService>(context, listen: false).login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      // After successful login, pop back to previous screen
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Fehler anzeigen
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _navigateToRegistration(BuildContext context) {
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmeldung'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-Mail'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Passwort'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Anmelden'),
              onPressed: () => _login(context),
            ),
            TextButton(
              child: const Text('Noch kein Konto? Registrieren'),
              onPressed: () => _navigateToRegistration(context),
            ),
          ],
        ),
      ),
    );
  }
}
