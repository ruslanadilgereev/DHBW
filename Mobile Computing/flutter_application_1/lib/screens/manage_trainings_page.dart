import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/lecturer_service.dart';
import '../services/tag_service.dart';

class ManageTrainingsPage extends StatefulWidget {
  const ManageTrainingsPage({super.key});

  @override
  _ManageTrainingsPageState createState() => _ManageTrainingsPageState();
}

class _ManageTrainingsPageState extends State<ManageTrainingsPage> {
  List<dynamic> _trainings = [];
  final LecturerService _lecturerService = LecturerService();
  final TagService _tagService = TagService();
  List<Lecturer> _lecturers = [];
  Lecturer? _selectedLecturer;
  List<String> _tags = [];
  List<Tag> _tagSuggestions = [];
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTrainings();
    _fetchLecturers();
  }

  Future<void> _fetchLecturers() async {
    try {
      final lecturers = await _lecturerService.getLecturers();
      setState(() {
        _lecturers = lecturers;
        // If we have a selected lecturer, find its corresponding instance in the new list
        if (_selectedLecturer != null) {
          _selectedLecturer = lecturers.firstWhere(
            (l) => l.id == _selectedLecturer!.id,
            orElse: () => _selectedLecturer!,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Dozenten: $e')),
        );
      }
    }
  }

  Future<void> fetchTrainings() async {
    try {
      final response =
          await http.get(Uri.parse('http://localhost:3001/api/trainings'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        setState(() {
          _trainings =
              jsonData.map((json) => json as Map<String, dynamic>).toList();
        });
      } else {}
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching trainings: $e')),
      );
    }
  }

  void _showAddTrainingDialog(BuildContext context) {
    String trainingName = '';
    List<DateTime> selectedDates = [];
    List<DateTimeRange> pauses = [];
    // Add maps to store start and end times for each date
    Map<DateTime, TimeOfDay> startTimes = {};
    Map<DateTime, TimeOfDay> endTimes = {};

    // Controllers for input fields
    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController locationController = TextEditingController();
    TextEditingController maxParticipantsController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Neue Schulung hinzufügen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Schulungsname'),
                      onChanged: (value) {
                        trainingName = value;
                      },
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Beschreibung'),
                    ),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Ort'),
                    ),
                    TextField(
                      controller: maxParticipantsController,
                      decoration: const InputDecoration(
                          labelText: 'Maximale Teilnehmerzahl'),
                      keyboardType: TextInputType.number,
                    ),
                    Column(
                      children: [
                        TextField(
                          controller: _tagController,
                          decoration: const InputDecoration(
                            labelText: 'Tags',
                            hintText:
                                'Tippen Sie, um Tags zu suchen oder neue zu erstellen',
                          ),
                          onChanged: (value) async {
                            List<Tag> suggestions;
                            if (value.isEmpty) {
                              suggestions = await _tagService.getAllTags();
                            } else {
                              suggestions = await _tagService.searchTags(value);
                            }
                            setDialogState(() {
                              _tagSuggestions = suggestions;
                            });
                          },
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              setDialogState(() {
                                if (!_tags.contains(value)) {
                                  _tags.add(value);
                                }
                              });
                              _tagController.clear();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<Tag>>(
                          future: _tagService.getAllTags(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }

                            final availableTags = _tagSuggestions.isEmpty
                                ? (snapshot.data ?? [])
                                : _tagSuggestions;

                            if (availableTags.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8.0, bottom: 4.0),
                                  child: Text(
                                    'Verfügbare Tags:',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: availableTags
                                      .map((tag) => ActionChip(
                                            label: Text(tag.name),
                                            backgroundColor: _tags
                                                    .contains(tag.name)
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            labelStyle: TextStyle(
                                              color: _tags.contains(tag.name)
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                            onPressed: () {
                                              setDialogState(() {
                                                if (!_tags.contains(tag.name)) {
                                                  _tags.add(tag.name);
                                                }
                                              });
                                            },
                                          ))
                                      .toList(),
                                ),
                              ],
                            );
                          },
                        ),
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 8.0, bottom: 4.0),
                            child: Text(
                              'Ausgewählte Tags:',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _tags
                                .map((tag) => Chip(
                                      label: Text(tag),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      labelStyle: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer),
                                      deleteIcon: Icon(
                                        Icons.cancel,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      onDeleted: () {
                                        setDialogState(() {
                                          _tags.remove(tag);
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Lecturer>(
                            decoration:
                                const InputDecoration(labelText: 'Dozent'),
                            value: _selectedLecturer,
                            items: _lecturers.map((lecturer) {
                              return DropdownMenuItem<Lecturer>(
                                key: ValueKey(lecturer.id ?? -1),
                                value: lecturer,
                                child: Text(lecturer.fullName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                setState(() {
                                  _selectedLecturer = value;
                                });
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Neuen Dozenten erstellen',
                          onPressed: () async {
                            final result = await _showAddLecturerDialog();
                            if (result == true) {
                              // Force the dialog to rebuild with the new lecturer list
                              setDialogState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Gesamtzeitraum auswählen
                    ElevatedButton(
                      onPressed: () async {
                        final pickedRange = await showDateRangePicker(
                          locale: const Locale("de", "DE"),
                          context: dialogContext,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                          initialDateRange: selectedDates.isNotEmpty
                              ? DateTimeRange(
                                  start: selectedDates.first,
                                  end: selectedDates.last)
                              : null,
                        );
                        if (pickedRange != null) {
                          setDialogState(() {
                            // Generiere Trainingstage innerhalb des gewählten Zeitraums
                            selectedDates = _generateTrainingDates(
                                pickedRange.start, pickedRange.end, pauses);
                          });
                        }
                      },
                      child: const Text('Gesamtzeitraum auswählen'),
                    ),
                    const SizedBox(height: 10),
                    // Anzeige des Gesamtzeitraums
                    if (selectedDates.isNotEmpty)
                      Text(
                        'Zeitraum: ${_formatDate(selectedDates.first)} - ${_formatDate(selectedDates.last)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 10),
                    // Trainingsdaten anzeigen
                    const Text('Trainingstage:'),
                    const SizedBox(height: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: selectedDates.map((date) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Chip(
                                  label: Text(_formatDate(date)),
                                  onDeleted: () {
                                    setDialogState(() {
                                      selectedDates.remove(date);
                                      startTimes.remove(date);
                                      endTimes.remove(date);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Start time button
                              TextButton(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: startTimes[date] ??
                                        const TimeOfDay(hour: 9, minute: 0),
                                  );
                                  if (time != null) {
                                    setDialogState(() {
                                      startTimes[date] = time;
                                    });
                                  }
                                },
                                child: Text(
                                  startTimes[date]?.format(context) ?? '09:00',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Text(' - '),
                              // End time button
                              TextButton(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: endTimes[date] ??
                                        const TimeOfDay(hour: 17, minute: 0),
                                  );
                                  if (time != null) {
                                    setDialogState(() {
                                      endTimes[date] = time;
                                    });
                                  }
                                },
                                child: Text(
                                  endTimes[date]?.format(context) ?? '17:00',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    // Pausen hinzufügen
                    ElevatedButton(
                      onPressed: () async {
                        final pickedPause = await showDateRangePicker(
                          locale: const Locale("de", "DE"),
                          context: dialogContext,
                          firstDate: selectedDates.isNotEmpty
                              ? selectedDates.first
                              : DateTime.now(),
                          lastDate: selectedDates.isNotEmpty
                              ? selectedDates.last
                              : DateTime.now()
                                  .add(const Duration(days: 365 * 2)),
                        );
                        if (pickedPause != null) {
                          setDialogState(() {
                            pauses.add(pickedPause);
                            // Aktualisiere die Trainingstage basierend auf den Pausen
                            selectedDates = _generateTrainingDates(
                                selectedDates.first,
                                selectedDates.last,
                                pauses);
                          });
                        }
                      },
                      child: const Text('Pause hinzufügen'),
                    ),
                    const SizedBox(height: 5),
                    // Anzeige der Pausen
                    if (pauses.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pausen:'),
                          Wrap(
                            spacing: 8.0,
                            children: pauses.map((range) {
                              return Chip(
                                label: Text(
                                    '${_formatDate(range.start)} - ${_formatDate(range.end)}'),
                                onDeleted: () {
                                  setDialogState(() {
                                    pauses.remove(range);
                                    // Aktualisiere die Trainingstage nach dem Entfernen einer Pause
                                    selectedDates = _generateTrainingDates(
                                        selectedDates.first,
                                        selectedDates.last,
                                        pauses);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Abbrechen'),
                  onPressed: () {
                    _tags.clear(); // This will reset the selected tags
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Hinzufügen'),
                  onPressed: () async {
                    if (trainingName.isNotEmpty &&
                        selectedDates.isNotEmpty &&
                        _selectedLecturer != null) {
                      // Convert TimeOfDay to string format HH:mm:ss
                      final startTimeStrings = selectedDates.map((date) {
                        final time = startTimes[date] ??
                            const TimeOfDay(hour: 9, minute: 0);
                        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
                      }).toList();

                      final endTimeStrings = selectedDates.map((date) {
                        final time = endTimes[date] ??
                            const TimeOfDay(hour: 17, minute: 0);
                        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
                      }).toList();

                      await addTraining(
                        trainingName,
                        selectedDates,
                        pauses,
                        descriptionController.text,
                        locationController.text,
                        int.tryParse(maxParticipantsController.text) ?? 0,
                        _selectedLecturer?.id ?? 0,
                        startTimeStrings, // Add start times
                        endTimeStrings, // Add end times
                      );
                      Navigator.of(dialogContext).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Bitte geben Sie einen Namen, mindestens ein Datum und einen Dozenten an')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showAddLecturerDialog() async {
    final TextEditingController vornameController = TextEditingController();
    final TextEditingController nachnameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Neuen Dozenten hinzufügen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: vornameController,
                  decoration: const InputDecoration(labelText: 'Vorname'),
                ),
                TextField(
                  controller: nachnameController,
                  decoration: const InputDecoration(labelText: 'Nachname'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Hinzufügen'),
              onPressed: () async {
                if (vornameController.text.isNotEmpty &&
                    nachnameController.text.isNotEmpty &&
                    emailController.text.isNotEmpty) {
                  try {
                    final newLecturer = await _lecturerService.createLecturer(
                      vornameController.text,
                      nachnameController.text,
                      emailController.text,
                    );

                    // Update the lecturers list and select the new lecturer
                    final updatedLecturers =
                        await _lecturerService.getLecturers();
                    if (mounted) {
                      setState(() {
                        _lecturers = updatedLecturers;
                        // Find and select the new lecturer by ID
                        _selectedLecturer = updatedLecturers.firstWhere(
                          (l) => l.id == newLecturer.id,
                          orElse: () => newLecturer,
                        );
                      });

                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Dozent erfolgreich hinzugefügt')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: ${e.toString()}')),
                      );
                      Navigator.of(context).pop(false);
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );

    return result ?? false; // Handle null case when dialog is dismissed
  }

  // Hilfsfunktion zum Formatieren von Datum
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Hilfsfunktion zum Generieren von Trainingstagen unter Berücksichtigung von Pausen
  List<DateTime> _generateTrainingDates(
      DateTime start, DateTime end, List<DateTimeRange> pauses) {
    List<DateTime> dates = [];
    DateTime current = start;
    while (!current.isAfter(end)) {
      bool isPaused = pauses.any((pause) =>
          (current.isAfter(pause.start.subtract(const Duration(days: 1))) &&
              current.isBefore(pause.end.add(const Duration(days: 1)))));
      if (!isPaused &&
          current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  Future<List<int>> _createTags(List<String> tagNames) async {
    List<int> tagIds = [];

    for (String tagName in tagNames) {
      try {
        final response = await http.post(
          Uri.parse('http://localhost:3001/api/tags'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, dynamic>{
            'name': tagName,
            'create_time': DateTime.now().toIso8601String(),
          }),
        );

        if (response.statusCode == 201) {
          final Map<String, dynamic> data = json.decode(response.body);
          tagIds.add(data['id']);
        } else if (response.statusCode == 409) {
          // Tag already exists, get its ID
          final existingTagResponse = await http.get(
            Uri.parse('http://localhost:3001/api/tags/byName/$tagName'),
          );
          if (existingTagResponse.statusCode == 200) {
            final Map<String, dynamic> data =
                json.decode(existingTagResponse.body);
            tagIds.add(data['id']);
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating tag $tagName: $e')),
        );
      }
    }
    return tagIds;
  }

  // Aktualisierte addTraining-Funktion
  Future<void> addTraining(
    String name,
    List<DateTime> dates,
    List<DateTimeRange> pauses,
    String description,
    String location,
    int maxParticipants,
    int lecturerId,
    List<String> startTimeStrings,
    List<String> endTimeStrings,
  ) async {
    try {
      // Format dates to ISO strings after normalizing them
      final formattedDates = dates
          .map((date) =>
              _normalizeDate(date.toLocal()).toIso8601String().split('T')[0])
          .toList();

      final tagIds = await _createTags(_tags);
      final response = await http.post(
        Uri.parse('http://localhost:3001/api/trainings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'training_name': name,
          'description': description,
          'location': location,
          'max_participants': maxParticipants,
          'lecturer_id': lecturerId,
          'dates': formattedDates,
          'tags': tagIds,
          'pauses': pauses
              .map((pause) => {
                    'start': pause.start.toIso8601String(),
                    'end': pause.end.toIso8601String(),
                  })
              .toList(),
          'start_times': startTimeStrings,
          'end_times': endTimeStrings,
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          _tags = []; // Clear tags after successful creation
        });
        fetchTrainings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schulung hinzugefügt')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Hinzufügen der Schulung')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _updateTraining(
    int trainingId,
    String name,
    List<DateTime> dates,
    List<DateTimeRange> pauses,
    String description,
    String location,
    int maxParticipants,
    int lecturerId,
    List<String> startTimeStrings,
    List<String> endTimeStrings,
    List<String> tags,
  ) async {
    try {
      // Format dates to ISO strings after normalizing them
      final formattedDates = dates
          .map((date) =>
              _normalizeDate(date.toLocal()).toIso8601String().split('T')[0])
          .toList();

      final response = await http.put(
        Uri.parse('http://localhost:3001/api/trainings/$trainingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'training_name': name,
          'description': description,
          'location': location,
          'max_participants': maxParticipants,
          'lecturer_id': lecturerId,
          'dates': formattedDates,
          'tags': tags,
          'pauses': pauses
              .map((pause) => {
                    'start': pause.start.toIso8601String(),
                    'end': pause.end.toIso8601String(),
                  })
              .toList(),
          'start_times': startTimeStrings,
          'end_times': endTimeStrings,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training erfolgreich aktualisiert')),
        );
        await fetchTrainings(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fehler beim Aktualisieren des Trainings')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aktualisieren des Trainings: $e')),
      );
    }
  }

  Future<void> _showEditTrainingDialog(dynamic training) async {
    final TextEditingController nameController =
        TextEditingController(text: training['titel']);
    final TextEditingController descriptionController =
        TextEditingController(text: training['beschreibung']);
    final TextEditingController locationController =
        TextEditingController(text: training['ort']);
    final TextEditingController maxParticipantsController =
        TextEditingController(text: training['max_teilnehmer'].toString());

    List<DateTime> selectedDates = [];
    Map<DateTime, TimeOfDay> startTimes = {};
    Map<DateTime, TimeOfDay> endTimes = {};
    List<DateTimeRange> pauses = [];

    // Initialize dates and times from sessions
    if (training['sessions'] != null) {
      for (var session in training['sessions']) {
        final DateTime date =
            _normalizeDate(DateTime.parse(session['datum']).toLocal());
        selectedDates.add(date);

        // Parse start time
        final startTimeParts = session['startzeit'].toString().split(':');
        startTimes[date] = TimeOfDay(
          hour: int.parse(startTimeParts[0]),
          minute: int.parse(startTimeParts[1]),
        );

        // Parse end time
        final endTimeParts = session['endzeit'].toString().split(':');
        endTimes[date] = TimeOfDay(
          hour: int.parse(endTimeParts[0]),
          minute: int.parse(endTimeParts[1]),
        );
      }
    }

    // Find the lecturer in _lecturers list
    Lecturer? selectedLecturer = _lecturers.firstWhere(
      (l) => l.id == training['dozent_id'],
      orElse: () => _lecturers.first,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.66,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Training bearbeiten',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration:
                                  const InputDecoration(labelText: 'Name'),
                            ),
                            TextField(
                              controller: descriptionController,
                              decoration: const InputDecoration(
                                  labelText: 'Beschreibung'),
                              maxLines: 3,
                            ),
                            TextField(
                              controller: locationController,
                              decoration:
                                  const InputDecoration(labelText: 'Ort'),
                            ),
                            TextField(
                              controller: maxParticipantsController,
                              decoration: const InputDecoration(
                                  labelText: 'Maximale Teilnehmerzahl'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            // Date picker section
                            ElevatedButton(
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
                                    if (!selectedDates.contains(date)) {
                                      selectedDates.add(date);
                                      selectedDates.sort();
                                    }
                                  });
                                }
                              },
                              child: const Text('Datum hinzufügen'),
                            ),
                            const SizedBox(height: 8),
                            // Display selected dates with time pickers
                            ...selectedDates.map((date) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Chip(
                                          label: Text(_formatDate(date)),
                                          onDeleted: () {
                                            setDialogState(() {
                                              selectedDates.remove(date);
                                              startTimes.remove(date);
                                              endTimes.remove(date);
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () async {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: startTimes[date] ??
                                                const TimeOfDay(
                                                    hour: 9, minute: 0),
                                          );
                                          if (time != null) {
                                            setDialogState(() {
                                              startTimes[date] = time;
                                            });
                                          }
                                        },
                                        child: Text(
                                          startTimes[date]?.format(context) ??
                                              '09:00',
                                        ),
                                      ),
                                      const Text(' - '),
                                      TextButton(
                                        onPressed: () async {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: endTimes[date] ??
                                                const TimeOfDay(
                                                    hour: 17, minute: 0),
                                          );
                                          if (time != null) {
                                            setDialogState(() {
                                              endTimes[date] = time;
                                            });
                                          }
                                        },
                                        child: Text(
                                          endTimes[date]?.format(context) ??
                                              '17:00',
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 16),
                            // Lecturer dropdown
                            DropdownButtonFormField<Lecturer>(
                              decoration:
                                  const InputDecoration(labelText: 'Dozent'),
                              value: selectedLecturer,
                              items: _lecturers.map((lecturer) {
                                return DropdownMenuItem<Lecturer>(
                                  value: lecturer,
                                  child: Text(lecturer.fullName),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedLecturer = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            // Tags section
                            FutureBuilder<List<Tag>>(
                              future: _tagService.getAllTags(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tags:'),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 4.0,
                                      children: snapshot.data!
                                          .map((tag) => FilterChip(
                                                selected: training['tags']
                                                    .contains(tag.name),
                                                label: Text(tag.name),
                                                onSelected: (bool selected) {
                                                  setDialogState(() {
                                                    if (selected) {
                                                      training['tags']
                                                          .add(tag.name);
                                                    } else {
                                                      training['tags']
                                                          .remove(tag.name);
                                                    }
                                                  });
                                                },
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Abbrechen'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (selectedDates.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Bitte mindestens ein Datum auswählen')),
                                      );
                                      return;
                                    }

                                    List<String> startTimeStrings = [];
                                    List<String> endTimeStrings = [];

                                    for (var date in selectedDates) {
                                      final start = startTimes[date] ??
                                          const TimeOfDay(hour: 9, minute: 0);
                                      final end = endTimes[date] ??
                                          const TimeOfDay(hour: 17, minute: 0);

                                      startTimeStrings.add(
                                          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00');
                                      endTimeStrings.add(
                                          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:00');
                                    }

                                    await _updateTraining(
                                      training['id'],
                                      nameController.text,
                                      selectedDates,
                                      [], // pauses
                                      descriptionController.text,
                                      locationController.text,
                                      int.tryParse(
                                              maxParticipantsController.text) ??
                                          0,
                                      selectedLecturer?.id ?? 0,
                                      startTimeStrings,
                                      endTimeStrings,
                                      training['tags'],
                                    );

                                    if (mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Speichern'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTraining(int trainingId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:3001/api/trainings/$trainingId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _trainings.removeWhere((training) => training['id'] == trainingId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schulung gelöscht')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Löschen der Schulung')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  void _viewBookings(int trainingId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3001/api/trainings/$trainingId/bookings'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> bookings = json.decode(response.body);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                width: MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Buchungen für Schulung',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: bookings.isEmpty
                          ? const Center(
                              child:
                                  Text('Keine Buchungen für diese Schulung.'),
                            )
                          : ListView.builder(
                              itemCount: bookings.length,
                              itemBuilder: (context, index) {
                                var booking = bookings[index];
                                return ListTile(
                                  title: Text(
                                    '${booking['first_name'] ?? 'Unbekannt'} ${booking['last_name'] ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Email: ${booking['user_email'] ?? 'Nicht verfügbar'}'),
                                      if (booking['company'] != null &&
                                          booking['company'].isNotEmpty)
                                        Text('Firma: ${booking['company']}'),
                                      if (booking['phone'] != null &&
                                          booking['phone'].isNotEmpty)
                                        Text('Telefon: ${booking['phone']}'),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        child: const Text('Schließen'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Laden der Buchungen')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget buildTrainingItem(dynamic training) {
    // Get dates from sessions instead of 'dates' field
    final List<dynamic> dates = (training['dates'] as List?) ?? [];
    final bool isMultiDay = dates.length > 1;
    final int maxParticipants = training['max_teilnehmer'] ?? 0;
    final int bookedCount = training['booked_count'] ?? 0;
    final int availableSpots = maxParticipants - bookedCount;
    final String startDate = training['start_date'] ?? '';
    final String endDate = training['end_date'] ?? '';

    String formatDateRange() {
      if (dates.isEmpty) return 'Keine Termine';
      if (dates.length == 1) {
        final DateTime normalizedDate =
            _normalizeDate(DateTime.parse(dates[0]).toLocal());
        return 'Am ${_formatDate(normalizedDate)}';
      }
      final DateTime normalizedStartDate =
          _normalizeDate(DateTime.parse(startDate).toLocal());
      final DateTime normalizedEndDate =
          _normalizeDate(DateTime.parse(endDate).toLocal());
      return 'Von ${_formatDate(normalizedStartDate)}\nBis ${_formatDate(normalizedEndDate)}\n${dates.length} Termine';
    }

    List<DateBlock> getDateBlocks(List<String> dates) {
      List<DateBlock> blocks = [];
      DateTime? blockStart;
      DateTime? blockEnd;

      for (var date in dates) {
        DateTime currentDate = DateTime.parse(date).toLocal();
        if (blockStart == null) {
          blockStart = currentDate;
          blockEnd = currentDate;
        } else {
          if (currentDate.difference(blockEnd!).inDays == 1) {
            blockEnd = currentDate;
          } else {
            blocks.add(DateBlock(blockStart, blockEnd));
            blockStart = currentDate;
            blockEnd = currentDate;
          }
        }
      }

      if (blockStart != null) {
        blocks.add(DateBlock(blockStart, blockEnd!));
      }

      return blocks;
    }

    return Card(
      elevation: isMultiDay ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isMultiDay ? Theme.of(context).primaryColor : Colors.orange,
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
                    training['titel'] ?? 'Unbenannte Schulung',
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
                      color: Theme.of(context).colorScheme.onSurface,
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (training['dozent_vorname'] != null &&
                    training['dozent_nachname'] != null) ...[
                  Row(
                    children: [
                      Icon(Icons.person,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dozent: ${training['dozent_vorname']} ${training['dozent_nachname']}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ort: ${training['ort'] ?? 'Kein Ort angegeben'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Beschreibung',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  training['beschreibung'] ?? 'Keine Beschreibung verfügbar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.87),
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
                  children: getDateBlocks(dates.cast<String>())
                      .map((block) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            child: Text(
                              '${block.dates.length} Termine\nVon: ${_formatDate(block.startDate)}\nBis: ${_formatDate(block.endDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
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
                      final date = _formatDate(_normalizeDate(
                          DateTime.parse(session['datum'].toString())
                              .toLocal()));
                      final startTime =
                          session['startzeit'].toString().substring(0, 5);
                      final endTime =
                          session['endzeit'].toString().substring(0, 5);
                      return Chip(
                        label: Text('$date: $startTime - $endTime'),
                      );
                    }).toList(),
                  ),
                ],
                if (training['tags'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: (training['tags'] as List)
                        .map((tag) => Chip(
                              label: Text(tag.toString()),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              labelStyle: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditTrainingDialog(training),
                      tooltip: 'Training bearbeiten',
                    ),
                    IconButton(
                      icon: const Icon(Icons.people, color: Colors.blue),
                      onPressed: () => _viewBookings(training['id']),
                      tooltip: 'Buchungen anzeigen',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTraining(training['id']),
                      tooltip: 'Training löschen',
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

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schulungen verwalten'),
      ),
      body: _trainings.isEmpty
          ? const Center(child: Text('Keine Schulungen vorhanden'))
          : ListView.builder(
              itemCount: _trainings.length,
              itemBuilder: (context, index) {
                return buildTrainingItem(_trainings[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTrainingDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DateBlock {
  final DateTime startDate;
  final DateTime endDate;
  List<DateTime> dates = [];

  DateBlock(this.startDate, this.endDate) {
    DateTime current = startDate;
    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
  }
}
