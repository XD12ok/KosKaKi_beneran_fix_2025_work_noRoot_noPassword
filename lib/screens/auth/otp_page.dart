import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:pinput/pinput.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class OtpPage extends StatefulWidget {
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
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final pinController = TextEditingController();
  String verificationId = "";
  bool isSending = true;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  /// -----------------------
  ///   KIRIM OTP KE NOMOR
  /// -----------------------
  void _sendOtp() async {
    print("Mengirim OTP ke: ${widget.phone}");

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      verificationCompleted: (PhoneAuthCredential credential) {
        print("verificationCompleted");
      },
      verificationFailed: (FirebaseAuthException e) {
        print("verificationFailed: ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim OTP: ${e.message}")),
        );
      },
      codeSent: (String verId, int? resendToken) {
        print("OTP terkirim! verificationId = $verId");
        setState(() {
          verificationId = verId;
          isSending = false;
        });
      },
      codeAutoRetrievalTimeout: (String verId) {
        print("Timeout: $verId");
      },
    );
  }

  /// -----------------------
  ///   VERIFIKASI OTP
  /// -----------------------
  void _verifyOtp() async {
    final smsCode = pinController.text.trim();

    if (smsCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kode OTP tidak lengkap")),
      );
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // LOGIN / VERIFIKASI
      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // Simpan ke Supabase
      await Supabase.instance.client.from('Users').insert({
        'id': uid,
        'Email': widget.email,
        'Phone': widget.phone,
        'Role': widget.role,
        'Created_at': DateTime.now().toIso8601String(),
      });

      // SUKSES
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor berhasil diverifikasi!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(),
        ),
      );

    } catch (e) {
      print("OTP error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kode OTP salah")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              "Kami telah mengirim kode verifikasi ke:\n${widget.phone}",
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

            isSending
                ? const Text(
              "Mengirim kode...",
              style: TextStyle(color: Colors.grey),
            )
                : GestureDetector(
              onTap: () {
                setState(() {
                  isSending = true;
                });
                _sendOtp();
              },
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    const TextSpan(text: "Tidak menerima kode? "),
                    TextSpan(
                      text: "Kirim ulang",
                      style: const TextStyle(
                        color: Colors.blue,                 // tombol biru
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            KKButton(
              text: "Verifikasi",
              onPressed: _verifyOtp,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
