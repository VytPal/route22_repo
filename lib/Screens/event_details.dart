// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:moto_events/Models/event.dart';
import 'package:moto_events/Models/eventResults.dart';
import 'package:moto_events/Screens/event_page.dart';
import 'package:moto_events/Services/event_service.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as Path;
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as Loc;
import 'dart:math';
import '../Models/userResults.dart';
import 'package:confetti/confetti.dart';
class EventDetailScreen extends StatefulWidget {
  Event event;

  EventDetailScreen({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool? _isRegistered;
  bool _isLoading = true;
  Map<String, bool>? _userRequirementsStatus;
  final user = FirebaseAuth.instance.currentUser;
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;
  @override
  void initState() {
    super.initState();
    _refreshEvent();
    _checkRegistrationStatus();
    _confettiControllerLeft = ConfettiController(duration: const Duration(seconds: 2));
    _confettiControllerRight = ConfettiController(duration: const Duration(seconds: 2));
  }

  Future<void> _checkRegistrationStatus() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _userRequirementsStatus = await context
        .read<EventsService>()
        .findUserStatusForEventAndUser(widget.event.id, userId);

    setState(() {
      _isRegistered = _userRequirementsStatus?['registered'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _refreshEvent() async {
    widget.event =
        await context.read<EventsService>().fetchEvent(widget.event.id);
  }

  Future<void> _registerForEvent() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String email = FirebaseAuth.instance.currentUser?.email ?? '';
    bool success = await context
        .read<EventsService>()
        .registerForEvent(widget.event.id, userId, email, widget.event.name);
    if (success) {
      setState(() {
        _isRegistered = true;
        _checkRegistrationStatus();
      });
    } else {}
  }

  Loc.Location location = Loc.Location();
  Future<void> _unregisterFromEvent() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool success = await context
        .read<EventsService>()
        .unregisterFromEvent(widget.event.id, userId);
    if (success) {
      setState(() {
        _isRegistered = false;
      });
    } else {}
  }

  Future<bool> _requestPermissions() async {
    Loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == Loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != Loc.PermissionStatus.granted) {
        return false;
      }
    }
    var status = await Permission.locationAlways.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      await Permission.locationAlways.request();
    }
    status = await Permission.locationAlways.status;
    permissionGranted = await location.hasPermission();
    return permissionGranted == Loc.PermissionStatus.granted &&
        (status.isGranted || status.isLimited);
  }

