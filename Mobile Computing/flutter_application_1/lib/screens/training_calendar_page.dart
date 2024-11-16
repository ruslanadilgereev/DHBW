import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

enum CalendarView { Jahr, Monat, Woche }

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  _TrainingCalendarPageState createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final Map<DateTime, List<Map<String, dynamic>>> _trainings = {};

  CalendarView _currentView = CalendarView.Monat;
  int _currentYear = DateTime.now().year;

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
            final trainingName = item['training_name'].toString();
            final trainingId = item['id'];
            final trainingInfo = {'id': trainingId, 'name': trainingName};

            if (item['dates'] != null && item['dates'] is List) {
              for (var dateString in item['dates']) {
                DateTime rawDate = DateTime.parse(dateString).toLocal();
                final trainingDate = _normalizeDate(rawDate);
                _trainings.putIfAbsent(trainingDate, () => []).add(trainingInfo);
              }
            }
          }
        });
      } else {
        print('Fehler beim Laden der Schulungen: ${response.statusCode}');
      }
    } catch (e) {
      print('Fehler beim Abrufen der Schulungen: $e');
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

  Widget _buildToggleButtons() {
    return ToggleButtons(
      isSelected: [
        _currentView == CalendarView.Jahr,
        _currentView == CalendarView.Monat,
        _currentView == CalendarView.Woche,
      ],
      onPressed: (int index) {
        setState(() {
          _currentView = CalendarView.values[index];
        });
      },
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Jahr'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Monat'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Woche'),
        ),
      ],
    );
  }

  Widget _buildYearView() {
    return Column(
      children: [
        // Jahrwechsler
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _currentYear--;
                });
              },
            ),
            Text(
              '$_currentYear',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _currentYear++;
                });
              },
            ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
            itemCount: 12,
            itemBuilder: (context, index) {
              DateTime month = DateTime(_currentYear, index + 1, 1);
              return Card(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        DateFormat.MMMM('de_DE').format(month),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _buildMonthGrid(month),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    DateTime firstDayOfMonth = DateTime(month.year, month.month, 1);
    int startingWeekday = firstDayOfMonth.weekday;

    List<Widget> dayWidgets = [];

    // Leere Widgets für die Tage vor dem ersten Tag des Monats
    for (int i = 1; i < startingWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      DateTime currentDate = DateTime(month.year, month.month, day);
      List<Map<String, dynamic>> trainings =
          _trainings[_normalizeDate(currentDate)] ?? [];

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = currentDate;
              _focusedDay = currentDate;
              _currentView = CalendarView.Monat;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(1.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                Center(child: Text('$day', style: const TextStyle(fontSize: 12))),
                if (trainings.isNotEmpty)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      children: dayWidgets,
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        Expanded(
          child: TableCalendar(
            locale: 'de_DE',
            firstDay: DateTime(_currentYear - 1, 1, 1),
            lastDay: DateTime(_currentYear + 1, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _currentView == CalendarView.Monat
                ? CalendarFormat.month
                : CalendarFormat.week,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Monat',
              CalendarFormat.week: 'Woche',
            },
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
              return _trainings[normalizedDay]
                      ?.map((e) => e['name'])
                      .toList() ??
                  [];
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
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: _buildTrainingsList(),
        ),
      ],
    );
  }

  Widget _buildTrainingsList() {
    List<Map<String, dynamic>> trainingsForSelectedDay =
        _trainings[_normalizeDate(_selectedDay)] ?? [];

    return trainingsForSelectedDay.isEmpty
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
                  onPressed: () =>
                      _showBookingDialog(trainingId, trainingName),
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Kalender'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8.0),
          _buildToggleButtons(),
          const SizedBox(height: 8.0),
          Expanded(
            child: _currentView == CalendarView.Jahr
                ? _buildYearView()
                : _buildCalendarView(),
          ),
        ],
      ),
    );
  }
}
