import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:moto_events/Models/event.dart';
import 'package:moto_events/Models/eventMarker.dart';
import 'package:moto_events/Utils/constants.dart';

class MarkersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<EventMarker>> getMarkersForEvent(String eventID) async {
    try {
      var markersCollection =
          _firestore.collection('eventData').doc(eventID).collection('markers');
      var snapshot = await markersCollection.get();

      List<EventMarker> markers =
          snapshot.docs.map((doc) => EventMarker.fromFirestore(doc)).toList();

      return markers;
    } catch (e) {
      print("Error fetching markers: $e");
      return [];
    }
  }
}
