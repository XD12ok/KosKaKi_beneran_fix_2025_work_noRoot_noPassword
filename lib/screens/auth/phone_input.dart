import 'package:flutter/material.dart';
import 'package:koskaki/screens/auth/otp_page.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/theme/app_theme.dart';
import 'package:country_code_picker/country_code_picker.dart';

class PhoneInput extends StatefulWidget {
  final String role;
  final String email;
  final String password;

  const PhoneInput({
    super.key,
    required this.role,
    required this.email,
    required this.password,
  });

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  final phoneController = TextEditingController();
  String countryCode = "+62";

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Masukkan nomor telepon anda untuk verifikasi",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                CountryCodePicker(
                  initialSelection: "ID",
                  favorite: const ["+62", "ID"],
                  onChanged: (code) {
                    setState(() {
                      countryCode = code.dialCode ?? "+62";
                    });
                  },
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "8xxxxxxx", // tanpa 0
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            KKButton(
              text: "Lanjut",
              onPressed: () {
                final rawPhone = phoneController.text.trim();

                if (rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nomor telepon tidak boleh kosong")),
                  );
                  return;
                }

                if (rawPhone.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nomor telepon tidak valid")),
                  );
                  return;
                }

                _goToOtp(
                  context,
                  widget.role,
                  widget.email,
                  widget.password,
                  countryCode,
                  rawPhone,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _goToOtp(
    BuildContext context,
    String role,
    String email,
    String password,
    String code,
    String rawPhone,
    ) {
  if (rawPhone.startsWith("0")) {
    rawPhone = rawPhone.substring(1);
  }

  final fullPhone = "$code$rawPhone";

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OtpPage(
        role: role,
        email: email,
        password: password,
        phone: fullPhone,
      ),
    ),
  );
}
