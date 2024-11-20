import 'package:flutter/material.dart';
import '../services/training_service.dart';
import 'package:intl/intl.dart';

class TrainingSearchDelegate extends SearchDelegate<String> {
  final TrainingService _trainingService = TrainingService();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _trainingService.searchTrainings(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final trainings = snapshot.data ?? [];
        
        if (trainings.isEmpty) {
          return const Center(child: Text('No trainings found'));
        }

        return ListView.builder(
          itemCount: trainings.length,
          itemBuilder: (context, index) {
            final training = trainings[index];
            final lecturer = '${training['lecturerVorname']} ${training['lecturerNachname']}'.trim();
            final dateFormat = DateFormat('dd.MM.yyyy');
            final startDate = training['start_date'] != '' ? dateFormat.format(DateTime.parse(training['start_date'])) : 'TBD';
            final endDate = training['end_date'] != '' ? dateFormat.format(DateTime.parse(training['end_date'])) : 'TBD';

            return ListTile(
              title: Text(training['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(training['description']),
                  Text('Location: ${training['location']}'),
                  Text('Lecturer: $lecturer'),
                  Text('Date: $startDate - $endDate'),
                  Text('Participants: ${training['bookedCount']}/${training['maxParticipants']}'),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                close(context, training['id'].toString());
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Start typing to search...'));
    }
    return buildResults(context);
  }
}
