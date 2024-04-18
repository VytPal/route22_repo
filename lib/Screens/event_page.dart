// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as Loc;
import 'package:map_launcher/map_launcher.dart';
import 'package:moto_events/Models/event.dart';
import 'package:moto_events/Models/eventMarker.dart';
import 'package:moto_events/Services/markers_servive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/location_service.dart';

class EventPage extends StatefulWidget {
  final Event event;

  EventPage({Key? key, required this.event}) : super(key: key);

  @override
  EventPageState createState() => EventPageState();
}

class EventPageState extends State<EventPage> {
  LocationService locationService = LocationService();
  MapController mapController = MapController();
  MarkersService markersService = MarkersService();
  LatLng? currentLocation;
  List<Marker> mapMarkers = [];
  List<EventMarker> markers = [];
  List<String> markersVisitedIds = [];
  Loc.Location location = Loc.Location();
  Stream<LocationMarkerPosition> get locationUpdates =>
      _locationUpdatesController.stream;
  final StreamController<LocationMarkerPosition> _locationUpdatesController =
      StreamController<LocationMarkerPosition>.broadcast();
  bool _isControllerClosed = false;
  StreamSubscription<Loc.LocationData>? streamas;
  double distanceTraveled = 0.0;
  Loc.LocationData? previousLocation;
  @override
  void initState() {
    super.initState();
    loadMarkers();

    getGpsStatus();
  }

