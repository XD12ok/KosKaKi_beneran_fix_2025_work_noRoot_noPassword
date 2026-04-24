import 'package:flutter/material.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
import 'package:koskaki/screens/Owner/OwnerPage.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';

class CheckAuthPage extends StatefulWidget {
  const CheckAuthPage({super.key});

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
    
    final token = await api.getToken();

    if (token == null) {
      _goToWelcome();
      return;
    }

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
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}