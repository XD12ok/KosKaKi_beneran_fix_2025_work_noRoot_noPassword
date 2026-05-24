import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:koskaki/screens/auth/resetpass.dart';
import 'package:koskaki/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledLink;

  @override
  void initState() {
    super.initState();
    _initDeepLink();
  }

  Future<void> _initDeepLink() async {
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();

      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          _handleDeepLink(uri);
        },
        onError: (error) {
          debugPrint("DEEPLINK STREAM ERROR: $error");
        },
      );
    } catch (e) {
      debugPrint("DEEPLINK INIT ERROR: $e");
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("DEEPLINK MASUK: $uri");

    final currentLink = uri.toString();

    if (_lastHandledLink == currentLink) {
      return;
    }

    _lastHandledLink = currentLink;

    final String email = uri.queryParameters["email"] ?? "";

    String token = uri.queryParameters["token"] ?? "";

    if (token.isEmpty && uri.pathSegments.isNotEmpty) {
      token = uri.pathSegments.last;
    }

    if (email.isEmpty || token.isEmpty) {
      debugPrint("DEEPLINK TIDAK VALID: email/token kosong");
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ResetPassPage(email: email, token: token),
        ),
      );
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Koskaki',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
