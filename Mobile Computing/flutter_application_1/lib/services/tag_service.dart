import 'dart:convert';
import 'package:http/http.dart' as http;

class Tag {
  final int id;
  final String name;
  final DateTime createTime;

  Tag({
    required this.id,
    required this.name,
    required this.createTime,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      createTime: DateTime.parse(json['create_time']),
    );
  }
}

class TagService {
  static const String baseUrl = 'http://localhost:3001/api';

  Future<List<Tag>> searchTags(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tags/search?q=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Tag.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching tags: $e');
      return [];
    }
  }

  Future<List<Tag>> getAllTags() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tags'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Tag.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching all tags: $e');
      return [];
    }
  }

  Future<Tag?> createTag(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tags'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 201 || response.statusCode == 409) {
        final data = json.decode(response.body);
        return Tag.fromJson({
          'id': data['id'],
          'name': name,
          'create_time': DateTime.now().toIso8601String(),
        });
      }
      return null;
    } catch (e) {
      print('Error creating tag: $e');
      return null;
    }
  }
}
