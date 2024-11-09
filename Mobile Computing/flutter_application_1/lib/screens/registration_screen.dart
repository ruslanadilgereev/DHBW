// lib/screens/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String _role = 'teilnehmer'; // Standardmäßig 'teilnehmer'

  void _register(BuildContext context) async {
    try {
      await Provider.of<AuthService>(context, listen: false).register(
        emailController.text,
        passwordController.text,
        _role,
      );

      // Nach erfolgreicher Registrierung zur Login-Seite zurückkehren
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrierung erfolgreich! Bitte melden Sie sich an.')),
      );
    } catch (e) {
      // Fehlerbehandlung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registrierung fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrieren'),
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
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(
                  value: 'teilnehmer',
                  child: Text('Teilnehmer'),
                ),
                DropdownMenuItem(
                  value: 'anbieter',
                  child: Text('Anbieter'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _role = value!;
                });
              },
              decoration: const InputDecoration(labelText: 'Rolle'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Registrieren'),
              onPressed: () => _register(context),
            ),
            TextButton(
              child: const Text('Bereits ein Konto? Anmelden'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
