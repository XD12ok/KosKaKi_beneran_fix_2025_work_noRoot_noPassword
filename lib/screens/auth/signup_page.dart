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

  String hashPassword(String pass) {
    return sha256.convert(utf8.encode(pass)).toString();
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
                      const SnackBar(
                          content: Text("Password tidak sama")),
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
                    final hashed = hashPassword(passText);

                    await Supabase.instance.client.from('Users').insert({
                      "UserName": usernameText,
                      "Email": emailText,
                      "Password": hashed,
                      "Role": role,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text("Akun berhasil dibuat. Silakan login.")),
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LoginPage(role: role)),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Gagal: $e")));
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
                            builder: (_) => LoginPage(role: role)),
                      );
                    },
                    child: const Text(
                      "Masuk",
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.w600),
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
