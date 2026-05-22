import 'package:flutter/material.dart';
import 'package:koskaki/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Koskaki',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
