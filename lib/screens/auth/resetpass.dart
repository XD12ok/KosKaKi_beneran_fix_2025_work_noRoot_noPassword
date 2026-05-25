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

  const ResetPassPage({super.key, required this.email, required this.token});

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

  String parseResponseMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        String message = decoded["message"]?.toString() ?? fallback;

        final errors = decoded["errors"];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          } else {
            message = firstError.toString();
          }
        }

        final lowerMessage = message.toLowerCase();

        if (lowerMessage.contains("token") &&
            (lowerMessage.contains("invalid") ||
                lowerMessage.contains("expired") ||
                lowerMessage.contains("kadaluarsa") ||
                lowerMessage.contains("kedaluwarsa"))) {
          return "Link reset password sudah tidak valid atau sudah kadaluarsa. Silakan minta link reset password baru.";
        }

        if (lowerMessage.contains("no query results for model")) {
          return "Data reset password tidak ditemukan. Silakan minta link reset password baru.";
        }

        return message;
      }

      return fallback;
    } catch (_) {
      final lowerBody = body.toLowerCase();

      if (lowerBody.contains("token") &&
          (lowerBody.contains("invalid") ||
              lowerBody.contains("expired") ||
              lowerBody.contains("kadaluarsa") ||
              lowerBody.contains("kedaluwarsa"))) {
        return "Link reset password sudah tidak valid atau sudah kadaluarsa. Silakan minta link reset password baru.";
      }

      if (lowerBody.contains("no query results for model")) {
        return "Data reset password tidak ditemukan. Silakan minta link reset password baru.";
      }

      return fallback;
    }
  }

  Future<void> showAlert({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String buttonText = "Mengerti",
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF161A33),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> showSuccessAlert() async {
    await showAlert(
      title: "Password Berhasil Diubah",
      message:
          "Password kamu berhasil diganti. Silakan login kembali menggunakan password baru.",
      icon: Icons.check_circle_rounded,
      color: const Color(0xFF2D2F8F),
      buttonText: "Oke",
    );
  }

  Future<void> showFailedAlert(String message) async {
    await showAlert(
      title: "Gagal Mengubah Password",
      message: message,
      icon: Icons.error_outline_rounded,
      color: Colors.red,
    );
  }

  Future<void> resetPassword() async {
    final passwordText = password.text.trim();
    final confirmPasswordText = confirmPassword.text.trim();

    if (passwordText.isEmpty || confirmPasswordText.isEmpty) {
      await showAlert(
        title: "Password Kosong",
        message:
            "Password baru dan konfirmasi password wajib diisi terlebih dahulu.",
        icon: Icons.lock_outline_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (passwordText.length < 8) {
      await showAlert(
        title: "Password Terlalu Pendek",
        message: "Password baru minimal harus 8 karakter.",
        icon: Icons.password_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (passwordText != confirmPasswordText) {
      await showAlert(
        title: "Konfirmasi Tidak Sama",
        message:
            "Password baru dan konfirmasi password tidak sama. Silakan periksa lagi.",
        icon: Icons.sync_problem_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (widget.email.trim().isEmpty || widget.token.trim().isEmpty) {
      await showFailedAlert(
        "Email atau token reset password tidak ditemukan. Silakan buka ulang link dari Gmail atau minta link baru.",
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final res = await http
          .post(
            Uri.parse("${ApiService.baseUrl}/auth/reset-password"),
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "email": widget.email,
              "token": widget.token,
              "password": passwordText,
              "password_confirmation": confirmPasswordText,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("RESET STATUS: ${res.statusCode}");
      debugPrint("RESET BODY: ${res.body}");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        await showSuccessAlert();

        if (!mounted) return;

        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }

      final message = parseResponseMessage(
        res.body,
        "Gagal mengubah password. Silakan coba lagi.",
      );

      await showFailedAlert(message);
    } catch (e) {
      debugPrint("RESET ERROR: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      await showFailedAlert(
        "Terjadi kesalahan koneksi. Pastikan internet kamu aktif lalu coba lagi.",
      );
    }
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
                  : KKButton(text: "Ganti Password", onPressed: resetPassword),
            ],
          ),
        ),
      ),
    );
  }
}
