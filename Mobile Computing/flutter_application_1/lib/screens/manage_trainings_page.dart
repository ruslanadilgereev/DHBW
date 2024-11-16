import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageTrainingsPage extends StatefulWidget {
  const ManageTrainingsPage({Key? key}) : super(key: key);

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
        showErrorMessage('Fehler beim Laden der Schulungen');
      }
    } catch (e) {
      showErrorMessage('Fehler: ${e.toString()}');
    }
  }

  void _showAddTrainingDialog() {
    String trainingName = '';
    String trainingDate = '';
    TextEditingController dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Neue Schulung hinzufügen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Schulungsname'),
                  onChanged: (value) {
                    trainingName = value;
                  },
                ),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Datum auswählen'),
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      locale: const Locale("de", "DE"),
                      context: dialogContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      String formattedDate = pickedDate.toIso8601String().split('T').first;
                      setState(() {
                        dateController.text = formattedDate;
                        trainingDate = formattedDate;
                      });
                    }
                  },
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
                if (trainingName.isNotEmpty && trainingDate.isNotEmpty) {
                  await addTraining(trainingName, trainingDate);
                  Navigator.of(dialogContext).pop();
                } else {
                  showErrorMessage('Alle Felder sind erforderlich');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> addTraining(String name, String date) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3001/api/trainings'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'training_name': name,
          'date': date,
        }),
      );
      if (response.statusCode == 201) {
        fetchTrainings();
        showSuccessMessage('Schulung hinzugefügt');
      } else {
        showErrorMessage('Fehler beim Hinzufügen der Schulung');
      }
    } catch (e) {
      showErrorMessage('Fehler: ${e.toString()}');
    }
  }

  Future<void> _deleteTraining(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:3001/api/trainings/$id'),
      );
      if (response.statusCode == 200) {
        fetchTrainings();
        showSuccessMessage('Schulung gelöscht');
      } else {
        showErrorMessage('Fehler beim Löschen der Schulung');
      }
    } catch (e) {
      showErrorMessage('Fehler: ${e.toString()}');
    }
  }

  void _showEditTrainingDialog(dynamic training) {
    String trainingName = training['training_name'];
    String trainingDate = training['date'];
    TextEditingController nameController = TextEditingController(text: trainingName);
    TextEditingController dateController = TextEditingController(text: trainingDate);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Schulung bearbeiten'),
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
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Datum auswählen'),
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      locale: const Locale("de", "DE"),
                      context: dialogContext,
                      initialDate: DateTime.parse(trainingDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      String formattedDate = pickedDate.toIso8601String().split('T').first;
                      setState(() {
                        dateController.text = formattedDate;
                        trainingDate = formattedDate;
                      });
                    }
                  },
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
              child: const Text('Aktualisieren'),
              onPressed: () async {
                if (trainingName.isNotEmpty && trainingDate.isNotEmpty) {
                  await _updateTraining(training['id'], trainingName, trainingDate);
                  Navigator.of(dialogContext).pop();
                } else {
                  showErrorMessage('Alle Felder sind erforderlich');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTraining(int id, String name, String date) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:3001/api/trainings/$id'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'training_name': name,
          'date': date,
        }),
      );
      if (response.statusCode == 200) {
        fetchTrainings();
        showSuccessMessage('Schulung aktualisiert');
      } else {
        showErrorMessage('Fehler beim Aktualisieren der Schulung');
      }
    } catch (e) {
      showErrorMessage('Fehler: ${e.toString()}');
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
            return AlertDialog(
              title: const Text('Buchungen für Schulung'),
              content: bookings.isEmpty
                  ? const Text('Keine Buchungen für diese Schulung.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: bookings.map((booking) {
                        return ListTile(
                          title: Text(booking['user_email']),
                        );
                      }).toList(),
                    ),
              actions: [
                TextButton(
                  child: const Text('Schließen'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      } else {
        showErrorMessage('Fehler beim Laden der Buchungen');
      }
    } catch (e) {
      showErrorMessage('Fehler: ${e.toString()}');
    }
  }

  void showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        subtitle: Text('Datum: ${training['date']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.people, color: Colors.green),
              onPressed: () {
                _viewBookings(training['id']);
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orangeAccent),
              onPressed: () {
                _showEditTrainingDialog(training);
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
