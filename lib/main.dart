import 'package:flutter/material.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class  MyApp extends StatelessWidget {
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

    final firstTime = prefs.getBool("first_time") ?? true;
    final logged = prefs.getBool("logged_in") ?? false;

    setState(() {
      isFirstTime = firstTime;
      isLoggedIn = logged;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstTime == null || isLoggedIn == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isFirstTime!) {
      return WelcomeScreen();
    }

    // if (isLoggedIn!) {
    //   return HomePage();
    // }

    return WelcomeScreen();
  }
}
