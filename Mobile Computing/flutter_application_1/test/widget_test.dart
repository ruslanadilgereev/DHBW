// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Initialize SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final themeService = ThemeService(prefs);
    final authService = AuthService();

    // Wrap the app with necessary providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider.value(value: authService),
        ],
        child: const TrainingCalendarApp(),
      ),
    );

    // Verify that the app widget is present
    expect(find.byType(TrainingCalendarApp), findsOneWidget);
  });
}
