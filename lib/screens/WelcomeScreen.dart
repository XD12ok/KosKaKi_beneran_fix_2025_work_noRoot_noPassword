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
  bool hideStartText = false;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          /// Logo Mambu
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Image.asset(
                  "assets/logo1.png",
                  height: 150,
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

          /// Orang
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            bottom: startAnimation ? 140 : 200,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/people.png",
              height: 300,
            ),
          ),

          /// Biru Biru Gatel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            bottom: startAnimation ? -250 : -150,
            left: startAnimation ? -220 : -140,
            right: startAnimation ? -220 : -140,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              height: startAnimation ? 700 : 395,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E50),
                borderRadius: BorderRadius.circular(800), // jare gpt ngene
              ),
            ),
          ),

          /// Tombol Ayo Mulai
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            bottom: startAnimation ? -(height * 0.25) : 80,
            left: 30,
            right: 30,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                ),
                const SizedBox(height: 10),
                const Text(
                  "Buat manajemen anda lebih baik dengan KosKaKi",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          /* if (showRoles)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              bottom: 50,sad
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
                          builder: (_) => const OwnerHomePage(), // langsung ke halaman pemilik
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  _roleButton(
                    "Masuk sebagai penghuni",
                    Icons.people,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ), */

          /// Tombol Pemilik & Anak Kos
          if (showRoles)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              bottom: 50,
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
                          builder: (_) => const SignUpPage(role: "owner"),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  _roleButton(
                    "Masuk sebagai penghuni",
                    Icons.people,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const SignUpPage(role: "residents"),
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

  Widget _roleButton(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              size: 40,
              color: Colors.blue,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
