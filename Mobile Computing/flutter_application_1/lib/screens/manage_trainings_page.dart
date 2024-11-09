// lib/screens/manage_trainings_page.dart
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
    final response = await http.get(Uri.parse('http://localhost:3001/api/trainings'));
    if (response.statusCode == 200) {
      setState(() {
        trainings = json.decode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Laden der Schulungen')),
      );
    }
  }

  void _showAddTrainingDialog() {
    String trainingName = '';
    String trainingDate = '';
    TextEditingController dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Verwende dialogContext hier
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
                      context: dialogContext, // Verwende dialogContext hier
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
                await addTraining(trainingName, trainingDate);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> addTraining(String name, String date) async {
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
    print(response.statusCode);
    if (response.statusCode == 201) {
      fetchTrainings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schulung hinzugefügt')),
      );
    } else {
      // Fehlerbehandlung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hinzufügen der Schulung')),
      );
    }
  }

  Future<void> _deleteTraining(int id) async {
    final response = await http.delete(
      Uri.parse('http://localhost:3001/api/trainings/$id'),
    );

    if (response.statusCode == 200) {
      fetchTrainings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schulung gelöscht')),
      );
    } else {
      // Fehlerbehandlung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen der Schulung')),
      );
    }
  }

  void _showEditTrainingDialog(dynamic training) {
    String trainingName = training['training_name'];
    String trainingDate = training['date'];
    TextEditingController nameController = TextEditingController(text: trainingName);
    TextEditingController dateController = TextEditingController(text: trainingDate);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Schulung bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Schulungsname'),
                  onChanged: (value) {
                    trainingName = value;
                  },
                ),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(labelText: 'Datum auswählen'),
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      locale: const Locale("de", "DE"),
                      context: context,
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
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Aktualisieren'),
              onPressed: () async {
                await _updateTraining(training['id'], trainingName, trainingDate);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTraining(int id, String name, String date) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schulung aktualisiert')),
      );
    } else {
      // Fehlerbehandlung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aktualisieren der Schulung')),
      );
    }
  }

  Widget buildTrainingItem(dynamic training) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(Icons.school, color: Colors.blueAccent),
        title: Text(
          training['training_name'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Datum: ${training['date']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.orangeAccent),
              onPressed: () {
                _showEditTrainingDialog(training);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent),
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
        title: Text('Schulungen verwalten'),
      ),
      body: trainings.isEmpty
          ? Center(child: Text('Keine Schulungen vorhanden'))
          : ListView.builder(
              itemCount: trainings.length,
              itemBuilder: (context, index) {
                return buildTrainingItem(trainings[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTrainingDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
