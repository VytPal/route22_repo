// ignore_for_file: use_build_context_synchronously

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:moto_events/Models/gloabalLeaderboardData.dart';
import 'package:moto_events/Models/globalLeaferboardEntry.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import 'package:location/location.dart' as Loc;
import 'package:provider/provider.dart';

import '../Models/eventResults.dart';
import '../Models/userResults.dart';
import '../Services/event_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});



  @override
  MainPageState createState() => MainPageState();
}
class MainPageState extends State<MainPage> {
  Loc.Location location = Loc.Location();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 15),
                const Text(
                  'Welcome to Route22!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'This app uses foreground and background location permissions to track your journey during events. Please grant permissions for the best experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final bool status = await _requestPermissions();
                    if (status) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location permission granted')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please grant location permissions')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    elevation: 5,
                  ),
                  child: const Text('Grant Location Permissions'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => openBrowserTab('https://sites.google.com/view/1000km-policy/pagrindinis-puslapis'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.green,
                    onPrimary: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    elevation: 5,
                  ),
                  child: const Text('Privacy Policy'),
                ),
                const SizedBox(height: 30),
                leaderboard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void openBrowserTab(String url) async {
    await FlutterWebBrowser.openWebPage(
      url: url,
      customTabsOptions: const CustomTabsOptions(
        colorScheme: CustomTabsColorScheme.dark,
        toolbarColor: Colors.deepPurple,
        secondaryToolbarColor: Colors.green,
        navigationBarColor: Colors.amber,
        addDefaultShareMenuItem: true,
        instantAppsEnabled: true,
        showTitle: true,
        urlBarHidingEnabled: true,
      ),
      safariVCOptions: const SafariViewControllerOptions(
        barCollapsingEnabled: true,
        preferredBarTintColor: Colors.deepPurple,
        preferredControlTintColor: Colors.white,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        modalPresentationCapturesStatusBarAppearance: true,
      ),
    );
  }
   Widget leaderboard() {
     return FutureBuilder<GlobalLeaderboardData?>(
       future: context.read<EventsService>().getLeaderboardData(),
       builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
           return const CircularProgressIndicator();
         } else if (snapshot.hasError) {
           return const Center(child: Text('An error occurred'));
         } else if (snapshot.hasData) {
           GlobalLeaderboardData? leaderboardData = snapshot.data;
           if(leaderboardData != null) {
             return leaderboardWidget(leaderboardData);
           }
           else{
             return Container();
           }
         }
         else {
           return const Center(child: Text('No results found'));
         }
       },
     );
   }

  Widget leaderboardWidget(GlobalLeaderboardData leaderboardData) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            "Top scoring drivers",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        CarouselSlider(
          options: CarouselOptions(
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            aspectRatio: 2.5,
            autoPlayInterval: const Duration(seconds: 3),
          ),
          items: leaderboardData.userList.map((user_) {
            return Builder(
              builder: (BuildContext context) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 6,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16, left: 10),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: getMedalColor(user_, leaderboardData),
                            child: Text('#${leaderboardData.userList.indexOf(user_) + 1}', style: const TextStyle(fontSize: 20, color: Colors.black)),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user_.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Score: ${user_.score}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                              Text('Traveled: ${user_.traveledKM} KM', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Color getMedalColor(GlobalLeaderboardEntry user, GlobalLeaderboardData leaderboardData) {
    int rank = leaderboardData.userList.indexOf(user) + 1;
    switch (rank) {
      case 1:
        return const Color.fromRGBO(218, 165, 32, 1);
      case 2:
        return const Color.fromRGBO(192, 192, 192, 1);
      case 3:
        return const Color.fromRGBO(205, 127, 50, 1);
      default:
        return Colors.grey.shade300;
    }
  }
}


