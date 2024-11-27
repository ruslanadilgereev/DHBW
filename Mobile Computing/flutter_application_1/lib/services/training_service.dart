import 'package:http/http.dart' as http;
import 'dart:convert';

class TrainingService {
  final String baseUrl = 'http://localhost:3001/api';
  final http.Client client;

  TrainingService({http.Client? client}) : client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> searchTrainings(String query) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/trainings/search?query=$query'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map<Map<String, dynamic>>((item) => {
                  'id': item['id'],
                  'name': item['training_name'] ??
                      item['titel'] ??
                      'Unbenannte Schulung',
                  'description': item['beschreibung'] ?? 'Keine Beschreibung',
                  'location': item['ort'] ?? 'Kein Ort angegeben',
                  'maxParticipants': item['max_teilnehmer'] ?? 0,
                  'lecturerId': item['dozent_id'] ?? 'Keine Angabe',
                  'lecturerVorname': item['dozent_vorname'] ?? '',
                  'lecturerNachname': item['dozent_nachname'] ?? '',
                  'lecturerEmail': item['dozent_email'] ?? '',
                  'bookedCount': item['booked_count'] ?? 0,
                  'dates': item['dates'] ?? [],
                  'start_date': item['start_date'] ?? '',
                  'end_date': item['end_date'] ?? '',
                  'is_multi_day': ((item['dates'] as List?)?.length ?? 0) > 1,
                })
            .toList();
      } else {
        throw Exception('Failed to search trainings');
      }
    } catch (e) {
      throw Exception('Error searching trainings: $e');
    }
  }

  Future<void> cancelTraining(String trainingId, String userId) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/trainings/$trainingId/cancel/$userId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to cancel training: ${response.body}');
    }
  }
}
