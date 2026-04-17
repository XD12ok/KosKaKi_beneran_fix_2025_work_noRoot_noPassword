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

  // 🔥 FUNCTION ALERT ERROR
  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Terjadi Kesalahan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
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

              const Text("Buat Akun",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
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

                      // VALIDASI
                      if (usernameText.isEmpty ||
                          emailText.isEmpty ||
                          passText.isEmpty ||
                          confirmText.isEmpty) {
                        showErrorDialog("Semua harus diisi");
                        return;
                      }

                      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(emailText)) {
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
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text("Berhasil"),
                              content: const Text("Akun berhasil dibuat. Silakan login."),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoginPage(role: widget.role),
                                      ),
                                    );
                                  },
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );
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
                              final msg = result['message'].toString().toLowerCase();

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