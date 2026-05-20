import 'package:flutter/material.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'signin_page.dart';
import 'package:koskaki/service/api_service.dart';

class SignUpPage extends StatefulWidget {
  final String role;

  const SignUpPage({super.key, required this.role});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final username = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    pass.dispose();
    confirm.dispose();
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

  void showSuccessDialog() {
    showCustomAlert(
      title: "Berhasil",
      message: "Akun berhasil dibuat silahkan cek email untuk verifikasi",
      icon: Icons.mark_email_read_rounded,
      iconColor: const Color(0xFF16A34A),
      buttonColor: const Color(0xFF16A34A),
      gradientColors: const [Color(0xFFE7FBEF), Color(0xFFF7FFF9)],
      buttonText: "Masuk",
      onConfirm: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage(role: widget.role)),
        );
      },
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
                "Buat Akun",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              KKTextField(
                label: "Username",
                controller: username,
                hintText: "Nama pengguna",
              ),

              const SizedBox(height: 14),

              KKTextField(
                label: "Email",
                controller: email,
                hintText: "contoh@gmail.com",
              ),

              const SizedBox(height: 14),

              KKTextField(
                label: "Password",
                controller: pass,
                obscure: true,
                hintText: "Minimal 8 karakter",
              ),

              const SizedBox(height: 14),

              KKTextField(
                label: "Ulangi Password",
                controller: confirm,
                obscure: true,
                hintText: "Masukkan ulang password",
              ),

              const SizedBox(height: 20),

              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KKButton(
                      text: "Buat",
                      onPressed: () async {
                        final usernameText = username.text.trim();
                        final emailText = email.text.trim();
                        final passText = pass.text.trim();
                        final confirmText = confirm.text.trim();

                        if (usernameText.isEmpty ||
                            emailText.isEmpty ||
                            passText.isEmpty ||
                            confirmText.isEmpty) {
                          showErrorDialog("Semua harus diisi");
                          return;
                        }

                        if (!RegExp(
                          r'^[a-zA-Z0-9._%+-]+@gmail\.com$',
                        ).hasMatch(emailText)) {
                          showErrorDialog("Masukkan email Gmail yang valid");
                          return;
                        }

                        if (passText != confirmText) {
                          showErrorDialog("Password tidak sama");
                          return;
                        }

                        if (passText.length < 8) {
                          showErrorDialog("Password minimal 8 karakter");
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          ApiService api = ApiService();

                          final result = await api.register(
                            usernameText,
                            emailText,
                            passText,
                            confirmText,
                            widget.role,
                          );

                          if (!context.mounted) return;

                          if (result != null && result['errors'] == null) {
                            showSuccessDialog();
                          } else {
                            String errorMessage = "Gagal mendaftar";

                            if (result != null) {
                              if (result['errors'] != null) {
                                final errors = result['errors'];

                                if (errors['email'] != null) {
                                  errorMessage = "Email sudah digunakan";
                                } else if (errors['password'] != null) {
                                  errorMessage = "Password tidak valid";
                                } else if (errors['name'] != null) {
                                  errorMessage = "Username tidak valid";
                                } else if (errors['role'] != null) {
                                  errorMessage = "Role tidak valid";
                                }
                              } else if (result['message'] != null) {
                                final msg = result['message']
                                    .toString()
                                    .toLowerCase();

                                if (msg.contains("email")) {
                                  errorMessage = "Email sudah digunakan";
                                } else if (msg.contains("password")) {
                                  errorMessage = "Password tidak valid";
                                } else {
                                  errorMessage = result['message'];
                                }
                              }
                            }

                            showErrorDialog(errorMessage);
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          showErrorDialog("Terjadi kesalahan jaringan");
                        } finally {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                      },
                    ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Sudah punya akun? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginPage(role: widget.role),
                        ),
                      );
                    },
                    child: const Text(
                      "Masuk",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
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
