import 'package:flutter/material.dart';
import 'package:koskaki/screens/auth/signup_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool startAnimation = false;
  bool showRoles = false;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // logo
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Image.asset(
                  "assets/logo.png",
                  height: 120,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Kost Kontrakan Kita",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                )
              ],
            ),
          ),

          // animasi orng turun
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            bottom: startAnimation ? -(height * 0.25) : 30,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/people.png",
              height: 260,
            ),
          ),

          // wave biru
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            bottom: startAnimation ? 0 : -300,
            left: -100,
            right: -100,
            child: Container(
              height: 600,
              decoration: const BoxDecoration(
                color: Color(0xFF0A0E50),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ayomulai btn
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            bottom: startAnimation ? -(height * 0.25) : 80,
            left: 30,
            right: 30,
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    setState(() => startAnimation = true);

                    Future.delayed(const Duration(milliseconds: 700), () {
                      setState(() => showRoles = true);
                    });
                  },
                  child: const Text(
                    "Ayo Mulai!",
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Buat manajemen anda lebih baik dengan KosKaKi",
                  style: TextStyle(color: Colors.black54),
                )
              ],
            ),
          ),

          // role btn
          if (showRoles)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              bottom: 150,
              left: 30,
              right: 30,
              child: Column(
                children: [
                  _roleButton(
                    "Masuk sebagai pemilik",
                    Icons.home,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpPage(role: "pemilik"),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _roleButton(
                    "Masuk sebagai penghuni",
                    Icons.people,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpPage(role: "penghuni"),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Tombol role
  Widget _roleButton(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
