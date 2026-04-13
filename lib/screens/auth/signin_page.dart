import 'package:flutter/material.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/screens/Owner/OwnerPage.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import '../../service/auth_service.dart';
import 'signup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';


class LoginPage extends StatefulWidget {
  final String role;

  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  String errorMessage = "";

  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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

              if (errorMessage.isNotEmpty)
                Center(
                  child: Text(errorMessage,
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),

              const SizedBox(height: 10),

              KKButton(
                text: "Masuk",
                onPressed: () async {
                  final emailText = email.text.trim();
                  final passText = pass.text.trim();

                  if (emailText.isEmpty || passText.isEmpty) {
                    setState(() => errorMessage = "Email dan password wajib.");
                    return;
                  }

                  final hashed = hashPassword(passText);

                  try {
                    final response = await Supabase.instance.client
                        .from("Users")
                        .select()
                        .eq("Email", emailText)
                        .maybeSingle();

                    if (response == null) {
                      setState(() => errorMessage = "Email tidak ditemukan.");
                      return;
                    }

                    final role = response['Role'] as String;
                    final dbPassword = response['Password'] as String;

                    if (role != widget.role) {
                      setState(() => errorMessage =
                      "Akun ini tidak bisa login sebagai ${widget.role}");
                      return;
                    }

                    if (dbPassword != hashed) {
                      setState(() => errorMessage = "Password salah.");
                      return;
                    }

                    // Simpan session
                    await AuthService.saveUserSession(response['id'] as int);

                    // Pindah ke HomePage
                    // Pindah ke HomePage sesuai role
                    if (widget.role == "Penghuni") {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                      );
                    }
                    else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const OwnerHomePage()),
                      );
                    }
                  } catch (e) {
                    setState(() => errorMessage = "Error: $e");
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
                          builder: (_) => SignUpPage(role: widget.role),
                        ),
                      );
                    },
                    child: const Text(
                      "Daftar",
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
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
