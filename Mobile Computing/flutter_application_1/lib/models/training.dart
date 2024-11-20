class Training {
  final int id;
  final String title;
  final String description;
  final String lecturer;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final int maxParticipants;
  final int currentParticipants;

  Training({
    required this.id,
    required this.title,
    required this.description,
    required this.lecturer,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.maxParticipants,
    required this.currentParticipants,
  });

  factory Training.fromJson(Map<String, dynamic> json) {
    return Training(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      lecturer: json['lecturer'] as String,
      location: json['location'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      maxParticipants: json['max_participants'] as int,
      currentParticipants: json['current_participants'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'lecturer': lecturer,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
    };
  }
}
