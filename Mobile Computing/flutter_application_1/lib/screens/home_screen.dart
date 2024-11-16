// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'training_calendar_page.dart';
import 'manage_trainings_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) {
    Provider.of<AuthService>(context, listen: false).logout();
  }

  @override
  Widget build(BuildContext context) {
    String role = Provider.of<AuthService>(context).role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Willkommen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: role == 'anbieter'
          ? const ManageTrainingsPage()
          : const TrainingCalendarPage(),
    );
  }
}
