import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';

class ResetPassPage extends StatefulWidget {
  final String email;
  final String token;

  const ResetPassPage({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPassPage> createState() => _ResetPassPageState();
}

class _ResetPassPageState extends State<ResetPassPage> {
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    if (password.text.trim().isEmpty || confirmPassword.text.trim().isEmpty) {
      return;
    }

    if (password.text.trim() != confirmPassword.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konfirmasi password tidak sama.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${ApiService.baseUrl}/auth/reset-password"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": widget.email,
          "token": widget.token,
          "password": password.text.trim(),
          "password_confirmation": confirmPassword.text.trim(),
        }),
      );

      debugPrint("RESET STATUS: ${res.statusCode}");
      debugPrint("RESET BODY: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password berhasil diubah.")),
        );

        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mengubah password.")),
        );
      }
    } catch (e) {
      debugPrint("RESET ERROR: $e");
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
                "Ganti Password",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Masukkan password baru kamu.",
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              KKTextField(
                label: "Password Baru",
                controller: password,
                hintText: "Masukkan password baru",
                obscure: true,
              ),
              const SizedBox(height: 16),
              KKTextField(
                label: "Konfirmasi Password",
                controller: confirmPassword,
                hintText: "Ulangi password baru",
                obscure: true,
              ),
              const SizedBox(height: 26),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KKButton(
                      text: "Ganti Password",
                      onPressed: resetPassword,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}