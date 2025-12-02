import 'package:flutter/material.dart';
import 'package:koskaki/screens/HomePage.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'signup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  String errorMessage = "";

  // Hash password
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Email
              KKTextField(
                label: "Email",
                controller: email,
                hintText: "Masukkan email",
              ),
              const SizedBox(height: 16),

              // Password
              KKTextField(
                label: "Password",
                controller: pass,
                hintText: "Masukkan password",
                obscure: true,
              ),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Lupa Password?",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Error message
              if (errorMessage.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Tombol login
              KKButton(
                text: "Masuk",
                onPressed: () async {
                  final emailText = email.text.trim();
                  final passText = pass.text.trim();

                  if (emailText.isEmpty || passText.isEmpty) {
                    setState(() {
                      errorMessage =
                      "Email dan password tidak boleh kosong.";
                    });
                    return;
                  }

                  final hashed = hashPassword(passText);

                  try {
                    // Ambil user berdasarkan email
                    final response = await Supabase.instance.client
                        .from('Users')
                        .select()
                        .eq('Email', emailText)
                        .maybeSingle();

                    if (response == null) {
                      setState(() {
                        errorMessage = "Email tidak ditemukan.";
                      });
                      return;
                    }

                    // Cocokkan password hash
                    if (response['Password'] != hashed) {
                      setState(() {
                        errorMessage = "Password salah.";
                      });
                      return;
                    }

                    // Login berhasil
                    setState(() {
                      errorMessage = "";
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Berhasil masuk"),
                      ),
                    );

                    // TODO: arahkan ke halaman utama
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => HomePage()));

                  } catch (e) {
                    setState(() {
                      errorMessage = "Terjadi kesalahan: $e";
                    });
                  }
                },
              ),

              const SizedBox(height: 50),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Belum punya akun? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const SignUpPage(role: "user"),
                        ),
                      );
                    },
                    child: const Text(
                      "Daftar",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 15,
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
