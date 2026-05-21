import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:koskaki/screens/Owner/OwnerPage.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
import 'package:koskaki/service/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _backgroundController;
  late final AnimationController _loadingController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _loadingOpacity;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.42, 0.90, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.42, 0.95, curve: Curves.easeOutCubic),
          ),
        );

    _loadingOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.72, 1, curve: Curves.easeOut),
      ),
    );

    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    _backgroundController.repeat(reverse: true);
    _loadingController.repeat();
    _entryController.forward();

    final nextPageFuture = _checkLoginDestination();

    await Future.delayed(const Duration(milliseconds: 2500));

    final nextPage = await nextPageFuture;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, __, ___) => nextPage,
        transitionsBuilder: (_, animation, __, child) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final slideAnimation =
              Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
      ),
    );
  }

  Future<Widget> _checkLoginDestination() async {
    try {
      final api = ApiService();

      final token = await api.getToken();

      if (token == null) {
        return const WelcomeScreen();
      }

      final user = await api.getUser();

      if (user == null) {
        await api.removeToken();
        return const WelcomeScreen();
      }

      final role = user['role']?.toString();

      if (role == 'residents') {
        return const HomePage();
      }

      return const OwnerHomePage();
    } catch (_) {
      return const WelcomeScreen();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _backgroundController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundController,
          _entryController,
          _loadingController,
        ]),
        builder: (context, child) {
          final bgValue = _backgroundController.value;

          return Stack(
            children: [
              _MinimalBackground(value: bgValue),

              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: _LogoCard(backgroundValue: bgValue),
                          ),
                        ),

                        const SizedBox(height: 34),

                        FadeTransition(
                          opacity: _textOpacity,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) {
                                    return const LinearGradient(
                                      colors: [
                                        Color(0xFF0F172A),
                                        Color(0xFF1D4ED8),
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: const Text(
                                    'Koskaki',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                      height: 1,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'Temukan kost nyaman dengan mudah',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF334155,
                                    ).withOpacity(0.78),
                                    fontSize: 15,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 46),

                        FadeTransition(
                          opacity: _loadingOpacity,
                          child: Column(
                            children: [
                              _ElegantLoadingBar(
                                value: _loadingController.value,
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Menyiapkan aplikasi...',
                                style: TextStyle(
                                  color: const Color(
                                    0xFF475569,
                                  ).withOpacity(0.72),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MinimalBackground extends StatelessWidget {
  final double value;

  const _MinimalBackground({required this.value});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF), Color(0xFFDDEEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        Positioned(
          top: -120 + (value * 24),
          right: -110,
          child: _BlurCircle(
            size: 260,
            color: const Color(0xFF93C5FD).withOpacity(0.30),
          ),
        ),

        Positioned(
          bottom: -130,
          left: -110 + (value * 26),
          child: _BlurCircle(
            size: 300,
            color: const Color(0xFFC4B5FD).withOpacity(0.22),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).size.height * 0.22,
          left: -70,
          child: _BlurCircle(
            size: 170,
            color: const Color(0xFFBAE6FD).withOpacity(0.18),
          ),
        ),
      ],
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  final double backgroundValue;

  const _LogoCard({required this.backgroundValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      height: 185,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(46),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.10),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.95),
            blurRadius: 18,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(46),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(46),
              color: Colors.white.withOpacity(0.88),
              border: Border.all(
                color: Colors.white.withOpacity(0.95),
                width: 1.4,
              ),
            ),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _ElegantLoadingBar extends StatelessWidget {
  final double value;

  const _ElegantLoadingBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1).withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.28 + (value * 0.72),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
