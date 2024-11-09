// screens/training_calendar_page.dart
// (Dieser Code entspricht weitgehend deinem bestehenden Code, mit einigen Verbesserungen)
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() => runApp(TrainingCalendarApp());

class TrainingCalendarApp extends StatelessWidget {
  const TrainingCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TrainingCalendarPage(),
    );
  }
}

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  _TrainingCalendarPageState createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final Map<DateTime, List<String>> _trainings = {};

  @override
  void initState() {
    super.initState();
    _fetchTrainings();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchTrainings() async {
    final url = Uri.parse('http://localhost:3000/api/trainings'); 

    try {
      print("Fetching trainings from backend...");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _trainings.clear();
          for (var item in data) {
            DateTime rawDate = DateTime.parse(item['date']).toLocal();
            final trainingDate = _normalizeDate(rawDate);
            final trainingName = item['training_name'].toString();
            _trainings.putIfAbsent(trainingDate, () => []).add(trainingName);
            print('Added training: $trainingName on $trainingDate');
          }
        });
        print("Trainings fetched successfully.");
      } else {
        print('Failed to load trainings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching trainings: $e');
    }
  }

  void _bookTraining(String trainingName) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Training "$trainingName" gebucht!')),
    );
  }

  void _showBookingDialog(String trainingName) {
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
            onPressed: () => _bookTraining(trainingName),
            child: const Text('Buchen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> trainingsForSelectedDay =
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
                _focusedDay = focusedDay; // update `_focusedDay` here as well
              });
            },
            eventLoader: (day) {
              final normalizedDay = _normalizeDate(day);
              return _trainings[normalizedDay] ?? [];
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
                      String trainingName = trainingsForSelectedDay[index];
                      return ListTile(
                        title: Text(trainingName),
                        trailing: ElevatedButton(
                          child: const Text('Buchen'),
                          onPressed: () => _showBookingDialog(trainingName),
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
