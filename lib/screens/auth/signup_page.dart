import 'package:flutter/material.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'phone_input.dart';

class SignUpPage extends StatelessWidget {
  final String role;

  const SignUpPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                  onPressed: () async {
                    final emailText = email.text.trim();
                    final passText = pass.text.trim();
                    final confirmText = confirm.text.trim();

                    if (emailText.isEmpty || passText.isEmpty || confirmText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Semua field harus diisi")),
                      );
                      return;
                    }

                    if (passText != confirmText) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Password tidak sama")),
                      );
                      return;
                    }

                    try {
                      // 1. Signup Firebase Auth
                      final credential = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: emailText,
                        password: passText,
                      );

                      final uid = credential.user!.uid;

                      // 2. Insert ke Supabase
                      await Supabase.instance.client.from('Users').insert({
                        'id': uid,
                        'Email': emailText,
                        'Password': passText,
                        'Role': role,
                        'Created_at': DateTime.now().toIso8601String(),
                      });


                    // 3. Masuk ke PhoneInput (jika masih ingin lanjut)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhoneInput(
                            role: role,
                            email: emailText,
                            password: passText,
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: ${e.toString()}")),
                      );
                    }
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