  @override
  void dispose() {
    _isControllerClosed = true;
    _locationUpdatesController.close();
    streamas?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Stack(
        children: <Widget>[
          Positioned(
            bottom: 80,
            right: 10,
            child: FloatingActionButton(
              heroTag: 'moveToTag',
              onPressed: () {
                if (currentLocation?.latitude != null &&
                    currentLocation?.longitude != null) {
                  mapController.move(
                      LatLng(currentLocation!.latitude,
                          currentLocation!.longitude),
                      15);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: FloatingActionButton(
              heroTag: 'showMarkerList',
              onPressed: () {
                _attemptToShowMarkersList();
              },
              child: const Icon(Icons.list),
            ),
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(widget.event.name),
      ),
      body: FlutterMap(
        mapController: mapController,
        options: const MapOptions(
          initialCenter: LatLng(55.225189110210145, 24.089166637105627),
          initialZoom: 6.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          CurrentLocationLayer(
            positionStream: locationUpdates,
          ),
          MarkerLayer(markers: mapMarkers),
        ],
      ),
    );
  }

  Future<void> _listenLocation() async {
    location.enableBackgroundMode(enable: true);
    location.changeSettings(
        interval: 5000,
        accuracy: Loc.LocationAccuracy.high,
        distanceFilter: 100);
    streamas = location.onLocationChanged.handleError((onError) {
      streamas?.cancel();
      setState(() {
        streamas = null;
      });
    }).listen((Loc.LocationData currentLocation) async {
      if (!_isControllerClosed &&
          currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        var connectivityResult = await (Connectivity().checkConnectivity());
        await _uploadStoredLocations();
        if (previousLocation != null) {
          final distance = calculateDistance(
            previousLocation!.latitude!,
            previousLocation!.longitude!,
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
          distanceTraveled += distance;
        }

        previousLocation = currentLocation;

        final position = LocationMarkerPosition(
          latitude: currentLocation.latitude!,
          longitude: currentLocation.longitude!,
          accuracy: 1,
        );
        this.currentLocation =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
        _locationUpdatesController.add(position);
        if (connectivityResult == ConnectivityResult.none) {
          final prefs = await SharedPreferences.getInstance();
          List<String> storedLocations = prefs.getStringList('storedLocations') ?? [];
          Map<String, dynamic> locationMap = {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'distanceTraveled': distanceTraveled
          };
          storedLocations.add(json.encode(locationMap));
          await prefs.setStringList('storedLocations', storedLocations);
        }
        else {
          uploadLocationToFirebase(currentLocation, widget.event.id);
        }
      } else {}
    });
  }
  Future<void> _uploadStoredLocations() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> storedLocations = prefs.getStringList('storedLocations') ?? [];

    if (storedLocations.isNotEmpty) {
      for (String locationJson in storedLocations) {
        Map<String, dynamic> locationMap = json.decode(locationJson);

        var userID = FirebaseAuth.instance.currentUser?.uid;
        if (userID == null) {
          print("Missing data for Firestore upload.");
          return;
        }

        DocumentReference eventDocRef =
        FirebaseFirestore.instance.collection('events').doc(widget.event.id);

        CollectionReference userLocationsCollection = eventDocRef
            .collection('userCoords')
            .doc(userID)
            .collection('locations');
        Loc.LocationData locationData = Loc.LocationData.fromMap({
          'latitude': locationMap['latitude'],
          'longitude': locationMap['longitude'],
        });
        userLocationsCollection.add({
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
          'timestamp': DateTime.fromMillisecondsSinceEpoch(locationMap['timestamp']),
          'distanceTraveled': locationMap['distanceTraveled'],
        }).then((docRef) {
          print("Location update added with ID: ${docRef.id}");
        }).catchError((error) {
          print("Error adding location update: $error");
        });
      }

      fetchLatestPoint();
      await prefs.remove('storedLocations');
    }
  }
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return const Distance()
        .as(LengthUnit.Meter, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }


  Future<void> getGpsStatus() async {
    final serviceEnabled = await location.serviceEnabled();
    await fetchLatestPoint();
    if (!serviceEnabled) {
      final result = await location.requestService();
      if (result == true) {
        print('Service has been enabled');
        _listenLocation();
      } else {
        throw Exception('GPS service not enabled');
      }
    } else {
      _listenLocation();
    }
  }

  Future<void> fetchLatestPoint() async {
    var userID = FirebaseAuth.instance.currentUser?.uid;
    try {
      DocumentReference eventDocRef =
          FirebaseFirestore.instance.collection('events').doc(widget.event.id);

      final querySnapshot = await eventDocRef
          .collection('userCoords')
          .doc(userID)
          .collection('locations')
          .orderBy('timestamp',
              descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        distanceTraveled = 0.0;
        previousLocation = null;
      } else {
        final latestDoc = querySnapshot.docs.first;
        final latestData = latestDoc.data();
        final lat = latestData['latitude'] as double;
        final lon = latestData['longitude'] as double;
        distanceTraveled = latestData['distanceTraveled'] as double? ??
            0.0;
        previousLocation = Loc.LocationData.fromMap({
          'latitude': lat,
          'longitude': lon,
        });
      }
    } catch (e) {
      print("Error fetching latest point from Firebase: $e");
    }
  }
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> uploadLocationToFirebase(
      Loc.LocationData locationData, String eventID) async {
    var userID = FirebaseAuth.instance.currentUser?.uid;
    if (userID == null) {
      print("Missing data for Firestore upload.");
      return;
    }

    var timestamp = FieldValue.serverTimestamp();

    DocumentReference eventDocRef =
        FirebaseFirestore.instance.collection('events').doc(eventID);

    CollectionReference userLocationsCollection = eventDocRef
        .collection('userCoords')
        .doc(userID)
        .collection('locations');

    userLocationsCollection.add({
      'latitude': locationData.latitude,
      'longitude': locationData.longitude,
      'timestamp': timestamp,
      'distanceTraveled': distanceTraveled,
    }).then((docRef) {
      print("Location update added with ID: ${docRef.id}");
    }).catchError((error) {
      print("Error adding location update: $error");
    });
  }

  Future<void> _showMapChoices(double latitude, double longitude) async {
    final availableMaps = await MapLauncher.installedMaps;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Wrap(
              children: <Widget>[
                for (var map in availableMaps)
                  ListTile(
                    leading: const Icon(Icons.map),
                    title: Text(map.mapName),
                    onTap: () => map.showMarker(
                      coords: Coords(latitude, longitude),
                      title: "Destination",
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> loadMarkers() async {
    await loadVisitedMarkers();
    var eventMarkers = await markersService.getMarkersForEvent(widget.event.id);
    markers.addAll(eventMarkers);
    setState(() {
      mapMarkers.clear();
      mapMarkers.addAll(eventMarkers.map(
        (e) => Marker(
          point: LatLng(e.latitude, e.longitude),
          width: 80.0,
          height: 80.0,
          child: GestureDetector(
            onTap: () {
              mapController.moveAndRotate(
                  LatLng(e.latitude, e.longitude), 15.0, 0);
              showMarkerInfo(e);
            },
            child: markersVisitedIds.contains(e.id)
                ? const Icon(Icons.check_circle,
                    color: Colors.green)
                : const Icon(Icons.location_pin,
                    color: Colors.red),
          ),
        ),
      ));
    });
  }

  Future<void> loadVisitedMarkers() async {
    String userID = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userID.isNotEmpty) {
      try {
        var querySnapshot = await FirebaseFirestore.instance
            .collection('eventVisitedMarkers')
            .doc(widget.event.id)
            .collection(userID)
            .get();

        List<String> visitedMarkers = querySnapshot.docs.map((doc) {
          Map<String, dynamic>? data = doc.data();
          return data["markerID"].toString();
        }).toList();
        setState(() {
          markersVisitedIds.addAll(visitedMarkers);
        });
        print(markersVisitedIds);
      } catch (e) {
        print("Error fetching visited markers: $e");
      }
    }
  }

  void _showMarkersListBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        if (currentLocation == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Getting location..."),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: markers.length,
          itemBuilder: (context, index) {
            final marker = markers[index];
            final distanceMeters = const Distance().as(LengthUnit.Meter,
                currentLocation!, LatLng(marker.latitude, marker.longitude));
            final distanceKilometers = distanceMeters / 1000;
            bool isVisited =
                markersVisitedIds.contains(marker.id);

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: isVisited
                    ? const Icon(Icons.check_circle,
                        color: Colors.green)
                    : const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                      ),
                title: Text(marker.name),
                subtitle:
                    Text("${distanceKilometers.toStringAsFixed(3)} km away"),
                trailing: IconButton(
                  icon: const Icon(Icons.navigation),
                  onPressed: () {
                    _showMapChoices(marker.latitude, marker.longitude);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _attemptToShowMarkersList() {
    if (currentLocation == null) {

    } else {
      _showMarkersListBottomSheet(context);
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    final Distance distance = const Distance();
    return distance.as(
        LengthUnit.Kilometer, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  void showMarkerInfo(EventMarker marker) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        bool isVisited = markersVisitedIds.contains(marker.id);

        return Container(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(marker.name),
                subtitle: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text("Lat: ${marker.latitude}"),
                    Text(
                        "Long: ${marker.longitude}"),
                  ],
                ),
                trailing: isVisited
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: () {
                          Navigator.pop(context);
                          openCamera(marker);
                        },
                      ),
              ),
              if (isVisited)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(
                      child: Text("You have already visited this marker.",
                          style: TextStyle(color: Colors.green))),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> openCamera(EventMarker marker) async {
    final ImagePicker _picker = ImagePicker();
    String eventID =
        widget.event.id;
    String markerID = marker
        .id;

    if (currentLocation == null) {
      print("Current location is not available.");
      return;
    }

    final Distance distance = const Distance();
    final double meters = distance(
      LatLng(currentLocation!.latitude, currentLocation!.longitude),
      LatLng(marker.latitude, marker.longitude),
    );

    if (meters <= 200) {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _showLoadingDialog(context, "Uploading image...");
        await uploadPhoto(
            photo, eventID, markerID);
        Navigator.of(context).pop();
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 10),
                Text("Too Far Away"),
              ],
            ),
            content: const Text(
                "You are too far from the marker. You need to be atleast 200m away from the location. "),
            actions: <Widget>[
              TextButton(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check,
                        color: Colors.green),
                    SizedBox(width: 4),
                    Text("OK"),
                  ],
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> uploadPhoto(XFile photo, String eventID, String markerID) async {
    String userID = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userID.isEmpty) {
      return;
    }

    String fileName = "$eventID-${DateTime.now().millisecondsSinceEpoch}";
    String fullPath = 'eventVisitedMarkers/$eventID/$userID/$fileName';

    try {
      TaskSnapshot uploadTask = await FirebaseStorage.instance
          .ref(fullPath)
          .putFile(File(photo.path));
      String downloadURL = await uploadTask.ref.getDownloadURL();

      await saveMarkerVisit(eventID, userID, downloadURL, markerID);

      EventMarker? visitedMarker =
          markers.firstWhereOrNull((e) => e.id == markerID);
      if (visitedMarker != null && !markersVisitedIds.contains(markerID)) {
        setState(() {
          markersVisitedIds.add(markerID);
        });
        EventMarker marker = markers.firstWhere((element) => element.id == markerID);
        updateFinalScore(eventID, userID, marker.points);
        refreshMarkers();
      }

    } catch (e) {
      print("Error uploading photo: $e");
    }
  }
  Future<void> updateFinalScore(String eventID, String userID, int points) async {

    FirebaseFirestore firestore = FirebaseFirestore.instance;

    QuerySnapshot eventEntries = await firestore
        .collection('eventEntries')
        .where('eventID', isEqualTo: eventID)
        .where('userID', isEqualTo: userID)
        .get();

    if (eventEntries.docs.isNotEmpty) {

      DocumentSnapshot entry = eventEntries.docs.first;

      int currentScore = entry.get('finalScore') ?? 0;

      int newScore = currentScore + points;

      await firestore
          .collection('eventEntries')
          .doc(entry.id)
          .update({'finalScore': newScore});
    }
  }
  void refreshMarkers() {
    setState(() {
      mapMarkers.clear();
      mapMarkers.addAll(markers.map(
        (e) => Marker(
          point: LatLng(e.latitude, e.longitude),
          width: 80.0,
          height: 80.0,
          child: GestureDetector(
            onTap: () {
              mapController.moveAndRotate(
                  LatLng(e.latitude, e.longitude), 15.0, 0);
              showMarkerInfo(e);
            },
            child: markersVisitedIds.contains(e.id)
                ? const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  )
                : const Icon(Icons.location_pin,
                    color: Colors.red),
          ),
        ),
      ));
    });
  }

  Future<void> saveMarkerVisit(
      String eventID, String userID, String photoURL, String markerID) async {
    try {
      await FirebaseFirestore.instance
          .collection('eventVisitedMarkers')
          .doc(eventID)
          .collection(userID)
          .add({
        'photoURL': photoURL,
        'timestamp':
            FieldValue.serverTimestamp(),
        'markerID': markerID,
      });
      print("Marker visit saved.");
    } catch (e) {
      print("Error saving marker visit: $e");
    }
  }
}
