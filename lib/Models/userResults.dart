
import 'package:cloud_firestore/cloud_firestore.dart';

class UserResults {
  final String userID;
  final String? displayName;
  final int finalScore;
  final double traveledKM;
  final String? eventID;
  final String? eventName;

  UserResults({
    required this.userID,
    this.displayName,
    required this.finalScore,
    required this.traveledKM,
    this.eventID,
    this.eventName
});

}