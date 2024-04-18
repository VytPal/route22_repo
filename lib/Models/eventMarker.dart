import 'package:cloud_firestore/cloud_firestore.dart';

class EventMarker {
  final String name;
  final double latitude;
  final double longitude;
  final String id;
  final int points;

  EventMarker(
      {required this.name,
      required this.latitude,
      required this.longitude,
      required this.id,
      required this.points});

  factory EventMarker.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventMarker(
      id: doc.id,
      name: data['name'],
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['long'] as num).toDouble(),
      points: data['points']
    );
  }
}

double parseCoordinate(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.parse(value);
  }
  return 0.0;
}
