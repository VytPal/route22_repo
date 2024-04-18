import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String description;
  final DateTime? startTime;
  final DateTime? endTime;
  final double entryPrice;
  final String imageUrl;

  Event({
    required this.id,
    required this.name,
    required this.description,
    this.startTime,
    this.endTime,
    required this.entryPrice,
    required this.imageUrl,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Event(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      startTime: data['startTime']?.toDate(),
      endTime: data['endTime']?.toDate(),
      entryPrice: (data['entryPrice'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}
