import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
import 'package:koskaki/screens/Owner/OwnerPage.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase (kalau masih dipakai)
  await Supabase.initialize(
    url: 'https://ggawtlojbtrlyxudenvw.supabase.co',
    anonKey: 'YOUR_KEY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CheckAuthPage(), // 🔥 AUTO LOGIN
    );
  }
}

class Decider extends StatefulWidget {
  const Decider({super.key});

  @override
  State<CheckAuthPage> createState() => _CheckAuthPageState();
}

class _CheckAuthPageState extends State<CheckAuthPage> {

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final api = ApiService();

    // ✅ CEK TOKEN
    final token = await api.getToken();

    if (token == null) {
      _goToWelcome();
      return;
    }

    // ✅ CEK USER
    final user = await api.getUser();

    if (user == null) {
      await api.removeToken();
      _goToWelcome();
      return;
    }

    final role = user['role'];

    if (role == "residents") {
      _goToHome();
    } else {
      _goToOwner();
    }
  }

  void _goToWelcome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _goToOwner() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OwnerHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}