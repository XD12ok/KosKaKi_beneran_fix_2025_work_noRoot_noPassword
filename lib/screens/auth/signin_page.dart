import 'package:flutter/material.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/screens/Owner/OwnerPage.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import '../../service/auth_service.dart';
import 'signup_page.dart';
import 'package:koskaki/service/api_service.dart';

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

  // ✅ ALERT ERROR FUNCTION
  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Terjadi Kesalahan"),
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

              const SizedBox(height: 10),

              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KKButton(
                      text: "Masuk",
                      onPressed: () async {
                        final emailText = email.text.trim();
                        final passText = pass.text.trim();

                        if (emailText.isEmpty || passText.isEmpty) {
                          showErrorDialog("Email dan password wajib diisi.");
                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          ApiService api = ApiService();

                          // ✅ LOGIN
                          final token =
                              await api.login(emailText, passText);

                          if (token == null) {
                            setState(() => isLoading = false);
                            showErrorDialog("Email atau password salah.");
                            return;
                          }

                          // ✅ AMBIL USER
                          final user = await api.getUser();

                          if (user == null) {
                            setState(() => isLoading = false);
                            showErrorDialog("Gagal mengambil data user.");
                            return;
                          }

                          final roleUser = user['role'];

                          if (roleUser != widget.role) {
                            setState(() => isLoading = false);
                            showErrorDialog(
                                "Akun ini tidak sesuai dengan role yang dipilih.");
                            return;
                          }

                          // OPTIONAL
                          await AuthService.saveUserSession(user['id']);

                          // ✅ REDIRECT
                          if (widget.role == "residents") {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HomePage()),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const OwnerHomePage()),
                            );
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          showErrorDialog("Terjadi kesalahan jaringan.");
                        }
                      },
                    ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Belum punya akun? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SignUpPage(role: widget.role),
                        ),
                      );
                    },
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
            ],
          ),
        ),
      ),
    );
  }
}