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
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController companyController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    companyController = TextEditingController();
    phoneController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    companyController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String _role = 'teilnehmer'; // Standardmäßig 'teilnehmer'

  void _register(BuildContext context) async {
    try {
      await Provider.of<AuthService>(context, listen: false).register(
        emailController.text,
        passwordController.text,
        _role,
        firstNameController.text,
        lastNameController.text,
        companyController.text,
        phoneController.text,
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Vorname'),
              ),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Nachname'),
              ),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Unternehmen'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Telefon'),
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
      ),
    );
  }
}
