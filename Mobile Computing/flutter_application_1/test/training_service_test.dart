import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_application_1/services/training_service.dart';
import 'dart:convert';

@GenerateNiceMocks([MockSpec<http.Client>()])
import 'training_service_test.mocks.dart';

void main() {
  group('TrainingService Tests', () {
    late TrainingService trainingService;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient();
      trainingService = TrainingService(client: mockHttpClient);
    });

    test('searchTrainings returns list of trainings when successful', () async {
      // Arrange
      final mockResponse = [
        {
          'id': 1,
          'training_name': 'Flutter Basics',
          'beschreibung': 'Learn Flutter basics',
          'ort': 'Online',
          'max_teilnehmer': 20,
          'dozent_id': '1',
          'dozent_vorname': 'John',
          'dozent_nachname': 'Doe',
          'dozent_email': 'john@example.com',
          'booked_count': 5,
          'dates': ['2024-01-01'],
          'start_date': '2024-01-01',
          'end_date': '2024-01-01'
        }
      ];

      when(mockHttpClient.get(any)).thenAnswer(
          (_) async => http.Response(json.encode(mockResponse), 200));

      // Act
      final result = await trainingService.searchTrainings('Flutter');

      // Assert
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, 1);
      expect(result.first['name'], 'Flutter Basics');
      expect(result.first['maxParticipants'], 20);
    });

    test('searchTrainings throws exception on error', () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response('Server error', 500));

      // Act & Assert
      expect(trainingService.searchTrainings('Flutter'), throwsException);
    });

    test('searchTrainings handles empty response correctly', () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response('[]', 200));

      // Act
      final result = await trainingService.searchTrainings('NonExistent');

      // Assert
      expect(result, isEmpty);
    });

    test('searchTrainings handles malformed response', () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response('invalid json', 200));

      // Act & Assert
      expect(trainingService.searchTrainings('Flutter'), throwsException);
    });

    test('searchTrainings properly formats training data', () async {
      // Arrange
      final mockResponse = [
        {
          'id': 1,
          'training_name': null, // Test null handling
          'titel': 'Flutter Advanced',
          'beschreibung': null,
          'ort': null,
          'max_teilnehmer': null,
          'dozent_id': null,
          'dates': null
        }
      ];

      when(mockHttpClient.get(any)).thenAnswer(
          (_) async => http.Response(json.encode(mockResponse), 200));

      // Act
      final result = await trainingService.searchTrainings('Flutter');

      // Assert
      expect(result.first['name'], 'Flutter Advanced');
      expect(result.first['description'], 'Keine Beschreibung');
      expect(result.first['location'], 'Kein Ort angegeben');
      expect(result.first['maxParticipants'], 0);
      expect(result.first['lecturerId'], 'Keine Angabe');
    });
  });
}
