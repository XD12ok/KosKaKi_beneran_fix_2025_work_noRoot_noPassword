import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:koskaki/screens/auth/signup_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool startAnimation = false;
  bool showRoles = false;

  late final AnimationController _floatingController;

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF1D4ED8);
  final Color accentColor = const Color(0xFF64D2FF);

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  void _startWelcomeAnimation() {
    if (startAnimation) return;

    setState(() {
      startAnimation = true;
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;

      setState(() {
        showRoles = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;

    final bool isSmallScreen = height < 720;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF5F8FF),
                  Color(0xFFEAF2FF),
                ],
              ),
            ),
          ),

          /// DEKORASI BACKGROUND
          Positioned(
            top: -70,
            right: -60,
            child: _softCircle(size: 180, color: secondColor.withOpacity(0.10)),
          ),

          Positioned(
            top: 150,
            left: -45,
            child: _softCircle(size: 115, color: accentColor.withOpacity(0.20)),
          ),

          Positioned(
            top: 305,
            right: 28,
            child: _softCircle(size: 28, color: secondColor.withOpacity(0.18)),
          ),

          /// LOGO TENGAH TANPA CARD
          AnimatedPositioned(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            top: startAnimation
                ? (isSmallScreen ? 22 : 28)
                : (isSmallScreen ? 34 : 42),
            left: 24,
            right: 24,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              scale: startAnimation ? 0.88 : 1,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 450),
                opacity: showRoles ? 0.95 : 1,
                child: Column(
                  children: [
                    Image.asset(
                      "assets/logo1.png",
                      height: isSmallScreen ? 130 : 165,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Kost Kontrakan Kita",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 22,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "Cari dan kelola kost lebih mudah",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.5 : 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// GAMBAR ORANG
          /// DITARUH SEBELUM WARNA BIRU SUPAYA ADA DI BELAKANG WARNA BIRU
          AnimatedPositioned(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            bottom: startAnimation
                ? (isSmallScreen ? 200 : 230)
                : (isSmallScreen ? 105 : 118),
            left: -52,
            right: -52,
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final double dy =
                    math.sin(_floatingController.value * 2 * math.pi) * 8;

                return Transform.translate(offset: Offset(0, dy), child: child);
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                scale: startAnimation ? 0.95 : 1,
                child: Image.asset(
                  "assets/people.png",
                  height: isSmallScreen ? 355 : 430,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          /// BENTUK BIRU BESAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
            bottom: startAnimation ? -315 : -165,
            left: startAnimation ? -250 : -145,
            right: startAnimation ? -250 : -145,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              height: startAnimation ? 720 : 410,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [secondColor, primaryColor, const Color(0xFF060936)],
                ),
                borderRadius: BorderRadius.circular(900),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.35),
                    blurRadius: 35,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
            ),
          ),

          /// HIASAN DI AREA BIRU
          AnimatedPositioned(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            bottom: startAnimation ? 325 : 245,
            right: startAnimation ? 40 : 30,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: startAnimation ? 0.45 : 0.35,
              child: _softCircle(
                size: 58,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            bottom: startAnimation ? 250 : 180,
            left: startAnimation ? 35 : 28,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: startAnimation ? 0.35 : 0.25,
              child: _softCircle(
                size: 34,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),

          /// TOMBOL AYO MULAI
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            bottom: startAnimation ? -(height * 0.25) : 68,
            left: 28,
            right: 28,
            child: IgnorePointer(
              ignoring: startAnimation,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: startAnimation ? 0 : 1,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        onPressed: _startWelcomeAnimation,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Ayo Mulai!",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 24),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Temukan kost nyaman atau kelola kost kamu lebih mudah",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// PILIHAN ROLE
          AnimatedPositioned(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutBack,
            bottom: showRoles ? 34 : -260,
            left: 24,
            right: 24,
            child: IgnorePointer(
              ignoring: !showRoles,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: showRoles ? 1 : 0,
                child: Column(
                  children: [
                    Text(
                      "Pilih akses masuk kamu",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _roleButton(
                      title: "Masuk sebagai pemilik",
                      subtitle: "Kelola kost, kamar, dan laporan",
                      icon: Icons.home_work_rounded,
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpPage(role: "owner"),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    _roleButton(
                      title: "Masuk sebagai penghuni",
                      subtitle: "Cari kost dan temukan tempat nyaman",
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF22C55E),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpPage(role: "residents"),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _roleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.95), color.withOpacity(0.55)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.50),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
