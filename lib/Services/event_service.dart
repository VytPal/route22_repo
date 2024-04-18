import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:moto_events/Models/event.dart';
import 'package:moto_events/Utils/constants.dart';

import '../Models/eventResults.dart';
import '../Models/gloabalLeaderboardData.dart';
import '../Models/globalLeaferboardEntry.dart';
import '../Models/userResults.dart';

class EventsService with ChangeNotifier {
  Future<List<Event>> fetchEvents() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('events').get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }
  Future<Event> fetchEvent(String eventID) async {
    DocumentSnapshot snapshot =
    await FirebaseFirestore.instance.collection('events').doc(eventID).get();
    return Event.fromFirestore(snapshot);
  }


  Future<bool> unregisterFromEvent(String eventID, String userID) async {
    try {
      CollectionReference eventEntriesCol =
          FirebaseFirestore.instance.collection("eventEntries");
      print(eventID + userID);
      var querySnapshot = await eventEntriesCol
          .where('userID', isEqualTo: userID)
          .where('eventID', isEqualTo: eventID)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print(querySnapshot.docs.first.id);
        var docIDtoDelete = querySnapshot.docs.first.id;
        await eventEntriesCol.doc(docIDtoDelete).delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Error unregistering from event: $e");
      return false;
    }
  }

  Future<bool> registerForEvent(String eventID, String userID, String email, String eventName) async {
    try {
      CollectionReference eventEntriesColRef =
          FirebaseFirestore.instance.collection('eventEntries');
      await eventEntriesColRef.add({
        'eventID': eventID,
        'userID': userID,
        'registrationDate': DateTime.now(),
        'status':
            userEntryStatusStrings[UserEntryStatus.waitingForConfirmation],
        'finalScore': 0,
        'distanceTraveledKM': 0,
        'finalPlace': 0,
        'registered': true,
        'confirmedByAdmin': false,
        'filledOutProfile': false,
        'agreedWithRules': false,
        'email': email,
        'eventName': eventName
      });
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<Map<String, bool>?> findUserStatusForEventAndUser(
      String eventID, String userID) async {
    try {
      QuerySnapshot eventEntries = await FirebaseFirestore.instance
          .collection('eventEntries')
          .where('eventID', isEqualTo: eventID)
          .where('userID', isEqualTo: userID)
          .get();

      if (eventEntries.docs.isNotEmpty) {
        Map<String, dynamic> data =
            eventEntries.docs.first.data() as Map<String, dynamic>;

        Map<String, bool> userStatus = {
          'registered': data['registered'] ?? false,
          'confirmedByAdmin': data['confirmedByAdmin'] ?? false,
          'filledOutProfile': data['filledOutProfile'] ?? false,
          'agreedWithRules': data['agreedWithRules'] ?? false,
        };

        return userStatus;
      } else {
        return null;
      }
    } catch (e) {
      print('Error querying documents: $e');
      return null;
    }
  }

  Future<QueryDocumentSnapshot<Object?>?> getUserEventEntry(String userID, String eventID) async {
    try{
      QuerySnapshot userEntry = await FirebaseFirestore.instance
      .collection('eventEntries')
      .where('eventID', isEqualTo: eventID)
      .where('userID', isEqualTo: userID)
      .get();
      if(userEntry.docs.isNotEmpty){
        return userEntry.docs.first;
      }
      else{
        return null;
      }
    }
    catch(e){
      return null;
    }
  }

 Future<EventResults?> getEventResults(String eventID) async {
    try{
      QuerySnapshot eventResults = await FirebaseFirestore.instance
      .collection('eventResults')
      .doc(eventID)
      .collection('results').get();

      if(eventResults.docs.isNotEmpty){

        List<UserResults> usersResults =[];
        for(var doc in eventResults.docs){
          var userEntry = await getUserEventEntry(doc.id, eventID);
          try{
            if(userEntry != null){
              print(userEntry['email']);
              usersResults.add(

                  UserResults(
                      userID: doc.id,
                      displayName: userEntry['email'],
                      finalScore: userEntry['finalScore'],
                      traveledKM: userEntry['distanceTraveledKM'].toDouble()));
            }
          }
          catch (e){
            print(e);
          }

        }
        usersResults.sort((a, b) => b.finalScore.compareTo(a.finalScore));
        return EventResults(usersResults);
      }
      else{
        return null;
      }

    }
    catch (e){
      return null;
    }
}


  Future<GlobalLeaderboardData?> getLeaderboardData() async {
    try{
      QuerySnapshot eventResults = await FirebaseFirestore.instance
          .collection('globalLeaderboard')
          .get();

      if(eventResults.docs.isNotEmpty){

        List<GlobalLeaderboardEntry> usersResults =[];
        for(var doc in eventResults.docs){

          try{

            usersResults.add(
                GlobalLeaderboardEntry(
                    userID: doc.id,
                    displayName: doc['email'],
                    score: doc['score'],
                    traveledKM: doc['distanceTraveled'].toDouble()));
                    }
          catch (e){
            print(e);
          }

        }
        usersResults.sort((a, b) => b.score.compareTo(a.score));
        return GlobalLeaderboardData(usersResults);
      }
      else{
        return null;
      }

    }
    catch (e){
      return null;
    }
  }

  Future<List<UserResults>> getUserEventHistory(String userID) async {
    List<UserResults> results = [];
    QuerySnapshot eventResults = await FirebaseFirestore.instance
        .collection('eventEntries')
        .where('userID', isEqualTo: userID)
        .where('confirmedByAdmin', isEqualTo: true)
        .where('agreedWithRules', isEqualTo: true)
        .where('filledOutProfile', isEqualTo: true)
        .where('registered', isEqualTo: true)
        .get();
      for (var doc in eventResults.docs) {
        try{
          results.add(UserResults(
              finalScore: doc["finalScore"].toInt(),
              userID: userID,
              eventID: doc['eventID'],
              traveledKM: doc["distanceTraveledKM"].toDouble(),
              eventName: doc['eventName'] ?? 'No name'
          ));

        }
        catch(e){
          print(e);
        }


      }
      return results;



  }



}
