// lib/screens/manage_trainings_page.dart
import 'package:flutter/material.dart';

class ManageTrainingsPage extends StatelessWidget {
  const ManageTrainingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schulungen verwalten'),
      ),
      body: const Center(
        child: Text('Hier können Anbieter ihre Schulungen verwalten'),
      ),
    );
  }
}
