import 'package:http/http.dart' as http;
import 'dart:convert';

class Lecturer {
  final int? id;
  final String vorname;
  final String nachname;
  final String email;

  Lecturer({
    this.id,
    required this.vorname,
    required this.nachname,
    required this.email,
  });

  String get fullName => '$vorname $nachname';

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    return Lecturer(
      id: json['id'],
      vorname: json['vorname'],
      nachname: json['nachname'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vorname': vorname,
      'nachname': nachname,
      'email': email,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lecturer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          vorname == other.vorname &&
          nachname == other.nachname &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, vorname, nachname, email);
}

class LecturerService {
  static const String baseUrl = 'http://localhost:3001/api';  

  Future<List<Lecturer>> getLecturers() async {
    try {
      final endpoints = [
        '/dozenten',
        '/dozent',
        '/lecturer',
        '/lecturers'
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse(baseUrl + endpoint),
            headers: {'Content-Type': 'application/json'},
          );
          
          print('Trying endpoint $endpoint - Status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            return data.map((json) => Lecturer.fromJson(json)).toList();
          }
        } catch (e) {
          print('Error with endpoint $endpoint: $e');
        }
      }
      throw Exception('Failed to load lecturers: No working endpoint found');
    } catch (e) {
      print('Detailed error: $e');
      throw Exception('Error fetching lecturers: $e');
    }
  }

  Future<Lecturer> createLecturer(String vorname, String nachname, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/dozenten'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vorname': vorname,
          'nachname': nachname,
          'email': email,
        }),
      );

      if (response.statusCode == 201) {
        return Lecturer.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['details'] ?? 'Failed to create lecturer');
      }
    } catch (e) {
      throw Exception('Failed to create lecturer: $e');
    }
  }
}
