import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../services/training_service.dart';

enum CalendarView { Jahr, Monat, Woche, Liste, Gebucht }

enum SortOption {
  AlphabeticalAsc,
  AlphabeticalDesc,
  StartDateAsc,
  StartDateDesc
}

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
  final String backendUrl = 'http://localhost:3001/api';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  List<String> _allTags = [];
  List<String> _filteredTags = [];
  List<String> _selectedTags = [];
  bool _showTagSuggestions = false;
  final ScrollController _scrollController = ScrollController();
  Future<List<Map<String, dynamic>>>? _bookingsFuture;
  List<Map<String, dynamic>> _lecturers = [];
  SortOption _currentSortOption = SortOption.StartDateDesc;
  late AuthService _authService;

  CalendarView _currentView = CalendarView.Monat;
  int _currentYear = DateTime.now().year;
  final bool _showWeekNumbers = false;

  @override
  void initState() {
    super.initState();
    _tagFocusNode.addListener(() {
      setState(() {
        _showTagSuggestions = _tagFocusNode.hasFocus;
      });
    });
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && _isSearching) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
      }
    });
    _fetchTrainings();
    _fetchTags();
    _fetchLecturers();

    // Initialize auth service and add listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authService = Provider.of<AuthService>(context, listen: false);
      _authService.addListener(_handleAuthStateChange);
      if (_authService.isAuthenticated) {
        _fetchUserBookings();
      }
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    _searchController.dispose();
    _tagFocusNode.dispose();
    _scrollController.dispose();
    _authService.removeListener(_handleAuthStateChange);
    super.dispose();
  }

  void _handleAuthStateChange() {
    setState(() {
      if (!_authService.isAuthenticated) {
        // Clear user-specific data when logged out
        _userBookedTrainingIds.clear();
        _bookingsFuture = null;
        if (_currentView == CalendarView.Gebucht) {
          _currentView = CalendarView.Monat;
        }
      } else {
        // Refresh user bookings when logged in
        _fetchUserBookings();
      }
    });
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchTrainings() async {
    final url = Uri.parse('$backendUrl/trainings');
    print('Fetching trainings from $url');

    try {
      final response = await http.get(url);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Received ${data.length} trainings');

        // Create a temporary map to store the new data
        final Map<DateTime, List<Map<String, dynamic>>> newTrainings = {};

        setState(() {
          for (var item in data) {
            final trainingName =
                item['training_name'] ?? item['titel'] ?? 'Unbenannte Schulung';
            final trainingId = item['id'];
            final int bookedCount = item['booked_count'] ?? 0;

            print('Processing training: $trainingName (ID: $trainingId)');
            print('Booked count from backend: $bookedCount');
            print('Dates from backend: ${item['sessions']}');

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
              'bookedCount': bookedCount,
              'is_multi_day': item['is_multi_day'] ?? false,
              'start_date': item['gesamt_startdatum'] ?? '',
              'end_date': item['gesamt_enddatum'] ?? '',
              'dates': (item['sessions'] as List?)
                      ?.map((session) => session['datum'])
                      .toList() ??
                  [],
              'tags': item['tags'] ?? [],
              'sessions': item['sessions'] ?? [], // Add the full sessions data
            };

            print('Training info: $trainingInfo');

            if (item['sessions'] != null && item['sessions'] is List) {
              for (var session in item['sessions']) {
                String dateString = session['datum'];
                print('Processing date: $dateString');
                DateTime rawDate = DateTime.parse(dateString).toLocal();
                final trainingDate = _normalizeDate(rawDate);
                print('Normalized date: $trainingDate');
                newTrainings
                    .putIfAbsent(trainingDate, () => [])
                    .add(trainingInfo);
              }
            }
          }

          // Update the main trainings map with the new data
          _trainings.clear();
          _trainings.addAll(newTrainings);
          print('Updated trainings map with ${_trainings.length} dates');
        });
      } else {
        print('Error loading trainings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching trainings: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserBookings() async {
    if (!mounted) return [];
    try {
      final userId = _authService.userId;
      if (userId <= 0) return [];

      final response =
          await http.get(Uri.parse('$backendUrl/users/$userId/bookings'));
      if (!mounted) return [];

      if (response.statusCode == 200) {
        final bookings = json.decode(response.body) as List<dynamic>;
        if (!mounted) return [];

        setState(() {
          _userBookedTrainingIds =
              bookings.map<int>((b) => b['training_id'] as int).toList();
        });

        return bookings
            .map<Map<String, dynamic>>((b) => {
                  'id': b['training_id'], // Use training_id as the main id
                  'name': b['training_name'] ??
                      '', // Changed from 'name' to 'training_name'
                  'description': b['beschreibung'] ??
                      '', // Changed from 'description' to 'beschreibung'
                  'location':
                      b['ort'] ?? '', // Changed from 'location' to 'ort'
                  'maxParticipants': b['max_teilnehmer'] ??
                      0, // Changed from 'max_participants'
                  'bookedCount': b['booked_count'] ?? 0,
                  'dates': b['dates'] ?? [],
                  'is_multi_day': b['is_multi_day'] ?? false,
                  'start_date': b['start_date'] ?? '',
                  'end_date': b['end_date'] ?? '',
                  'tags': b['tags'] ?? [],
                  'lecturerVorname':
                      b['dozent_vorname'] ?? '', // Added lecturer info
                  'lecturerNachname': b['dozent_nachname'] ?? '',
                  'lecturerEmail': b['dozent_email'] ?? '',
                  'sessions': b['sessions'] ?? [], // Added sessions
                  'start_times': b['start_times'] ?? [], // Added start times
                  'end_times': b['end_times'] ?? [], // Added end times
                })
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching user bookings: $e');
      if (!mounted) return [];
      setState(() => _bookingsFuture = Future.error(e));
      return [];
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
        SnackBar(content: Text('Error searching trainings: $e')),
      );
    }
  }

  Future<void> _cancelBooking(int trainingId, String trainingName) async {
    int userId = Provider.of<AuthService>(context, listen: false).userId;

    final url = Uri.parse('$backendUrl/bookings').replace(
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
              content: Text('Booking for "$trainingName" was cancelled'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bookTraining(int trainingId, String trainingName) async {
    // Show confirmation dialog
    bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        bool sendEmail = true; // Default value for the checkbox
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Training buchen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Möchten Sie dieses Training wirklich buchen?'),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: sendEmail,
                        onChanged: (bool? value) {
                          setState(() {
                            sendEmail = value ?? true;
                          });
                        },
                      ),
                      Text('Bestätigungs-E-Mail senden'),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Abbrechen'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Buchen'),
                  onPressed: () {
                    Navigator.of(context).pop(sendEmail);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldProceed != null) {
      int userId = Provider.of<AuthService>(context, listen: false).userId;
      final url = Uri.parse('$backendUrl/bookings');

      try {
        print('Booking training $trainingId for user $userId');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'training_id': trainingId,
            'send_email': shouldProceed, // Add email preference to request
          }),
        );

        print('Booking response status: ${response.statusCode}');
        print('Booking response body: ${response.body}');

        if (response.statusCode == 201) {
          // Clear all cached data
          setState(() {
            _trainings.clear();
            _userBookedTrainingIds.add(trainingId);
            _bookingsFuture = null;
          });

          // Fetch fresh data
          print('Fetching fresh data after booking...');
          await _fetchTrainings();
          _bookingsFuture = _fetchUserBookings();

          // Force a rebuild of the UI
          setState(() {});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Training "$trainingName" booked successfully'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error booking training: ${response.body}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error booking training: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBookingDialog(int trainingId, String trainingName) {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login required'),
          content: const Text('You need to be logged in to book a training.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book training'),
        content: Text('Do you want to book the training "$trainingName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bookTraining(trainingId, trainingName);
            },
            child: const Text('Book'),
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
          title: const Text('Cancel booking'),
          content: Text(
              'Do you really want to cancel the booking for "$trainingName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelBooking(trainingId, trainingName);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterTrainingsByTags(
      List<Map<String, dynamic>> trainings) {
    if (_selectedTags.isEmpty) {
      return trainings;
    }

    final filtered = trainings.where((training) {
      List<String> trainingTags = List<String>.from(training['tags'] ?? []);
      final result = _selectedTags
          .every((selectedTag) => trainingTags.contains(selectedTag));
      return result;
    }).toList();

    return filtered;
  }

  int _getEventCount(DateTime day) {
    final normalizedDate = _normalizeDate(day);
    final trainingsForDay = _trainings[normalizedDate] ?? [];
    final filteredTrainings = _filterTrainingsByTags(trainingsForDay);
    return filteredTrainings.length;
  }

  Widget _buildTagFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by tags:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _allTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(tag),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
              final filteredTrainings = _filterTrainingsByTags(trainingsForDay);
              final hasTrainings = filteredTrainings.isNotEmpty;
              final hasBookedTraining = filteredTrainings.any((training) =>
                  _userBookedTrainingIds.contains(training['id']));

              // Count single-day and multi-day trainings
              int singleDayCount = 0;
              Set<int> uniqueMultiDayTrainings = {};

              for (var training in filteredTrainings) {
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
                  decoration: hasBookedTraining
                      ? BoxDecoration(
                          border: Border.all(
                            color: Colors.red,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      'Today',
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
                lastDay: DateTime.utc(2030, 12, 31), // Extended to 2030
                focusedDay: _focusedDay,
                pageAnimationEnabled: false,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
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
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedTextStyle: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                  ),
                  weekendTextStyle: TextStyle(
                    color: isDark ? Colors.red[300] : Colors.red[700],
                  ),
                  outsideTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, date, _) {
                    final normalizedDay = _normalizeDate(date);
                    final trainingsOnDay = _trainings[normalizedDay] ?? [];
                    bool hasBookedTraining = trainingsOnDay.any((training) =>
                        _userBookedTrainingIds.contains(training['id']));

                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: hasBookedTraining
                          ? BoxDecoration(
                              border: Border.all(
                                color: Colors.red,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                  selectedBuilder: (context, date, _) {
                    final normalizedDay = _normalizeDate(date);
                    final trainingsOnDay = _trainings[normalizedDay] ?? [];
                    bool hasBookedTraining = trainingsOnDay.any((training) =>
                        _userBookedTrainingIds.contains(training['id']));

                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        border: hasBookedTraining
                            ? Border.all(
                                color: Colors.red,
                                width: 2,
                              )
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  todayBuilder: (context, date, _) {
                    final normalizedDay = _normalizeDate(date);
                    final trainingsOnDay = _trainings[normalizedDay] ?? [];
                    bool hasBookedTraining = trainingsOnDay.any((training) =>
                        _userBookedTrainingIds.contains(training['id']));

                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        border: Border.all(
                          color: hasBookedTraining
                              ? Colors.red
                              : theme.colorScheme.primary,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  markerBuilder: (context, date, events) {
                    final normalizedDay = _normalizeDate(date);
                    final trainingsOnDay = _trainings[normalizedDay] ?? [];
                    // Apply tag filtering
                    final filteredTrainings =
                        _filterTrainingsByTags(trainingsOnDay);

                    if (filteredTrainings.isEmpty) return const SizedBox();

                    int singleDayCount = 0;
                    Set<int> uniqueMultiDayTrainings = {};

                    for (var training in filteredTrainings) {
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
                                  style: const TextStyle(
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
                                  style: const TextStyle(
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
                eventLoader: (day) {
                  final count = _getEventCount(day);
                  return count > 0 ? [1] : [];
                },
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
    final List<String> dates = List<String>.from(training['dates'] ?? []);
    final bool isMultiDay = dates.length > 1;
    final List<String> startTimes =
        List<String>.from(training['start_times'] ?? []);
    final List<String> endTimes =
        List<String>.from(training['end_times'] ?? []);
    final String startDate = training['start_date'] ?? '';
    final String endDate = training['end_date'] ?? '';
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

    List<DateBlock> getDateBlocks(List<String> dates) {
      List<DateBlock> blocks = [];
      DateTime? startDate;
      DateTime? endDate;

      for (var date in dates) {
        DateTime rawDate = _normalizeDate(DateTime.parse(date).toLocal());
        if (startDate == null) {
          startDate = rawDate;
          endDate = rawDate;
        } else {
          if (rawDate.difference(endDate!).inDays == 1) {
            endDate = rawDate;
          } else {
            blocks.add(DateBlock(startDate, endDate));
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
      if (dates.length == 1) {
        final date = _normalizeDate(DateTime.parse(dates[0]).toLocal());
        return 'Am ${DateFormat('dd.MM.yyyy').format(date)}';
      }
      final normalizedStartDate =
          _normalizeDate(DateTime.parse(startDate).toLocal());
      final normalizedEndDate =
          _normalizeDate(DateTime.parse(endDate).toLocal());
      return 'Von ${DateFormat('dd.MM.yyyy').format(normalizedStartDate)}\nBis ${DateFormat('dd.MM.yyyy').format(normalizedEndDate)}\n${dates.length} Termine';
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
                      color: theme.colorScheme.onSurface,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Training Details Section
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
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
                        if (lecturerInfo.isNotEmpty) const SizedBox(height: 8),
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
                  children: getDateBlocks(dates)
                      .map((block) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            child: Text(
                              '${block.dates.length} Termine\nVon: ${DateFormat('dd.MM.yyyy').format(block.startDate)}\nBis: ${DateFormat('dd.MM.yyyy').format(block.endDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                if (training['sessions'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Zeiten:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: (training['sessions'] as List).map((session) {
                      final date = DateFormat('dd.MM.yyyy').format(
                          _normalizeDate(
                              DateTime.parse(session['datum'].toString())
                                  .toLocal()));
                      final startTime =
                          session['startzeit'].toString().substring(0, 5);
                      final endTime =
                          session['endzeit'].toString().substring(0, 5);
                      return Chip(
                        label: Text('$date: $startTime - $endTime'),
                        backgroundColor: theme.colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (training['tags'] != null &&
                    (training['tags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: (training['tags'] as List)
                        .map<Widget>((tag) => Chip(
                              label: Text(tag.toString()),
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ))
                        .toList(),
                  ),
                ],
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

    // Apply tag filtering
    trainingsForSelectedDay = _filterTrainingsByTags(trainingsForSelectedDay);

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
    if (!_isSearching) return const SizedBox();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(Icons.search,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suchergebnisse für "${_searchController.text}"',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _isSearching = false;
                    _searchResults.clear();
                  });
                },
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
        if (_searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Keine Ergebnisse gefunden.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              return _buildTrainingCard(_searchResults[index],
                  isSearchResult: true);
            },
          ),
      ],
    );
  }

  Widget _buildListView() {
    if (_isSearching) {
      return _buildSearchResults();
    }

    // Get all trainings and sort them by date
    List<Map<String, dynamic>> allTrainings = [];
    _trainings.forEach((date, trainingsForDate) {
      allTrainings.addAll(trainingsForDate);
    });

    // Apply tag filtering to the full list
    allTrainings = _filterTrainingsByTags(allTrainings);

    // Deduplicate trainings based on ID
    final Map<int, Map<String, dynamic>> uniqueTrainings = {};
    for (var training in allTrainings) {
      uniqueTrainings[training['id']] = training;
    }
    allTrainings = uniqueTrainings.values.toList();

    // Sort trainings based on selected option
    switch (_currentSortOption) {
      case SortOption.AlphabeticalAsc:
        allTrainings.sort((a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));
        break;
      case SortOption.AlphabeticalDesc:
        allTrainings.sort((a, b) => (b['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((a['name'] ?? '').toString().toLowerCase()));
        break;
      case SortOption.StartDateAsc:
        allTrainings.sort((a, b) {
          final aDate = a['start_date'] != null && a['start_date'].isNotEmpty
              ? DateTime.parse(a['start_date'])
              : DateTime.parse(a['dates'][0]);
          final bDate = b['start_date'] != null && b['start_date'].isNotEmpty
              ? DateTime.parse(b['start_date'])
              : DateTime.parse(b['dates'][0]);
          return aDate.compareTo(bDate);
        });
        break;
      case SortOption.StartDateDesc:
        allTrainings.sort((a, b) {
          final aDate = a['start_date'] != null && a['start_date'].isNotEmpty
              ? DateTime.parse(a['start_date'])
              : DateTime.parse(a['dates'][0]);
          final bDate = b['start_date'] != null && b['start_date'].isNotEmpty
              ? DateTime.parse(b['start_date'])
              : DateTime.parse(b['dates'][0]);
          return bDate.compareTo(aDate);
        });
        break;
    }

    if (allTrainings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTags.isEmpty
                  ? 'Keine Schulungen verfügbar'
                  : 'Keine Schulungen mit den ausgewählten Tags gefunden',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sorting dropdown
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Sortieren nach: '),
              DropdownButton<SortOption>(
                value: _currentSortOption,
                items: [
                  DropdownMenuItem(
                    value: SortOption.StartDateDesc,
                    child: Row(
                      children: const [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 8),
                        Text('Startdatum (neueste zuerst)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: SortOption.StartDateAsc,
                    child: Row(
                      children: const [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 8),
                        Text('Startdatum (älteste zuerst)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: SortOption.AlphabeticalAsc,
                    child: Row(
                      children: const [
                        Icon(Icons.sort_by_alpha, size: 16),
                        SizedBox(width: 8),
                        Text('Alphabetisch (A-Z)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: SortOption.AlphabeticalDesc,
                    child: Row(
                      children: const [
                        Icon(Icons.sort_by_alpha, size: 16),
                        SizedBox(width: 8),
                        Text('Alphabetisch (Z-A)'),
                      ],
                    ),
                  ),
                ],
                onChanged: (SortOption? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _currentSortOption = newValue;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        // Training list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allTrainings.length,
          itemBuilder: (context, index) {
            return _buildTrainingCard(allTrainings[index]);
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllTrainings() async {
    final url = Uri.parse('$backendUrl/trainings');
    try {
      final response = await http.get(url);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
            'tags': item['tags'] ?? [],
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

  Future<void> _fetchTags() async {
    print('Starting to fetch tags...'); // Debug print
    try {
      final response = await http.get(Uri.parse('$backendUrl/tags'));
      print('Tags response status: ${response.statusCode}'); // Debug print
      print('Tags response body: ${response.body}'); // Debug print
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Parsed data: $data'); // Debug print
        setState(() {
          _allTags = data.map((tag) => tag['name'] as String).toList();
          _filteredTags = List.from(_allTags);
          _showTagSuggestions = true;
          print('Set _allTags to: $_allTags'); // Debug print
          print('Set _filteredTags to: $_filteredTags'); // Debug print
          print(
              'Set _showTagSuggestions to: $_showTagSuggestions'); // Debug print
        });
      }
    } catch (e) {
      print('Error fetching tags: $e'); // Debug print
    }
  }

  void _filterTags(String query) {
    print('Filtering tags. Query: "$query"'); // Debug print
    print('All tags before filter: $_allTags'); // Debug print
    setState(() {
      if (query.isEmpty) {
        _filteredTags = List.from(_allTags);
      } else {
        _filteredTags = _allTags
            .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _showTagSuggestions = true;
      print('Filtered tags: $_filteredTags'); // Debug print
      print('Show suggestions: $_showTagSuggestions'); // Debug print
    });
  }

  Future<void> _fetchLecturers() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/dozenten'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _lecturers = List<Map<String, dynamic>>.from(data);
        });
      } else {
        print('Error fetching lecturers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching lecturers: $e');
    }
  }

  void _handleTagSelection(String tag) {
    if (!_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
        _showTagSuggestions = false;
      });
    }
  }

  Widget _buildTagInput() {
    print('Building tag input'); // Debug print
    print('_showTagSuggestions: $_showTagSuggestions'); // Debug print
    print('_allTags: $_allTags'); // Debug print
    print('_filteredTags: $_filteredTags'); // Debug print

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedTags.isNotEmpty) ...[
              const Text(
                'Ausgewählte Tags:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _selectedTags
                    .map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: () {
                            setState(() {
                              _selectedTags.remove(tag);
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
            TextField(
              controller: _tagController,
              focusNode: _tagFocusNode,
              decoration: InputDecoration(
                labelText: 'Tags',
                hintText: 'Tag eingeben oder aus Liste wählen',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_tagController.text.isNotEmpty) {
                      _handleTagSelection(_tagController.text);
                    }
                  },
                ),
              ),
              onTap: () {
                setState(() {
                  _showTagSuggestions = true;
                });
              },
              onChanged: (value) {
                _filterTags(value);
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _handleTagSelection(value);
                }
              },
            ),
            if (_allTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Verfügbare Tags:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredTags.length,
                  itemBuilder: (context, index) {
                    final tag = _filteredTags[index];
                    final isSelected = _selectedTags.contains(tag);
                    return ListTile(
                      dense: true,
                      title: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).disabledColor
                              : null,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () {
                        if (!isSelected) {
                          _handleTagSelection(tag);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showAddTrainingDialog(BuildContext context) {
    String trainingName = '';
    String description = '';
    String location = '';
    int maxParticipants = 0;
    int? selectedLecturerId;
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    // Reset tag-related state
    _tagController.clear();
    setState(() {
      _selectedTags = [];
      _filteredTags = List.from(_allTags);
      _showTagSuggestions = false;
    });

    // Fetch fresh tags
    _fetchTags().then((_) {
      print('Tags fetched for dialog: $_allTags'); // Debug print
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            print('Dialog rebuilding with tags: $_allTags'); // Debug print
            return AlertDialog(
              title: const Text('Neue Schulung erstellen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Name'),
                      onChanged: (value) => trainingName = value,
                    ),
                    TextField(
                      decoration:
                          const InputDecoration(labelText: 'Beschreibung'),
                      onChanged: (value) => description = value,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Ort'),
                      onChanged: (value) => location = value,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Maximale Teilnehmerzahl'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          maxParticipants = int.tryParse(value) ?? 0,
                    ),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Dozent'),
                      value: selectedLecturerId,
                      items: _lecturers.map((lecturer) {
                        return DropdownMenuItem<int>(
                          value: lecturer['id'] as int,
                          child: Text(
                              '${lecturer['vorname']} ${lecturer['nachname']}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLecturerId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Tag input section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedTags.isNotEmpty) ...[
                          const Text(
                            'Ausgewählte Tags:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _selectedTags
                                .map((tag) => Chip(
                                      label: Text(tag),
                                      onDeleted: () {
                                        setDialogState(() {
                                          _selectedTags.remove(tag);
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                        ],
                        TextField(
                          controller: _tagController,
                          focusNode: _tagFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Tags',
                            hintText: 'Tag eingeben oder aus Liste wählen',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (_tagController.text.isNotEmpty) {
                                  final newTag = _tagController.text;
                                  setDialogState(() {
                                    if (!_selectedTags.contains(newTag)) {
                                      _selectedTags.add(newTag);
                                      _tagController.clear();
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          onTap: () {
                            setDialogState(() {
                              _showTagSuggestions = true;
                            });
                          },
                        ),
                        if (_allTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Verfügbare Tags:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _allTags.length,
                              itemBuilder: (context, index) {
                                final tag = _allTags[index];
                                final isSelected = _selectedTags.contains(tag);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    tag,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).disabledColor
                                          : null,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check)
                                      : null,
                                  onTap: () {
                                    if (!isSelected) {
                                      _handleTagSelection(tag);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Text(selectedDate == null
                                ? 'Datum wählen'
                                : DateFormat('dd.MM.yyyy')
                                    .format(selectedDate!)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Text(startTime == null
                                ? 'Startzeit wählen'
                                : startTime!.format(context)),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  endTime = time;
                                });
                              }
                            },
                            child: Text(endTime == null
                                ? 'Endzeit wählen'
                                : endTime!.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTagInput(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (trainingName.isEmpty ||
                        selectedDate == null ||
                        startTime == null ||
                        endTime == null ||
                        selectedLecturerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Bitte füllen Sie alle Pflichtfelder aus.'),
                        ),
                      );
                      return;
                    }

                    final training = {
                      'titel': trainingName,
                      'beschreibung': description,
                      'ort': location,
                      'max_teilnehmer': maxParticipants,
                      'dozent_id': selectedLecturerId,
                      'tags': _selectedTags,
                      'sessions': [
                        {
                          'datum':
                              DateFormat('yyyy-MM-dd').format(selectedDate!),
                          'startzeit':
                              '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00',
                          'endzeit':
                              '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00',
                          'typ': 'normal',
                        }
                      ],
                    };

                    try {
                      final response = await http.post(
                        Uri.parse('$backendUrl/trainings'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode(training),
                      );

                      if (response.statusCode == 201) {
                        if (mounted) {
                          Navigator.of(context).pop();
                          _fetchTrainings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Schulung erfolgreich erstellt'),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Fehler beim Erstellen der Schulung: ${response.body}'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Fehler beim Erstellen der Schulung: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Erstellen'),
                ),
              ],
            );
          },
        );
      },
    );
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
              _buildTagFilterChips(),
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
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.5),
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
                        _buildViewButton(CalendarView.Jahr, 'Jahr',
                            Icons.calendar_view_month),
                        _buildViewButton(
                            CalendarView.Monat, 'Monat', Icons.calendar_today),
                        _buildViewButton(
                            CalendarView.Woche, 'Woche', Icons.view_week),
                        _buildViewButton(
                            CalendarView.Liste, 'Liste', Icons.view_list),
                        _buildViewButton(
                            CalendarView.Gebucht, 'Gebucht', Icons.bookmark),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

    _bookingsFuture ??= _fetchUserBookings();

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
