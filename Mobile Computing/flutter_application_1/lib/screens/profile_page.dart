import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  
  // User data
  String _email = '';
  String _firstName = '';
  String _lastName = '';
  String _company = '';
  String _phone = '';
  String _currentPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userId;

      print('Fetching profile data for user $userId...');
      final response = await http.get(
        Uri.parse('http://localhost:3001/api/profile/$userId'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _email = data['email'] ?? '';
          _firstName = data['first_name'] ?? '';
          _lastName = data['last_name'] ?? '';
          _company = data['company'] ?? '';
          _phone = data['phone'] ?? '';
        });
      } else {
        setState(() {
          _error = 'Fehler beim Laden des Profils: ${response.body}';
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _error = 'Netzwerkfehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userId;

      final response = await http.put(
        Uri.parse('http://localhost:3001/api/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _email,
          'first_name': _firstName,
          'last_name': _lastName,
          'company': _company,
          'phone': _phone,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil erfolgreich aktualisiert')),
          );
        }
      } else {
        setState(() {
          _error = 'Fehler beim Aktualisieren des Profils: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Netzwerkfehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword != _confirmPassword) {
      setState(() {
        _error = 'Passwörter stimmen nicht überein';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'currentPassword': _currentPassword,
          'newPassword': _newPassword,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwort erfolgreich geändert')),
          );
          // Clear password fields
          setState(() {
            _currentPassword = '';
            _newPassword = '';
            _confirmPassword = '';
          });
        }
      } else {
        setState(() {
          _error = 'Fehler beim Ändern des Passworts';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Netzwerkfehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Persönliche Informationen',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _firstName,
                              decoration: const InputDecoration(
                                labelText: 'Vorname',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => _firstName = value,
                              validator: (value) =>
                                  value!.isEmpty ? 'Bitte geben Sie Ihren Vornamen ein' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _lastName,
                              decoration: const InputDecoration(
                                labelText: 'Nachname',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => _lastName = value,
                              validator: (value) =>
                                  value!.isEmpty ? 'Bitte geben Sie Ihren Nachnamen ein' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _email,
                              decoration: const InputDecoration(
                                labelText: 'E-Mail',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => _email = value,
                              validator: (value) =>
                                  value!.isEmpty ? 'Bitte geben Sie eine E-Mail ein' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _company,
                              decoration: const InputDecoration(
                                labelText: 'Firma',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => _company = value,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefon',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => _phone = value,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _updateProfile,
                              child: const Text('Profil aktualisieren'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Passwort ändern',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Aktuelles Passwort',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              onChanged: (value) => _currentPassword = value,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Neues Passwort',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              onChanged: (value) => _newPassword = value,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Neues Passwort bestätigen',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              onChanged: (value) => _confirmPassword = value,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _changePassword,
                              child: const Text('Passwort ändern'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
