// services/auth_service.dart
// services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String _role = '';
  int _userId = 0;

  bool get isAuthenticated => _isAuthenticated;
  String get role => _role;
  int get userId => _userId;

  Future<void> login(String email, String password) async {
    final url = Uri.parse('http://localhost:3001/api/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // Anmeldung erfolgreich
        final data = json.decode(response.body);
        _isAuthenticated = true;
        _role = data['role'];
        _userId = data['userId'];

        // Speichere Sitzungsinformationen
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', _isAuthenticated);
        await prefs.setString('role', _role);
        await prefs.setInt('userId', _userId);

        notifyListeners();
      } else {
        // Anmeldung fehlgeschlagen
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Anmeldung fehlgeschlagen');
      }
    } catch (e) {
      _isAuthenticated = false;
      _role = '';
      _userId = 0;
      notifyListeners();
      // Fehler weitergeben, damit die UI es anzeigen kann
      rethrow;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _role = '';
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _role = prefs.getString('role') ?? '';
    notifyListeners();
  }

  Future<void> register(
    String email,
    String password,
    String role,
    String firstName,
    String lastName,
    String company,
    String phone,
  ) async {
    final response = await http.post(
      Uri.parse('http://localhost:3001/api/register'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
        'role': role,
        'first_name': firstName,
        'last_name': lastName,
        'company': company,
        'phone': phone,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Registrierung fehlgeschlagen');
    }
  }
}
