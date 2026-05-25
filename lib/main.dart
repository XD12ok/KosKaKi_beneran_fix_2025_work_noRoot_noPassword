import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
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
  final AppLinks appLinks = AppLinks();

  StreamSubscription<Uri>? linkSubscription;
  String? lastHandledLink;

  @override
  void initState() {
    super.initState();
    initDeepLink();
  }

  Future<void> initDeepLink() async {
    try {
      final Uri? initialLink = await appLinks.getInitialLink();

      if (initialLink != null) {
        handleDeepLink(initialLink);
      }

      linkSubscription = appLinks.uriLinkStream.listen(
        (Uri uri) {
          handleDeepLink(uri);
        },
        onError: (error) {
          debugPrint("DEEPLINK STREAM ERROR:");
          debugPrint(error.toString());
        },
      );
    } catch (e) {
      debugPrint("DEEPLINK INIT ERROR:");
      debugPrint(e.toString());
    }
  }

  void handleDeepLink(Uri uri) {
    debugPrint("DEEPLINK MASUK:");
    debugPrint(uri.toString());

    final currentLink = uri.toString();

    if (lastHandledLink == currentLink) {
      return;
    }

    lastHandledLink = currentLink;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    debugPrint("DEEPLINK SCHEME: $scheme");
    debugPrint("DEEPLINK HOST: $host");
    debugPrint("DEEPLINK PATH: $path");
    debugPrint("DEEPLINK QUERY: ${uri.queryParameters}");

    final isResetPasswordLink =
        path.contains("reset-password") ||
        currentLink.toLowerCase().contains("reset-password");

    final isWelcomeLink =
        path.contains("welcome") ||
        currentLink.toLowerCase().contains("welcome");

    if (isResetPasswordLink) {
      openResetPasswordFromLink(uri);
      return;
    }

    if (isWelcomeLink || (scheme == "koskaki" && host == "auth")) {
      openWelcomeScreen();
      return;
    }

    debugPrint("DEEPLINK TIDAK DIKENALI:");
    debugPrint(uri.toString());
  }

  void openResetPasswordFromLink(Uri uri) {
    final email = Uri.decodeComponent(
      uri.queryParameters["email"] ?? "",
    ).trim();

    String token = Uri.decodeComponent(
      uri.queryParameters["token"] ?? "",
    ).trim();

    if (token.isEmpty && uri.pathSegments.isNotEmpty) {
      token = Uri.decodeComponent(uri.pathSegments.last).trim();
    }

    debugPrint("RESET EMAIL:");
    debugPrint(email);

    debugPrint("RESET TOKEN:");
    debugPrint(token);

    if (email.isEmpty || token.isEmpty) {
      debugPrint("DEEPLINK RESET TIDAK VALID: email/token kosong");
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        debugPrint("NAVIGATOR NULL SAAT RESET PASSWORD");
        return;
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ResetPassPage(
            email: email,
            token: token,
          ),
        ),
      );
    });
  }

  void openWelcomeScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        debugPrint("NAVIGATOR NULL SAAT WELCOME");
        return;
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Koskaki",
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "Poppins",
      ),
      home: const SplashScreen(),
    );
  }
}