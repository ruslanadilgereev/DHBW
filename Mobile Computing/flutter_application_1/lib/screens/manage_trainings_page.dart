import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/lecturer_service.dart';

class ManageTrainingsPage extends StatefulWidget {
  const ManageTrainingsPage({super.key});

  @override
  _ManageTrainingsPageState createState() => _ManageTrainingsPageState();
}

class _ManageTrainingsPageState extends State<ManageTrainingsPage> {
  List<dynamic> trainings = [];
  final LecturerService _lecturerService = LecturerService();
  List<Lecturer> _lecturers = [];
  Lecturer? _selectedLecturer;

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
        setState(() {
          trainings = json.decode(response.body);
        });
      } else {
        showErrorSnackbar('Fehler beim Laden der Schulungen');
      }
    } catch (e) {
      showErrorSnackbar('Fehler: $e');
    }
  }

  void _showAddTrainingDialog(BuildContext context) {
    String trainingName = '';
    List<DateTime> selectedDates = [];
    List<DateTimeRange> pauses = [];

    // Neue Controller für die zusätzlichen Eingabefelder
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
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
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
                    Wrap(
                      spacing: 8.0,
                      children: selectedDates.map((date) {
                        return Chip(
                          label: Text(_formatDate(date)),
                          onDeleted: () {
                            setDialogState(() {
                              selectedDates.remove(date);
                            });
                          },
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
                              : DateTime(2101),
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
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Hinzufügen'),
                  onPressed: () async {
                    if (trainingName.isNotEmpty &&
                        selectedDates.isNotEmpty &&
                        _selectedLecturer != null) {
                      await addTraining(
                        trainingName,
                        selectedDates,
                        pauses,
                        descriptionController.text,
                        locationController.text,
                        int.tryParse(maxParticipantsController.text) ?? 0,
                        _selectedLecturer?.id ?? 0,
                      );
                      Navigator.of(dialogContext).pop();
                    } else {
                      showErrorSnackbar(
                          'Bitte geben Sie einen Namen, mindestens ein Datum und einen Dozenten an');
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

  // Aktualisierte addTraining-Funktion
  Future<void> addTraining(
    String name,
    List<DateTime> dates,
    List<DateTimeRange> pauses,
    String description,
    String location,
    int maxParticipants,
    int lecturerId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3001/api/trainings'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'training_name': name,
          'description': description,
          'location': location,
          'max_participants': maxParticipants,
          'lecturer_id': lecturerId,
          'dates': dates
              .map((date) => date.toIso8601String().split('T').first)
              .toList(),
          'pauses': pauses
              .map((pause) => {
                    'start': pause.start.toIso8601String().split('T').first,
                    'end': pause.end.toIso8601String().split('T').first,
                  })
              .toList(),
        }),
      );

      if (response.statusCode == 201) {
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
                // Definieren Sie die gewünschte Höhe und Breite
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
        showErrorSnackbar('Fehler beim Laden der Buchungen');
      }
    } catch (e) {
      showErrorSnackbar('Fehler: $e');
    }
  }

  Widget buildTrainingItem(dynamic training) {
    final List<dynamic> dates = (training['dates'] as List?) ?? [];
    final bool isMultiDay = dates.length > 1;
    final int maxParticipants = training['max_teilnehmer'] ?? 0;
    final int bookedCount = training['booked_count'] ?? 0;
    final int availableSpots = maxParticipants - bookedCount;

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
        leading: const Icon(Icons.school, color: Colors.blueAccent),
        title: Row(
          children: [
            Expanded(
              child: Text(
                training['training_name'] ?? 'Unbenannte Schulung',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
                '${maxParticipants - bookedCount}/$maxParticipants Plätze',
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Dozent ID: ${training['dozent_id'] ?? 'Keine Angabe'}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Ort: ${training['ort'] ?? 'Kein Ort angegeben'}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beschreibung:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(training['beschreibung'] ?? 'Keine Beschreibung'),
                const SizedBox(height: 16),
                const Text(
                  'Termine:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...dates.map((date) => Text('- $date')),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.people, color: Colors.blueAccent),
                      onPressed: () => _viewBookings(training['id']),
                      tooltip: 'Buchungen anzeigen',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteTraining(training['id']),
                      tooltip: 'Schulung löschen',
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

  Future<void> _deleteTraining(int trainingId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:3001/api/trainings/$trainingId'),
      );
      if (response.statusCode == 200) {
        fetchTrainings();
        showSuccessSnackbar('Schulung gelöscht');
      } else {
        showErrorSnackbar('Fehler beim Löschen der Schulung');
      }
    } catch (e) {
      showErrorSnackbar('Fehler: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schulungen verwalten'),
      ),
      body: trainings.isEmpty
          ? const Center(child: Text('Keine Schulungen vorhanden'))
          : ListView.builder(
              itemCount: trainings.length,
              itemBuilder: (context, index) {
                return buildTrainingItem(trainings[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTrainingDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
