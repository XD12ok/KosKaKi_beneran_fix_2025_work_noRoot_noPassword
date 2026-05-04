import 'package:flutter/material.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/widgets/kk_logo.dart';
import 'package:koskaki/widgets/kk_textfield.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';

class LupaPasswordPage extends StatefulWidget {
  const LupaPasswordPage({super.key});

  @override
  State<LupaPasswordPage> createState() => _LupaPasswordPageState();
}

class _LupaPasswordPageState extends State<LupaPasswordPage> {
  final pass = TextEditingController();
  final confirm = TextEditingController();

  bool isLoading = false;
  String? emailUser;

  @override
  void initState() {
    super.initState();
    loadUserEmail();
  }

  Future<void> loadUserEmail() async {
    ApiService api = ApiService();
    final user = await api.getUser();

    if (user != null) {
      setState(() {
        emailUser = user['email']; 
      });
    }
  }

  @override
  void dispose() {
    pass.dispose();
    confirm.dispose();
    super.dispose();
  }

  void showDialogCustom(String title, String message, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              if (success) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
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

      appBar: AppBar(
        title: const Text("Ganti Password"),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KKLogo(),
              const SizedBox(height: 20),

              const Text(
                "Ganti Password",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                emailUser != null
                    ? "Akun: $emailUser"
                    : "Memuat akun...",
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              KKTextField(
                label: "Password Baru",
                controller: pass,
                obscure: true,
                hintText: "Minimal 8 karakter",
              ),

              const SizedBox(height: 14),

              KKTextField(
                label: "Konfirmasi Password",
                controller: confirm,
                obscure: true,
                hintText: "Ulangi password",
              ),

              const SizedBox(height: 20),

              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : KKButton(
                      text: "Simpan Password",
                      onPressed: () async {
                        final passText = pass.text.trim();
                        final confirmText = confirm.text.trim();

                        if (emailUser == null) {
                          showDialogCustom(
                              "Error", "Data user tidak ditemukan");
                          return;
                        }

                        if (passText.isEmpty || confirmText.isEmpty) {
                          showDialogCustom(
                              "Error", "Semua field wajib diisi");
                          return;
                        }

                        if (passText != confirmText) {
                          showDialogCustom(
                              "Error", "Password tidak sama");
                          return;
                        }

                        if (passText.length < 8) {
                          showDialogCustom(
                              "Error", "Password minimal 8 karakter");
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          ApiService api = ApiService();

                          final success = await api.resetPassword(
                            emailUser!,
                            passText,
                            confirmText,
                          );

                          if (!context.mounted) return;

                          if (success) {
                            await api.removeToken();

                            showDialogCustom(
                              "Berhasil",
                              "Password berhasil diubah.\nSilakan login ulang.",
                              success: true,
                            );
                          } else {
                            showDialogCustom(
                                "Gagal", "Reset password gagal");
                          }
                        } catch (e) {
                          showDialogCustom(
                              "Error", "Terjadi kesalahan jaringan");
                        } finally {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}