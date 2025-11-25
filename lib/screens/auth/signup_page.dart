import 'package:flutter/material.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'phone_input.dart';

class SignUpPage extends StatelessWidget {
  final String role; // role dari halaman welcome

  const SignUpPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(      // ⬅️ TAMBAHKAN INI BIAR BISA SCROLL
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KKLogo(),
                const SizedBox(height: 20),

                Text(
                  "Buat Akun (${role})",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                KKTextField(label: "Email", controller: email),
                const SizedBox(height: 14),

                KKTextField(label: "Buat Password", controller: pass, obscure: true),
                const SizedBox(height: 14),

                KKTextField(
                  label: "Masukkan password kembali",
                  controller: confirm,
                  obscure: true,
                ),
                const SizedBox(height: 20),

                KKButton(
                  text: "Buat",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhoneInput(
                          role: role,
                          email: email.text.trim(),
                          password: pass.text.trim(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text("Sudah punya akun? "),
                    Text(
                      "Masuk",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
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
