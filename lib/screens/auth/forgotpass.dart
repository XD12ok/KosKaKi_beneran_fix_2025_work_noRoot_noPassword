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

  bool isValidEmail(String value) {
    final text = value.trim();

    return RegExp(
      r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
    ).hasMatch(text);
  }

  Map<String, dynamic>? parseJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String parseResponseMessage(String body, String fallback) {
    final decoded = parseJsonMap(body);

    String message = fallback;
    String error = "";

    if (decoded != null) {
      message = decoded["message"]?.toString() ?? fallback;
      error = decoded["error"]?.toString() ?? "";

      final errors = decoded["errors"];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          message = firstError.first.toString();
        } else {
          message = firstError.toString();
        }
      }
    }

    final lowerBody = body.toLowerCase();
    final lowerMessage = message.toLowerCase();
    final lowerError = error.toLowerCase();

    final allText = "$lowerBody $lowerMessage $lowerError";

    if (allText.contains("route [password.reset] not defined")) {
      return "Fitur reset password belum siap dari server. Link Gmail belum bisa dibuat karena route reset password di backend belum tersedia.";
    }

    if (allText.contains("password.reset")) {
      return "Fitur reset password belum siap dari server. Silakan hubungi admin aplikasi.";
    }

    if (allText.contains("no query results for model") ||
        allText.contains("user not found") ||
        allText.contains("email not found") ||
        allText.contains("not found") ||
        allText.contains("tidak ditemukan")) {
      return "Email tidak ditemukan. Pastikan email sudah terdaftar.";
    }

    if (allText.contains("connection") ||
        allText.contains("timeout") ||
        allText.contains("timed out")) {
      return "Koneksi bermasalah. Pastikan internet kamu aktif lalu coba lagi.";
    }

    return message;
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
                child: Icon(
                  icon,
                  color: color,
                  size: 27,
                ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> showSuccessAlert() async {
    await showAlert(
      title: "Link Terkirim",
      message:
          "Link reset password sudah dikirim ke Gmail kamu. Silakan cek inbox atau folder spam, lalu klik link verifikasi/reset password.",
      icon: Icons.mark_email_read_rounded,
      color: const Color(0xFF2D2F8F),
      buttonText: "Oke",
    );
  }

  Future<void> showFailedAlert(String message) async {
    await showAlert(
      title: "Gagal Mengirim Link",
      message: message,
      icon: Icons.error_outline_rounded,
      color: Colors.red,
    );
  }

  Future<void> showServerResetRouteAlert() async {
    await showAlert(
      title: "Reset Password Belum Siap",
      message:
          "Server belum bisa membuat link reset password ke Gmail karena route password.reset belum tersedia di backend. Aplikasi tidak bisa mengirim link reset password sampai backend diperbaiki.",
      icon: Icons.warning_amber_rounded,
      color: Colors.orange,
      buttonText: "Paham",
    );
  }

  Future<void> sendForgotPassword() async {
    final emailText = email.text.trim();

    if (emailText.isEmpty) {
      await showAlert(
        title: "Email Kosong",
        message:
            "Masukkan email terlebih dahulu sebelum mengirim link reset password.",
        icon: Icons.email_outlined,
        color: Colors.orange,
      );
      return;
    }

    if (!isValidEmail(emailText)) {
      await showAlert(
        title: "Format Email Salah",
        message:
            "Format email belum benar. Contoh format yang benar: nama@email.com",
        icon: Icons.alternate_email_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse("${ApiService.baseUrl}/auth/forgot-password");

      debugPrint("FORGOT URL: $url");

      final res = await http
          .post(
            url,
            headers: const {
              "Accept": "application/json",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "email": emailText,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("FORGOT STATUS: ${res.statusCode}");
      debugPrint("FORGOT BODY: ${res.body}");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final bodyLower = res.body.toLowerCase();

      if (bodyLower.contains("route [password.reset] not defined") ||
          bodyLower.contains("password.reset")) {
        await showServerResetRouteAlert();
        return;
      }

      final success = res.statusCode == 200 || res.statusCode == 201;

      if (success) {
        await showSuccessAlert();
        return;
      }

      final message = parseResponseMessage(
        res.body,
        "Gagal mengirim link reset password. Coba lagi nanti.",
      );

      await showFailedAlert(message);
    } catch (e) {
      debugPrint("FORGOT ERROR: $e");

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
                "Reset Password",
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Masukkan email kamu. Setelah itu cek Gmail dan klik link verifikasi dari email.",
                style: TextStyle(
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              KKTextField(
                label: "Email",
                controller: email,
                hintText: "Masukkan email",
              ),
              const SizedBox(height: 26),
              isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
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