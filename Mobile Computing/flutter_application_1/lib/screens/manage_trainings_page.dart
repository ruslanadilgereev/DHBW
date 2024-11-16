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

void _showAddTrainingDialog() {
  String trainingName = '';
  List<DateTime> selectedDates = [];
  TextEditingController nameController = TextEditingController();

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
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Schulungsname'),
                    onChanged: (value) {
                      trainingName = value;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        locale: const Locale("de", "DE"),
                        context: dialogContext, // Verwenden Sie hier 'dialogContext'
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDates.add(pickedDate);
                        });
                      }
                    },
                    child: const Text('Datum hinzufügen'),
                  ),
                  const SizedBox(height: 10),
                  if (selectedDates.isNotEmpty)
                    Wrap(
                      spacing: 8.0,
                      children: selectedDates.map((date) {
                        return Chip(
                          label: Text(date.toIso8601String().split('T').first),
                          onDeleted: () {
                            setState(() {
                              selectedDates.remove(date);
                            });
                          },
                        );
                      }).toList(),
                    )
                  else
                    const Text('Keine Daten ausgewählt'),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Abbrechen'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Verwenden Sie 'dialogContext'
                },
              ),
              ElevatedButton(
                child: const Text('Hinzufügen'),
                onPressed: () async {
                  if (trainingName.isNotEmpty && selectedDates.isNotEmpty) {
                    await addTraining(trainingName, selectedDates);
                    Navigator.of(dialogContext).pop(); // Verwenden Sie 'dialogContext'
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



Future<void> addTraining(String name, List<DateTime> dates) async {
  try {
    final response = await http.post(
      Uri.parse('http://localhost:3001/api/trainings'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'training_name': name,
        'dates': dates.map((date) => date.toIso8601String().split('T').first).toList(),
      }),
    );

    if (response.statusCode == 201) {
      fetchTrainings();
      showSuccessSnackbar('Schulung hinzugefügt');
    } else {
      showErrorSnackbar('Fehler beim Hinzufügen der Schulung');
    }
  } catch (e) {
    showErrorSnackbar('Fehler: $e');
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
                                title: Text(booking['user_name'] ?? 'Unbekannt'),
                                subtitle: Text(booking['user_email'] ?? ''),
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
          training['training_name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
      print(response.statusCode);
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
        onPressed: _showAddTrainingDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
