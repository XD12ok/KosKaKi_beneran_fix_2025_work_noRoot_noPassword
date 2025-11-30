import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Init Supabase
  await Supabase.initialize(
    url: 'https://ggawtlojbtrlyxudenvw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdnYXd0bG9qYnRybHl4dWRlbnZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MDU4OTMsImV4cCI6MjA3OTE4MTg5M30.c3G4egt7CTCSL2oX65F_XMWmnDdtQUdN_VBdlyy7Aag',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Decider(),
    );
  }
}

class Decider extends StatefulWidget {
  @override
  _DeciderState createState() => _DeciderState();
}

class _DeciderState extends State<Decider> {
  bool? isFirstTime;
  bool? isLoggedIn;

  @override
  void initState() {
    super.initState();
    checkStatus();
  }

  void checkStatus() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      isFirstTime = prefs.getBool("first_time") ?? true;
      isLoggedIn = prefs.getBool("logged_in") ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstTime == null || isLoggedIn == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WelcomeScreen();
  }
}
