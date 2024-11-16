import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  _TrainingCalendarPageState createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final Map<DateTime, List<Map<String, dynamic>>> _trainings = {};

  @override
  void initState() {
    super.initState();
    _fetchTrainings();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchTrainings() async {
    final url = Uri.parse('http://localhost:3001/api/trainings'); 

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _trainings.clear();
          for (var item in data) {
            DateTime rawDate = DateTime.parse(item['date']).toLocal();
            final trainingDate = _normalizeDate(rawDate);
            final trainingName = item['training_name'].toString();
            final trainingId = item['id'];
            final trainingInfo = {'id': trainingId, 'name': trainingName};

            _trainings.putIfAbsent(trainingDate, () => []).add(trainingInfo);
          }
        });
      } else {
        print('Failed to load trainings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching trainings: $e');
    }
  }

  void _bookTraining(int trainingId, String trainingName) async {
    int userId = Provider.of<AuthService>(context, listen: false).userId;

    final url = Uri.parse('http://localhost:3001/api/bookings');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'training_id': trainingId,
        }),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Training "$trainingName" gebucht!')),
        );
      } else {
        final data = json.decode(response.body);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Fehler beim Buchen des Trainings')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Buchen des Trainings: $e')),
      );
    }
  }

  void _showBookingDialog(int trainingId, String trainingName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Training buchen'),
        content: Text('Möchten Sie "$trainingName" buchen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => _bookTraining(trainingId, trainingName),
            child: const Text('Buchen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> trainingsForSelectedDay =
        _trainings[_normalizeDate(_selectedDay)] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(DateTime.now().year - 1, 1, 1),
            lastDay: DateTime(DateTime.now().year + 1, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              final normalizedDay = _normalizeDate(day);
              return _trainings[normalizedDay]?.map((e) => e['name']).toList() ?? [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: trainingsForSelectedDay.isEmpty
                ? const Center(child: Text('Keine Trainings für diesen Tag.'))
                : ListView.builder(
                    itemCount: trainingsForSelectedDay.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> training = trainingsForSelectedDay[index];
                      String trainingName = training['name'];
                      int trainingId = training['id'];
                      return ListTile(
                        title: Text(trainingName),
                        trailing: ElevatedButton(
                          child: const Text('Buchen'),
                          onPressed: () => _showBookingDialog(trainingId, trainingName),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
