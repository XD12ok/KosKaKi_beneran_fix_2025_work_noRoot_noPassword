import 'package:flutter/material.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/screens/Owner/OwnerPage.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'package:koskaki/service/auth_service.dart';
import 'package:koskaki/service/api_service.dart';

import 'signup_page.dart';
import 'forgotpass.dart';

class LoginPage extends StatefulWidget {
  final String role;

  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  void showCustomAlert({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color buttonColor,
    required List<Color> gradientColors,
    required String buttonText,
    VoidCallback? onConfirm,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Alert",
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 92,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: iconColor, size: 42),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: Color(0xFF6B7280),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);

                      if (onConfirm != null) {
                        onConfirm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curvedAnimation, child: child),
        );
      },
    );
  }

  void showErrorDialog(String message) {
    showCustomAlert(
      title: "Terjadi Kesalahan",
      message: message,
      icon: Icons.error_rounded,
      iconColor: const Color(0xFFE53935),
      buttonColor: const Color(0xFFE53935),
      gradientColors: const [Color(0xFFFFE5E5), Color(0xFFFFF7F7)],
      buttonText: "Mengerti",
    );
  }

  void showUnverifiedEmailDialog() {
    showCustomAlert(
      title: "Akun Belum Diverifikasi",
      message: "Akun belum diverifikasi silahkan cek email",
      icon: Icons.mark_email_unread_rounded,
      iconColor: const Color(0xFFF59E0B),
      buttonColor: const Color(0xFFF59E0B),
      gradientColors: const [Color(0xFFFFF3CD), Color(0xFFFFFBEB)],
      buttonText: "Mengerti",
    );
  }

  bool isUnverifiedMessage(String message) {
    final msg = message.toLowerCase();

    return msg.contains("belum diverifikasi") ||
        msg.contains("belum verifikasi") ||
        msg.contains("akun belum") ||
        msg.contains("email belum") ||
        msg.contains("unverified") ||
        msg.contains("not verified") ||
        msg.contains("verify your email") ||
        msg.contains("email verification");
  }

  bool isUserEmailUnverified(dynamic user) {
    if (user == null || user is! Map) return false;

    if (user.containsKey('email_verified_at') &&
        user['email_verified_at'] == null) {
      return true;
    }

    return false;
  }

  Future<void> handleLogin() async {
    final emailText = email.text.trim();
    final passText = pass.text.trim();

    if (emailText.isEmpty || passText.isEmpty) {
      showErrorDialog("Email dan password wajib diisi.");
      return;
    }

    setState(() => isLoading = true);

    try {
      ApiService api = ApiService();

      final token = await api.login(emailText, passText);

      if (!context.mounted) return;

      if (token == null) {
        showErrorDialog("Email atau password salah.");
        return;
      }

      final user = await api.getUser();

      if (!context.mounted) return;

      if (user == null) {
        showErrorDialog("Gagal mengambil data user.");
        return;
      }

      if (isUserEmailUnverified(user)) {
        showUnverifiedEmailDialog();
        return;
      }

      final roleUser = user['role'];

      if (roleUser != widget.role) {
        showErrorDialog("Akun ini tidak sesuai dengan role yang dipilih.");
        return;
      }

      await AuthService.saveUserSession(user['id']);

      if (!context.mounted) return;

      if (widget.role == "residents") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OwnerHomePage()),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      final errorMessage = e.toString();

      if (isUnverifiedMessage(errorMessage)) {
        showUnverifiedEmailDialog();
      } else {
        showErrorDialog("Terjadi kesalahan jaringan.");
      }
    } finally {
      if (context.mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SignUpPage(role: widget.role)),
    );
  }

  void goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPassPage()),
    );
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

              const SizedBox(height: 20),

              const Text(
                "Masuk",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              KKTextField(
                label: "Email",
                controller: email,
                hintText: "Masukkan email",
              ),

              const SizedBox(height: 16),

              KKTextField(
                label: "Password",
                controller: pass,
                hintText: "Masukkan password",
                obscure: true,
              ),

              const SizedBox(height: 22),

              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KKButton(text: "Masuk", onPressed: handleLogin),

              const SizedBox(height: 34),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Belum punya akun? ",
                    style: TextStyle(fontSize: 14.5, color: Color(0xFF6B7280)),
                  ),
                  GestureDetector(
                    onTap: goToSignUp,
                    child: const Text(
                      "Daftar",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Lupa password? ",
                    style: TextStyle(fontSize: 14.5, color: Color(0xFF6B7280)),
                  ),
                  GestureDetector(
                    onTap: goToForgotPassword,
                    child: const Text(
                      "Lupa Password",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
