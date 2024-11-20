// lib/screens/main_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'training_calendar_page.dart';
import 'manage_trainings_page.dart';
import 'training_search_delegate.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  AppBar buildAppBar(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);
    
    return AppBar(
      title: const Text('Training Calendar'),
      actions: [
        // Theme toggle button
        IconButton(
          icon: Icon(themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => themeService.toggleTheme(),
          tooltip: themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        ),
        // Search button
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            showSearch(
              context: context,
              delegate: TrainingSearchDelegate(),
            );
          },
        ),
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            // Refresh the current page
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing...')),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainWrapper()),
              );
            }
          },
        ),
        if (!authService.isAuthenticated)
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          )
        else
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await authService.logout();
              } else if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated && authService.role == 'anbieter') {
          return Scaffold(
            appBar: buildAppBar(context),
            body: const ManageTrainingsPage(),
          );
        } else {
          return Scaffold(
            appBar: buildAppBar(context),
            body: const TrainingCalendarPage(),
          );
        }
      },
    );
  }
}
