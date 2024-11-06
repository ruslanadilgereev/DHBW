// This demo app is a Flutter calendar application that allows users to view and book trainings offered by a company. The trainings are fetched from a MariaDB database.

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mysql1/mysql1.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(TrainingCalendarApp());

class TrainingCalendarApp extends StatelessWidget {
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
  @override
  _TrainingCalendarPageState createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<String>> _trainings = {};

  @override
  void initState() {
    super.initState();
    _fetchTrainings();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchTrainings() async {
    final url = Uri.parse('http://127.0.0.1:3000/api/trainings'); 

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Training Calendar'),
      ),
      body: ListView.builder(
        itemCount: 12,
        itemBuilder: (context, index) {
          DateTime firstDayOfMonth = DateTime(DateTime.now().year, index + 1, 1);
          DateTime lastDayOfMonth = DateTime(DateTime.now().year, index + 2, 0);

          return Card(
            margin: EdgeInsets.all(8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${DateFormat.MMMM().format(firstDayOfMonth)} ${firstDayOfMonth.year}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TableCalendar(
                  firstDay: firstDayOfMonth,
                  lastDay: lastDayOfMonth,
                  focusedDay: firstDayOfMonth,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                    });
                  },
                  eventLoader: (day) {
                    final normalizedDay = _normalizeDate(day);
                    return _trainings[normalizedDay] ?? [];
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
        title: Text('Training buchen'),
        content: Text('Möchten Sie "$trainingName" buchen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => _bookTraining(trainingName),
            child: Text('Buchen'),
          ),
        ],
      ),
    );
  }
}
