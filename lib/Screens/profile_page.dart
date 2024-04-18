import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../Models/userResults.dart';
import '../Services/event_service.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  List<UserResults> eventHistory = [];
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _loadEventHistory();
    }
  }

  Future<void> _loadEventHistory() async {
    setState(() {
      _isLoading = true;
    });

    eventHistory = await context.read<EventsService>().getUserEventHistory(user!.uid);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(user?.photoURL ?? 'https://via.placeholder.com/150'),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? '',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? '',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:  [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                  ),
                  onPressed: () {},
                  child: const Text('Edit Profile'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                  ),
                  onPressed: () {},
                  child: const Text('Settings'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Event History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: eventHistory.length,
              itemBuilder: (context, index) {
                final event = eventHistory[index];
                return ListTile(
                  leading: const Icon(Icons.event),
                  title: Text('${event.eventName}'),
                  subtitle: Text('Score: ${event.finalScore}, Traveled: ${event.traveledKM} KM'),
                  onTap: () {
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
