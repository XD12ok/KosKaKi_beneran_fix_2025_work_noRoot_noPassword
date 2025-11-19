import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  final String role;

  const AuthPage({super.key, required this.role});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Auth (${widget.role})"),
      ),
      body: Center(
        child: Text(
          "Role yang dipilih: ${widget.role}",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

//ini code untuk nyimpen role kaya intent dari welcome screen
