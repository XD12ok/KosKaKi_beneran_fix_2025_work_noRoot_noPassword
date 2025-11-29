import 'package:flutter/material.dart';
import 'package:koskaki/screens/HomePage.dart';
import 'package:pinput/pinput.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/theme/app_theme.dart';

class OtpPage extends StatelessWidget {
  final String role;
  final String email;
  final String password;
  final String phone;

  const OtpPage({
    super.key,
    required this.role,
    required this.email,
    required this.password,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final pinController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: AppTheme.primary),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Verifikasi nomor telepon kamu",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Text(
              "Kami telah mengirim kode verifikasi ke:\n$phone",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            Pinput(
              length: 6,
              controller: pinController,
              defaultPinTheme: PinTheme(
                width: 50,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Tidak menerima kode? Kirim ulang",
              style: TextStyle(color: Colors.grey),
            ),

            const Spacer(),

            KKButton(
              text: "Verifikasi",
              onPressed: () {
                _verifyOtp(
                  context,
                  pinController.text.trim(),
                  email,
                  password,
                  role,
                  phone,
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Fungsi terpisah supaya tidak async di onPressed
void _verifyOtp(
    BuildContext context,
    String otp,
    String email,
    String password,
    String role,
    String phone,
    ) {
  print("OTP: $otp");
  print("Email: $email");
  print("Password: $password");
  print("Role: $role");
  print("Phone: $phone");

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HomePage(
        // role: role,
        // email: email,
        // password: password,
        // phone: fullPhone,
      ),
    ),
  );

  // Lanjutkan Firebase OTP verify atau backend logic
}
