import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageTrainingsPage extends StatefulWidget {
  const ManageTrainingsPage({super.key});

  @override
  _ManageTrainingsPageState createState() => _ManageTrainingsPageState();
}

class _ManageTrainingsPageState extends State<ManageTrainingsPage> {
  List<dynamic> trainings = [];

  @override
  void initState() {
    super.initState();
    fetchTrainings();
  }

  Future<void> fetchTrainings() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3001/api/trainings'));
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
    TextEditingController lecturerIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Neue Schulung hinzufügen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Schulungsname
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Schulungsname'),
                      onChanged: (value) {
                        trainingName = value;
                      },
                    ),
                    // Beschreibung
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Beschreibung'),
                    ),
                    // Ort
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Ort'),
                    ),
                    // Maximale Teilnehmerzahl
                    TextField(
                      controller: maxParticipantsController,
                      decoration: const InputDecoration(labelText: 'Maximale Teilnehmerzahl'),
                      keyboardType: TextInputType.number,
                    ),
                    // Dozent ID
                    TextField(
                      controller: lecturerIdController,
                      decoration: const InputDecoration(labelText: 'Dozent ID'),
                      keyboardType: TextInputType.number,
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
                              ? DateTimeRange(start: selectedDates.first, end: selectedDates.last)
                              : null,
                        );
                        if (pickedRange != null) {
                          setState(() {
                            // Generiere Trainingstage innerhalb des gewählten Zeitraums
                            selectedDates = _generateTrainingDates(pickedRange.start, pickedRange.end, pauses);
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
                            setState(() {
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
                          firstDate: selectedDates.isNotEmpty ? selectedDates.first : DateTime.now(),
                          lastDate: selectedDates.isNotEmpty ? selectedDates.last : DateTime(2101),
                        );
                        if (pickedPause != null) {
                          setState(() {
                            pauses.add(pickedPause);
                            // Aktualisiere die Trainingstage basierend auf den Pausen
                            selectedDates = _generateTrainingDates(selectedDates.first, selectedDates.last, pauses);
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
                                label: Text('${_formatDate(range.start)} - ${_formatDate(range.end)}'),
                                onDeleted: () {
                                  setState(() {
                                    pauses.remove(range);
                                    // Aktualisiere die Trainingstage nach dem Entfernen einer Pause
                                    selectedDates = _generateTrainingDates(selectedDates.first, selectedDates.last, pauses);
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
                    if (trainingName.isNotEmpty && selectedDates.isNotEmpty) {
                      await addTraining(
                        trainingName,
                        selectedDates,
                        pauses,
                        descriptionController.text,
                        locationController.text,
                        int.tryParse(maxParticipantsController.text) ?? 0,
                        int.tryParse(lecturerIdController.text) ?? 0,
                      );
                      Navigator.of(dialogContext).pop();
                    } else {
                      showErrorSnackbar('Bitte geben Sie einen Namen und mindestens ein Datum an');
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

  // Hilfsfunktion zum Formatieren von Datum
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Hilfsfunktion zum Generieren von Trainingstagen unter Berücksichtigung von Pausen
  List<DateTime> _generateTrainingDates(DateTime start, DateTime end, List<DateTimeRange> pauses) {
    List<DateTime> dates = [];
    DateTime current = start;
    while (!current.isAfter(end)) {
      bool isPaused = pauses.any((pause) =>
          (current.isAfter(pause.start.subtract(const Duration(days: 1))) && current.isBefore(pause.end.add(const Duration(days: 1)))));
      if (!isPaused && current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
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
          'dates': dates.map((date) => date.toIso8601String().split('T').first).toList(),
          'pauses': pauses.map((pause) => {
                'start': pause.start.toIso8601String().split('T').first,
                'end': pause.end.toIso8601String().split('T').first,
              }).toList(),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: bookings.isEmpty
                          ? const Center(
                              child: Text('Keine Buchungen für diese Schulung.'),
                            )
                          : ListView.builder(
                              itemCount: bookings.length,
                              itemBuilder: (context, index) {
                                var booking = bookings[index];
                                return ListTile(
                                  title: Text(
                                    '${booking['first_name'] ?? 'Unbekannt'} ${booking['last_name'] ?? ''}'.trim(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Email: ${booking['user_email'] ?? 'Nicht verfügbar'}'),
                                      if (booking['company'] != null && booking['company'].isNotEmpty)
                                        Text('Firma: ${booking['company']}'),
                                      if (booking['phone'] != null && booking['phone'].isNotEmpty)
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
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: const Icon(Icons.school, color: Colors.blueAccent),
        title: Text(
          training['training_name'] ?? 'Unbenannte Schulung',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Beschreibung: ${training['beschreibung'] ?? 'Keine Beschreibung'}'),
            Text('Ort: ${training['ort'] ?? 'Kein Ort angegeben'}'),
            Text('Max. Teilnehmer: ${training['max_teilnehmer'] ?? 'Keine Angabe'}'),
            Text('Dozent ID: ${training['dozent_id'] ?? 'Keine Angabe'}'),
            const SizedBox(height: 8),
            const Text('Termine:'),
            if (training['dates'] != null && training['dates'] is List)
              for (var date in training['dates']) Text('- $date')
            else
              const Text('Keine Termine verfügbar'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.people, color: Colors.blueAccent),
              onPressed: () {
                _viewBookings(training['id']);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                _deleteTraining(training['id']);
              },
            ),
          ],
        ),
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
