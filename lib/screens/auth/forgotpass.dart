import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';

class ForgotPassPage extends StatefulWidget {
  const ForgotPassPage({super.key});

  @override
  State<ForgotPassPage> createState() => _ForgotPassPageState();
}

class _ForgotPassPageState extends State<ForgotPassPage> {
  final email = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> sendForgotPassword() async {
    if (email.text.trim().isEmpty) return;

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${ApiService.baseUrl}/auth/forgot-password"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email.text.trim(),
        }),
      );

      debugPrint("FORGOT STATUS: ${res.statusCode}");
      debugPrint("FORGOT BODY: ${res.body}");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cek Gmail kamu lalu klik link verifikasi/reset password."),
        ),
      );
    } catch (e) {
      debugPrint("FORGOT ERROR: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KKLogo(),
              const SizedBox(height: 24),
              const Text(
                "Reset Password",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Masukkan email kamu. Setelah itu cek Gmail dan klik link verifikasi dari email.",
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              KKTextField(
                label: "Email",
                controller: email,
                hintText: "Masukkan email",
              ),
              const SizedBox(height: 26),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KKButton(
                      text: "Kirim Link ke Gmail",
                      onPressed: sendForgotPassword,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}