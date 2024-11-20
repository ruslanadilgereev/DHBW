import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../services/training_service.dart';

enum CalendarView { Jahr, Monat, Woche, Liste, Gebucht }

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  _TrainingCalendarPageState createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  final Map<DateTime, List<Map<String, dynamic>>> _trainings = {};
  List<int> _userBookedTrainingIds = [];
  final TrainingService _trainingService = TrainingService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Future<List<Map<String, dynamic>>>? _bookingsFuture;

  CalendarView _currentView = CalendarView.Monat;
  int _currentYear = DateTime.now().year;
  bool _showWeekNumbers = false;

  @override
  void initState() {
    super.initState();
    _fetchTrainings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated) {
        _bookingsFuture = _fetchUserBookings();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
            final trainingName =
                item['training_name'] ?? item['titel'] ?? 'Unbenannte Schulung';
            final trainingId = item['id'];

            // Zusätzliche Informationen abrufen
            final trainingInfo = {
              'id': trainingId,
              'name': trainingName,
              'description': item['beschreibung'] ?? 'Keine Beschreibung',
              'location': item['ort'] ?? 'Kein Ort angegeben',
              'maxParticipants': item['max_teilnehmer'] ?? 0,
              'lecturerId': item['dozent_id'] ?? 'Keine Angabe',
              'lecturerVorname': item['dozent_vorname'] ?? '',
              'lecturerNachname': item['dozent_nachname'] ?? '',
              'lecturerEmail': item['dozent_email'] ?? '',
              'bookedCount': item['booked_count'] ?? 0,
              'is_multi_day': item['is_multi_day'] ?? false,
              'start_date': item['start_date'] ?? '',
              'end_date': item['end_date'] ?? '',
              'dates': item['dates'] ?? [],
            };

            if (item['dates'] != null && item['dates'] is List) {
              for (var dateString in item['dates']) {
                DateTime rawDate = DateTime.parse(dateString).toLocal();
                final trainingDate = _normalizeDate(rawDate);
                _trainings
                    .putIfAbsent(trainingDate, () => [])
                    .add(trainingInfo);
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

  Future<List<Map<String, dynamic>>> _fetchUserBookings() async {
    int userId = Provider.of<AuthService>(context, listen: false).userId;
    final url = Uri.parse('http://localhost:3001/api/users/$userId/bookings');
    print('Fetching bookings for user $userId from $url'); // Debug print
    try {
      final response = await http.get(url);
      print('Response status: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Update the booked training IDs
        setState(() {
          _userBookedTrainingIds = data
              .map<int>((booking) => booking['training_id'] as int)
              .toList();
        });

        // Return the full training data
        return data.map<Map<String, dynamic>>((booking) {
          return {
            'id': booking['training_id'],
            'name': booking['training_name'] ?? 'Unbenannte Schulung',
            'description': booking['beschreibung'] ?? 'Keine Beschreibung',
            'location': booking['ort'] ?? 'Kein Ort angegeben',
            'maxParticipants': booking['max_teilnehmer'] ?? 0,
            'lecturerId': booking['dozent_id'] ?? 'Keine Angabe',
            'lecturerVorname': booking['dozent_vorname'] ?? '',
            'lecturerNachname': booking['dozent_nachname'] ?? '',
            'lecturerEmail': booking['dozent_email'] ?? '',
            'bookedCount': booking['booked_count'] ?? 0,
            'dates': booking['dates'] ?? [],
            'is_multi_day': booking['is_multi_day'] ?? false,
            'start_date': booking['start_date'] ?? '',
            'end_date': booking['end_date'] ?? '',
          };
        }).toList();
      } else {
        print('Fehler beim Laden der Nutzerbuchungen: ${response.statusCode}');
        throw Exception('Failed to load user bookings');
      }
    } catch (e) {
      print('Fehler beim Abrufen der Nutzerbuchungen: $e');
      throw Exception('Error: $e');
    }
  }

  Future<void> _searchTrainings(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    try {
      final results = await _trainingService.searchTrainings(query);
      setState(() {
        _isSearching = true;
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Suche: $e')),
      );
    }
  }

  Future<void> _cancelBooking(int trainingId, String trainingName) async {
    int userId = Provider.of<AuthService>(context, listen: false).userId;

    final url = Uri.parse('http://localhost:3001/api/bookings').replace(
      queryParameters: {
        'user_id': userId.toString(),
        'training_id': trainingId.toString(),
      },
    );

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _userBookedTrainingIds.remove(trainingId);
          // Reset the bookings future to trigger a refresh
          _bookingsFuture = null;
        });

        // Refresh the trainings to update the booking counts
        await _fetchTrainings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Buchung für "$trainingName" wurde storniert'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Stornieren der Buchung: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bookTraining(int trainingId, String trainingName) async {
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
        setState(() {
          _userBookedTrainingIds.add(trainingId);
          // Reset the bookings future to trigger a refresh
          _bookingsFuture = null;
        });

        // Refresh the trainings to update the booking counts
        await _fetchTrainings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Schulung "$trainingName" erfolgreich gebucht'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Fehler beim Buchen der Schulung: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Buchen der Schulung: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBookingDialog(int trainingId, String trainingName) {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Anmeldung erforderlich'),
          content: const Text(
              'Um eine Schulung zu buchen, müssen Sie sich anmelden.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Zur Anmeldung'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Training buchen'),
        content: Text('Möchten Sie das Training "$trainingName" buchen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bookTraining(trainingId, trainingName);
            },
            child: const Text('Buchen'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelConfirmationDialog(
      int trainingId, String trainingName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Buchung stornieren'),
          content: Text(
              'Möchten Sie die Buchung für "$trainingName" wirklich stornieren?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelBooking(trainingId, trainingName);
              },
              child:
                  const Text('Stornieren', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToggleButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(8.0),
        selectedColor: Colors.white,
        fillColor: Theme.of(context).primaryColor,
        isSelected: [
          _currentView == CalendarView.Jahr,
          _currentView == CalendarView.Monat,
          _currentView == CalendarView.Woche,
          _currentView == CalendarView.Liste,
          _currentView == CalendarView.Gebucht,
        ],
        onPressed: (int index) {
          setState(() {
            _currentView = CalendarView.values[index];
            if (_currentView == CalendarView.Woche) {
              _calendarFormat = CalendarFormat.week;
            } else if (_currentView == CalendarView.Monat) {
              _calendarFormat = CalendarFormat.month;
            }
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Liste'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Gebucht'),
          ),
        ],
      ),
    );
  }

  Widget _buildYearView() {
    return Column(
      children: [
        // Year selector
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = DateTime(_currentYear, index + 1);
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _buildSimpleMonthGrid(month),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSimpleMonthGrid(DateTime month) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekdayOfMonth = firstDayOfMonth.weekday;

    // Calculate the number of weeks needed
    final totalDays = firstWeekdayOfMonth - 1 + daysInMonth;
    final numberOfWeeks = (totalDays / 7).ceil();

    return Table(
      children: [
        // Days of week header
        TableRow(
          children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
              .map((day) => Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ))
              .toList(),
        ),
        // Calendar days
        for (var week = 0; week < numberOfWeeks; week++)
          TableRow(
            children: List.generate(7, (weekday) {
              final dayNumber = week * 7 + weekday - (firstWeekdayOfMonth - 2);

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  child: const Text(''),
                );
              }

              final date = DateTime(month.year, month.month, dayNumber);
              final trainingsForDay = _trainings[_normalizeDate(date)] ?? [];
              final hasTrainings = trainingsForDay.isNotEmpty;

              // Count single-day and multi-day trainings
              int singleDayCount = 0;
              Set<int> uniqueMultiDayTrainings = {};

              for (var training in trainingsForDay) {
                List<dynamic> trainingDates = training['dates'] ?? [];
                if (trainingDates.length > 1) {
                  uniqueMultiDayTrainings.add(training['id']);
                } else {
                  singleDayCount++;
                }
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = date;
                    _focusedDay = date;
                    _currentView = CalendarView.Woche;
                    _calendarFormat = CalendarFormat.week;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: weekday >= 5
                              ? Theme.of(context).brightness == Brightness.dark
                                  ? Colors.red[300]
                                  : Colors.red[700]
                              : null,
                        ),
                      ),
                      if (hasTrainings) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (uniqueMultiDayTrainings.isNotEmpty)
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.blue[300]
                                      : Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (singleDayCount > 0)
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.orange[300]
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildCalendarView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define consistent colors for single and multi-day events
    final multiDayColor = isDark ? Colors.blue[300]! : Colors.blue;
    final singleDayColor = isDark ? Colors.orange[300]! : Colors.orange;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = DateTime.now();
                    _focusedDay = DateTime.now();
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.today,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Heute',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2024, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarFormat: _currentView == CalendarView.Woche
                    ? CalendarFormat.week
                    : CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Monat',
                  CalendarFormat.week: 'Woche',
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                    _currentView = format == CalendarFormat.week
                        ? CalendarView.Woche
                        : CalendarView.Monat;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedTextStyle: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: TextStyle(
                    color: theme.colorScheme.onBackground,
                  ),
                  weekendTextStyle: TextStyle(
                    color: isDark ? Colors.red[300] : Colors.red[700],
                  ),
                  outsideTextStyle: TextStyle(
                    color: theme.colorScheme.onBackground.withOpacity(0.5),
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final normalizedDay = _normalizeDate(date);
                    final trainingsOnDay = _trainings[normalizedDay] ?? [];

                    if (trainingsOnDay.isEmpty) return const SizedBox();

                    int singleDayCount = 0;
                    Set<int> uniqueMultiDayTrainings = {};

                    for (var training in trainingsOnDay) {
                      List<dynamic> trainingDates = training['dates'] ?? [];
                      if (trainingDates.length > 1) {
                        uniqueMultiDayTrainings.add(training['id']);
                      } else {
                        singleDayCount++;
                      }
                    }

                    final multiDayCount = uniqueMultiDayTrainings.length;

                    return Positioned(
                      bottom: 1,
                      right: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (multiDayCount > 0)
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: multiDayColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$multiDayCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (singleDayCount > 0)
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: singleDayColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$singleDayCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                startingDayOfWeek: StartingDayOfWeek.monday,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTrainingsList(),
      ],
    );
  }

  Widget _buildTrainingCard(Map<String, dynamic> training,
      {bool isSearchResult = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String name = training['name'] ?? 'Unbenannte Schulung';
    final int maxParticipants = training['maxParticipants'] ?? 0;
    final int bookedCount = training['bookedCount'] ?? 0;
    final int availableSpots = maxParticipants - bookedCount;
    final bool isMultiDay = training['dates'].length > 1;
    final String startDate = training['start_date'] ?? '';
    final String endDate = training['end_date'] ?? '';
    final List<String> dates = List<String>.from(training['dates'] ?? []);
    final bool isBooked = _userBookedTrainingIds.contains(training['id']);

    // Define consistent colors
    final borderColor = isMultiDay
        ? (isDark ? Colors.blue[300]! : Colors.blue)
        : (isDark ? Colors.orange[300]! : Colors.orange);

    // Format lecturer info
    final String lecturerInfo = [
      training['lecturerVorname'] ?? '',
      training['lecturerNachname'] ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    final String lecturerEmail = training['lecturerEmail'] ?? '';

    List<DateBlock> _getDateBlocks(List<String> dates) {
      List<DateBlock> blocks = [];
      DateTime? startDate;
      DateTime? endDate;

      for (var date in dates) {
        DateTime rawDate = DateTime.parse(date).toLocal();
        if (startDate == null) {
          startDate = rawDate;
          endDate = rawDate;
        } else {
          if (rawDate.difference(endDate!).inDays == 1) {
            endDate = rawDate;
          } else {
            blocks.add(DateBlock(startDate!, endDate!));
            startDate = rawDate;
            endDate = rawDate;
          }
        }
      }

      if (startDate != null) {
        blocks.add(DateBlock(startDate, endDate!));
      }

      return blocks;
    }

    String formatDateRange() {
      if (dates.isEmpty) return 'Keine Termine';
      if (dates.length == 1) return 'Am ${_formatDate(dates[0])}';
      return 'Von ${_formatDate(startDate)}\nBis ${_formatDate(endDate)}\n${dates.length} Termine';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: isMultiDay ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: 2,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateRange(),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: availableSpots > 0
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$availableSpots/$maxParticipants Plätze',
                style: TextStyle(
                  color: availableSpots > 0
                      ? Colors.green.shade900
                      : Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Training Details Section
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lecturerInfo.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dozent: $lecturerInfo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (lecturerEmail.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.email,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Email: $lecturerEmail',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (training['location'] != null) ...[
                        if (lecturerInfo.isNotEmpty)
                          const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ort: ${training['location']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Description Section
                const SizedBox(height: 16),
                Text(
                  'Beschreibung',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  training['description'] ?? 'Keine Beschreibung verfügbar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.87),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Termine:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _getDateBlocks(dates)
                      .map((block) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${block.dates.length} Termine\nVon: ${DateFormat('dd.MM.yyyy').format(block.startDate)}\nBis: ${DateFormat('dd.MM.yyyy').format(block.endDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onBackground,
                                height: 1.5,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isBooked) ...[
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Stornieren'),
                        onPressed: () => _showCancelConfirmationDialog(
                          training['id'],
                          name,
                        ),
                      ),
                    ] else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Buchen'),
                        onPressed: availableSpots > 0
                            ? () => _showBookingDialog(
                                  training['id'],
                                  name,
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: availableSpots > 0
                              ? theme.colorScheme.primary
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Kein Datum';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return 'Ungültiges Datum';
    }
  }

  Widget _buildTrainingsList() {
    List<Map<String, dynamic>> trainingsForSelectedDay =
        _trainings[_normalizeDate(_selectedDay)] ?? [];

    // Sort trainings alphabetically by name
    trainingsForSelectedDay.sort((a, b) => (a['name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['name'] ?? '').toString().toLowerCase()));

    return trainingsForSelectedDay.isEmpty
        ? const Center(child: Text('Keine Trainings für diesen Tag.'))
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trainingsForSelectedDay.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> training = trainingsForSelectedDay[index];
              return _buildTrainingCard(training);
            },
          );
  }

  Widget _buildSearchResults() {
    if (!_isSearching) return Container();

    // Sort search results alphabetically
    _searchResults.sort((a, b) => (a['name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['name'] ?? '').toString().toLowerCase()));

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('Keine Ergebnisse gefunden.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildTrainingCard(_searchResults[index], isSearchResult: true);
      },
    );
  }

  Widget _buildListView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllTrainings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Fehler beim Laden der Schulungen: ${snapshot.error}'),
          );
        }

        final trainings = snapshot.data ?? [];

        // Sort all trainings alphabetically
        trainings.sort((a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));

        if (trainings.isEmpty) {
          return const Center(child: Text('Keine Schulungen verfügbar'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trainings.length,
          itemBuilder: (context, index) {
            final training = trainings[index];
            return _buildTrainingCard(training);
          },
        );
      },
    );
  }

  Widget _buildBookedTrainingsView() {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!authService.isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Anmeldung erforderlich',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bitte melden Sie sich an, um Ihre gebuchten Schulungen zu sehen.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Anmelden'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Registrieren'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_bookingsFuture == null) {
      _bookingsFuture = _fetchUserBookings();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Fehler beim Laden der gebuchten Schulungen:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        final bookedTrainings = snapshot.data ?? [];

        if (bookedTrainings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Sie haben noch keine Schulungen gebucht.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Schulungen durchsuchen'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentView = CalendarView.Monat;
                    });
                  },
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bookedTrainings.length,
            itemBuilder: (context, index) {
              return _buildTrainingCard(bookedTrainings[index]);
            },
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllTrainings() async {
    final url = Uri.parse('http://localhost:3001/api/trainings');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<Map<String, dynamic>>((item) {
          final List<dynamic> dates = item['dates'] ?? [];
          return {
            'id': item['id'],
            'name':
                item['training_name'] ?? item['titel'] ?? 'Unbenannte Schulung',
            'description': item['beschreibung'] ?? 'Keine Beschreibung',
            'location': item['ort'] ?? 'Kein Ort angegeben',
            'maxParticipants': item['max_teilnehmer'] ?? 0,
            'lecturerId': item['dozent_id'] ?? 'Keine Angabe',
            'lecturerVorname': item['dozent_vorname'] ?? '',
            'lecturerNachname': item['dozent_nachname'] ?? '',
            'lecturerEmail': item['dozent_email'] ?? '',
            'bookedCount': item['booked_count'] ?? 0,
            'dates': dates,
            'is_multi_day': dates.length > 1,
            'start_date': item['start_date'] ?? '',
            'end_date': item['end_date'] ?? '',
          };
        }).toList();
      } else {
        print('Error loading trainings: ${response.statusCode}');
        throw Exception('Failed to load trainings');
      }
    } catch (e) {
      print('Error fetching trainings: $e');
      throw Exception('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we're on a wider screen (web browser)
        final isWideScreen = constraints.maxWidth > 600;

        return Padding(
          // Doubled padding for web browsers
          padding: EdgeInsets.symmetric(
            horizontal: isWideScreen ? 96.0 : 0.0,
          ),
          child: Column(
            children: [
              // Search Section with elevated design
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Schulungen suchen...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).hintColor,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchTrainings('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) => _searchTrainings(value),
                  ),
                ),
              ),
              // Toggle Buttons with improved styling
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildViewButton(CalendarView.Jahr, 'Jahr', Icons.calendar_view_month),
                        _buildViewButton(CalendarView.Monat, 'Monat', Icons.calendar_today),
                        _buildViewButton(CalendarView.Woche, 'Woche', Icons.view_week),
                        _buildViewButton(CalendarView.Liste, 'Liste', Icons.view_list),
                        _buildViewButton(CalendarView.Gebucht, 'Gebucht', Icons.bookmark),
                      ],
                    ),
                  ),
                ),
              ),
              // Content area with subtle background
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          if (_isSearching)
                            _buildSearchResults()
                          else if (_currentView == CalendarView.Jahr)
                            _buildYearView()
                          else if (_currentView == CalendarView.Liste)
                            _buildListView()
                          else if (_currentView == CalendarView.Gebucht)
                            _buildBookedTrainingsView()
                          else
                            _buildCalendarView(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewButton(CalendarView view, String label, IconData icon) {
    final isSelected = _currentView == view;
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _currentView = view;
              if (view == CalendarView.Woche) {
                _calendarFormat = CalendarFormat.week;
              } else if (view == CalendarView.Monat) {
                _calendarFormat = CalendarFormat.month;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected 
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected 
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected 
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DateBlock {
  final DateTime startDate;
  final DateTime endDate;
  final List<DateTime> dates;

  DateBlock(this.startDate, this.endDate)
      : dates = List.generate(
          endDate.difference(startDate).inDays + 1,
          (index) => startDate.add(Duration(days: index)),
        );
}