  Future<bool> _checkLocationAndPermissions() async {
    final Loc.Location location = Loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    Loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted != Loc.PermissionStatus.granted) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != Loc.PermissionStatus.granted) {
        return false;
      }
    }

    if (Platform.isAndroid) {
      Loc.PermissionStatus backgroundPermission =
          await location.hasPermission();
      if (backgroundPermission != Loc.PermissionStatus.granted) {
        backgroundPermission = await location.requestPermission();
        if (backgroundPermission != Loc.PermissionStatus.granted) {
          return false;
        }
      }
    }

    return true;
  }

  void _navigateToEventPage() async {
    bool canNavigate = await _checkLocationAndPermissions();

    if (!canNavigate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Center(child: Text('Location Services Required')),
          content: const Text(
              'Please enable location services and grant the background permissions to proceed.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else {
      final userDoc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(user!.uid)
          .get();
      Map<String, dynamic>? userData = userDoc.data();

      if (userData != null &&
          userData['imageUrl'] != null &&
          userData['imageUrl'].toString().isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EventPage(event: widget.event)),
        );
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Center(child: Text('Speedometer image')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        "Before starting event, please upload your speedometer picture"),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final newImageUrl = await _pickAndUploadImage(context);
                        if (newImageUrl.isNotEmpty) {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    EventPage(event: widget.event)),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Image did not upload successfully')),
                          );
                        }
                      },
                      child: const Text('Upload Speedometer Image'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Close'),
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
  }

  void _showLocationPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(child: Text("Location Permission Needed")),
          content: const Text(
              "This app requires background location permission to function properly. Please enable this permission in the app settings.\nPermissions -> Location -> Allow all time"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Open Settings"),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openPreEventCheckSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                "Before you start",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Make sure you have granted background location (ALWAYS) permissions for best results and that your GPS is enabled.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  final bool status = await _requestPermissions();
                  if (status) {
                    _showDialog(context, "Location Permission",
                        "Location permission granted.");
                  } else {
                    Loc.PermissionStatus permissionGranted =
                        await location.hasPermission();
                    if (permissionGranted != Loc.PermissionStatus.granted) {
                      permissionGranted = await location.requestPermission();
                      if (permissionGranted != Loc.PermissionStatus.granted) {
                        _showLocationPermissionDialog(context);
                      }
                    }
                  }
                },
                child: const Text('Grant Location Permissions'),
              ),
              TextButton(
                onPressed: () async {
                  Loc.Location location = Loc.Location();

                  if (!await location.serviceEnabled()) {
                    bool serviceEnabled = await location.requestService();
                    if (!serviceEnabled) {
                      _showDialog(context, "GPS Service",
                          "GPS not enabled. Please enable GPS to proceed.");
                    } else {
                      _showDialog(context, "Location service",
                          "Location service is on.");
                    }
                  } else {
                    _showDialog(
                        context, "Location service", "Location service is on.");
                  }
                },
                child: const Text('Enable GPS'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                ),
                onPressed: _navigateToEventPage,
                child: const Text('Proceed to Event'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(child: Text(title)),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _styledButton(
      {required VoidCallback onPressed, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Container(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            primary: Colors.grey[900],
            onPrimary: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.all(20),
          ),
          child: Text(text),
        ),
      ),
    );
  }

  bool _areAllRequirementsMet() {
    if (_userRequirementsStatus == null) return false;
    return _userRequirementsStatus!.values.every((status) => status);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final eventHasStarted = now.isAfter(widget.event.startTime!);
    final eventHasEnded = widget.event.endTime != null && now.isAfter(widget.event.endTime!);
    final allRequirementsMet = _areAllRequirementsMet();
    final isRegistered = _isRegistered == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        backgroundColor: const Color(0xFF121212),
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFullPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 5),
              Hero(
                tag: 'event_image_${widget.event.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: widget.event.imageUrl != '' ? Image.network(
                    widget.event.imageUrl,
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                    errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                      return  Container();
                    },
                  ) : Container(),
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.headline6?.copyWith(color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event.description,
                      style: Theme.of(context).textTheme.bodyText1,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Starting time: ${DateFormat('yyyy/MM/dd kk:mm').format(widget.event.startTime!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.blueAccent),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Finish: ${DateFormat('yyyy/MM/dd kk:mm').format(widget.event.endTime!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.blueAccent),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              if (!eventHasStarted && !isRegistered)
                _styledButton(onPressed: _registerForEvent, text: 'Register'),
              if ((!eventHasStarted && isRegistered && !allRequirementsMet) ||
                  (eventHasStarted &&
                      !eventHasEnded &&
                      isRegistered &&
                      !allRequirementsMet))
                _buildRequirementsSection(),
              if (eventHasEnded) eventResultsWidget(),
              if ((!eventHasEnded &&
                  isRegistered &&
                  !allRequirementsMet &&
                  !eventHasEnded))
                _styledButton(
                  onPressed: _unregisterFromEvent,
                  text: 'Unregister',
                ),
              if (eventHasStarted && !eventHasEnded && !isRegistered)
                _styledButton(
                  onPressed: _registerForEvent,
                  text: 'Register',
                ),
              if (!eventHasStarted &&
                  isRegistered &&
                  allRequirementsMet &&
                  !eventHasEnded)
                Center(
                  child: Text("Wait for the event to start...",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.green)),
                ),
              if (allRequirementsMet && eventHasStarted && !eventHasEnded)
                _styledButton(
                  onPressed: _openPreEventCheckSheet,
                  text: 'Go to Event',
                ),
            ],
          ),
        ),
      ));
  }




  Future<void> _refreshFullPage() async {
    await _refreshEvent();
    await _checkRegistrationStatus();
  }

  Future<int?> getFinalPosition(String eventID) async {
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('eventResults')
        .doc(eventID)
        .collection('results')
        .doc(user!.uid);

    DocumentSnapshot doc = await docRef.get();

    if (doc.exists) {
      return doc.get('finalPosition');
    }
    return 0;
  }

  Future<String> fetchEventRules(String eventId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('eventData')
        .doc(eventId)
        .get();
    if (docSnapshot.exists && docSnapshot.data()!.containsKey('rules')) {
      return docSnapshot.data()!['rules'];
    } else {
      return "No rules available.";
    }
  }

  Future<void> _showRulesDialog(BuildContext context) async {
    String rules = await fetchEventRules(widget.event.id);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(child: Text('Event Rules')),
          content: SingleChildScrollView(
            child: Text(
              rules,
              textAlign: TextAlign.justify,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Accept'),
              onPressed: () {
                updateUserAgreementStatus(widget.event.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> updateUserAgreementStatus(String eventId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('eventEntries')
        .where('eventID', isEqualTo: widget.event.id)
        .where('userID', isEqualTo: user!.uid)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.set({
        'agreedWithRules': true,
      }, SetOptions(merge: true));
      _checkRegistrationStatus();
    }
  }

  Widget _buildRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 10,
        ),
        Center(
          child: Text('Requirements:',
              style: Theme.of(context).textTheme.headline6),
        ),
        if (_userRequirementsStatus != null) ...[
          _requirementListTile(
              'Registered', _userRequirementsStatus?['registered'] ?? false),
          _requirementListTile('Confirmed by Organisator',
              _userRequirementsStatus?['confirmedByAdmin'] ?? false),
          _requirementListTile('Profile filled out',
              _userRequirementsStatus?['filledOutProfile'] ?? false),
          if (!(_userRequirementsStatus?['filledOutProfile'] ?? false))
            Center(
              child: TextButton(
                onPressed: _openFillOutProfileDialog,
                child: const Text('Update profile'),
              ),
            ),
          _requirementListTile('Agreed with Rules',
              _userRequirementsStatus?['agreedWithRules'] ?? false),
          if (!(_userRequirementsStatus?['agreedWithRules'] ?? false))
            Center(
              child: TextButton(
                onPressed: () => _showRulesDialog(context),
                child: const Text('Agree with rules'),
              ),
            ),
        ]
      ],
    );
  }

  Widget _requirementIcon(bool status) {
    return Icon(
      status ? Icons.check : Icons.close,
      color: status ? Colors.green : Colors.red,
    );
  }

  Widget _requirementListTile(String title, bool status) {
    return ListTile(
      leading: _requirementIcon(status),
      title: Text(title),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<Map<String, dynamic>> fetchUserProfile() async {
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(user!.uid)
          .get();
      Map<String, dynamic>? userData = userDoc.data();

      Map<String, dynamic> profileData = {};
      if (userData != null) {
        if (userData.containsKey('fullName') &&
            userData['fullName'].toString().isNotEmpty) {
          profileData['fullName'] = userData['fullName'];
        }
        if (userData.containsKey('vehicleNumber') &&
            userData['vehicleNumber'].toString().isNotEmpty) {
          profileData['vehicleNumber'] = userData['vehicleNumber'];
        }
        if (userData.containsKey('imageUrl') &&
            userData['imageUrl'].toString().isNotEmpty) {
          profileData['imageUrl'] = userData['imageUrl'];
        }
        if (userData.containsKey('yearOfMake') &&
            userData['yearOfMake'].toString().isNotEmpty) {
          profileData['yearOfMake'] = userData['yearOfMake'];
        }
        return profileData;
      } else {
        return {};
      }
    } else {
      return {};
    }
  }

  Future<void> _openFillOutProfileDialog() async {
    final profileData = await fetchUserProfile();
    final TextEditingController _fullNameController =
        TextEditingController(text: profileData['fullName'] ?? '');
    final TextEditingController _vehicleNumberController =
        TextEditingController(text: profileData['vehicleNumber'] ?? '');
    final TextEditingController _vehicleYearController =
        TextEditingController(text: profileData['yearOfMake'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Center(child: Text('Complete Your Profile')),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Please complete your profile details.'),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _vehicleNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _vehicleYearController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Year of Make',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Complete Profile'),
              onPressed: () {
                _showLoadingDialog(context, 'Updating profile...');
                saveProfileData(context, _fullNameController,
                        _vehicleNumberController, _vehicleYearController)
                    .then(
                        (_) => Navigator.of(context, rootNavigator: true).pop())
                    .then((_) => checkAndUpdateProfileStatus());
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> checkAndUpdateProfileStatus() async {
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(user!.uid)
          .get();
      Map<String, dynamic>? userData = userDoc.data();

      bool hasFullName = userData?['fullName'] != null &&
          userData!['fullName'].toString().isNotEmpty;
      bool hasVehicleNumber = userData!['vehicleNumber'] != null &&
          userData['vehicleNumber'].toString().isNotEmpty;

      if (hasFullName && hasVehicleNumber) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('eventEntries')
            .where('eventID', isEqualTo: widget.event.id)
            .where('userID', isEqualTo: user!.uid)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.set({
            'filledOutProfile': true,
          }, SetOptions(merge: true));
          _checkRegistrationStatus();
        }
      }
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

  Future<String> _pickAndUploadImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    final user = FirebaseAuth.instance.currentUser;

    if (pickedFile != null && user != null) {
      _showLoadingDialog(context, 'Uploading image...');
      File imageFile = File(pickedFile.path);
      String fileName = Path.basename(imageFile.path);
      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child('uploads/${user.uid}/$fileName');
      UploadTask uploadTask = firebaseStorageRef.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask;
      String imageUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('usersData')
          .doc(user.uid)
          .set({
        'imageUrl': imageUrl,
      }, SetOptions(merge: true));
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
      return imageUrl;
    }
    return "";
  }

  Future<void> saveProfileData(
      BuildContext context,
      TextEditingController _fullNameController,
      TextEditingController _vehicleNumberController,
      TextEditingController _vechileyearOfMakeController) async {
    String fullName = _fullNameController.text;
    String vehicleNumber = _vehicleNumberController.text;
    String yearOfmake = _vechileyearOfMakeController.text;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('usersData')
          .doc(user.uid)
          .set({
        'fullName': fullName,
        'vehicleNumber': vehicleNumber,
        'yearOfMake': yearOfmake
      }, SetOptions(merge: true)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $error')),
        );
      });
    }
  }

  Widget eventResultsWidget() {

    return FutureBuilder<EventResults?>(
      future: context.read<EventsService>().getEventResults(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Center(child: Text('An error occurred'));
        } else if (snapshot.hasData) {
          EventResults? eventResults = snapshot.data;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FutureBuilder<int?>(
                future: getFinalPosition(widget.event.id),
                builder: (context, positionSnapshot) {
                  if (positionSnapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (positionSnapshot.hasError) {
                    return const Text('An error occurred');
                  } else {

                    if (positionSnapshot.data != null && positionSnapshot.data! <= 3 && positionSnapshot.data! > 0) {
                      _confettiControllerLeft.play();
                      _confettiControllerRight.play();
                    }
                    return Stack(
                      children: [
                        Align(
                        alignment: Alignment.centerLeft,
                      child: ConfettiWidget(
                        confettiController: _confettiControllerLeft,
                        blastDirection: pi / 2,
                        maxBlastForce: 6,
                        minBlastForce: 5,
                        numberOfParticles: 25,
                        gravity: 0.1,
                        colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConfettiWidget(
                        confettiController: _confettiControllerRight,
                        blastDirection: -pi / 2,
                        maxBlastForce: 6,
                        minBlastForce: 5,
                        numberOfParticles: 25,
                        gravity: 0.1,
                        colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                      ),
                    ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Event has ended', textAlign: TextAlign.center),
                            if (positionSnapshot.hasData && positionSnapshot.data != 0)
                              Text('You have placed #${positionSnapshot.data}', style: Theme.of(context).textTheme.bodyText1?.copyWith(color: Colors.green)),
                            if (eventResults != null)
                              Column(
                                children: [
                                  const SizedBox(height: 15),
                                  Text('Results', style: Theme.of(context).textTheme.headline6?.copyWith(color: Colors.blueAccent)),
                                  leaderboardWidget(eventResults),
                                ],
                              ),
                          ],
                        ),

                      ],
                    );
                  }
                },
              ),
            ],
          );
        } else {
          return const Center(child: Text('No results found'));
        }
      },
    );
  }

  Widget leaderboardWidget(EventResults eventResults) {
    return Center(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: eventResults.userList.length,
        itemBuilder: (context, index) {
          return buildLeaderboardEntry(context, eventResults.userList[index], index);
        },
      ),
    );
  }

  Widget buildLeaderboardEntry(BuildContext context, UserResults user, int index) {
    ThemeData theme = Theme.of(context);
    Color backgroundColor;
    switch (index) {
      case 0:
        backgroundColor = Colors.amber[800]!;
        break;
      case 1:
        backgroundColor = Colors.grey[300]!;
        break;
      case 2:
        backgroundColor = Colors.brown[600]!;
        break;
      default:
        backgroundColor = theme.colorScheme.secondaryContainer;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: backgroundColor,
          child: Text('#${index + 1}', style: TextStyle(color: Colors.black)),
        ),
        title: Center(child: Text(user.displayName ?? 'Anonymous User', style: theme.textTheme.headline6),),
        subtitle: Center(child: Text(
          'Score: ${user.finalScore}, Traveled: ${user.traveledKM} KM',
          style: theme.textTheme.subtitle2,
        )),


      ),
    );
  }
}
