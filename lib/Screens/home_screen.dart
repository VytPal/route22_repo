import 'package:flutter/material.dart';
import 'package:moto_events/Screens/events_screen.dart';
import 'package:moto_events/Screens/main_screen.dart';
import 'package:moto_events/Screens/profile_page.dart';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moto_events/Services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.index != _tabController.previousIndex) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text("Route 22"),
        scrolledUnderElevation: 0.0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MainPage(),
          EventListPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 4,
        backgroundColor: Colors.black45,
        currentIndex: _tabController.index,
        selectedItemColor: Colors.white,
        onTap: (index) {
          setState(() {
            _tabController.animateTo(index);
          });
        },
        showSelectedLabels: true,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: _tabController.index == 0 ? 30 : 24),
            label: 'Main',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event, size: _tabController.index == 1 ? 30 : 24),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: _tabController.index == 2 ? 30 : 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

