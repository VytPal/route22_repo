import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:moto_events/Screens/home_screen.dart';
import 'package:moto_events/Screens/login_screen.dart';
import 'package:moto_events/Services/auth_service.dart';
import 'package:moto_events/Services/event_service.dart';
import 'package:moto_events/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => EventsService()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Route 22',
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.latoTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
      ),
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (authService.user == null) {
            return LoginScreen();
          }
          return HomeScreen(user: authService.user!);
        },
      ),
    );
  }
}
