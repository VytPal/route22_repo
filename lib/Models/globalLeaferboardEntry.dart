
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalLeaderboardEntry {
  final String userID;
  final String displayName;
  final int score;
  final double traveledKM;

  GlobalLeaderboardEntry({
    required this.userID,
    required this.displayName,
    required this.score,
    required this.traveledKM
});

}