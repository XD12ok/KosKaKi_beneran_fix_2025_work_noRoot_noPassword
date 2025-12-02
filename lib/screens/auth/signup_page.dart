import 'package:flutter/material.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'signin_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SignUpPage extends StatelessWidget {
  final String role;

  const SignUpPage({super.key, required this.role});

  // Fungsi hash password (SHA-256)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    final username = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KKLogo(),
                const SizedBox(height: 20),

                const Text(
                  "Buat",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Username
                KKTextField(
                  label: "Username",
                  controller: username,
                  hintText: "Nama pengguna",
                ),
                const SizedBox(height: 14),

                // Email
                KKTextField(
                  label: "Email",
                  controller: email,
                  hintText: "contoh@gmail.com",
                ),
                const SizedBox(height: 14),

                // Password
                KKTextField(
                  label: "Buat Password",
                  controller: pass,
                  obscure: true,
                  hintText: "Harus 8 karakter",
                ),
                const SizedBox(height: 14),

                // Confirm Password
                KKTextField(
                  label: "Masukkan Password kembali",
                  controller: confirm,
                  obscure: true,
                  hintText: "Masukkan password kembali",
                ),

                const SizedBox(height: 20),

                // Tombol Buat
                KKButton(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Semua field harus diisi")),
                      );
                      return;
                    }

                    if (passText != confirmText) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Password tidak sama")),
                      );
                      return;
                    }

                    if (passText.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Password minimal 8 karakter")),
                      );
                      return;
                    }

                    try {
                      // Hash password
                      final hashedPassword = hashPassword(passText);

                      // Insert ke Supabase
                      await Supabase.instance.client.from('Users').insert({
                        'UserName': usernameText,
                        'Email': emailText,
                        'Password': hashedPassword,
                        'Role': role,
                        'Created_at': DateTime.now().toIso8601String(),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Akun berhasil dibuat")),
                      );

                      // Redirect ke LoginPage
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Gagal mendaftar: $e")),
                      );
                    }
                  },
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Sudah punya akun? "),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        child: Text(
                          "Masuk",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
