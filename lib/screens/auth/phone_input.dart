import 'package:flutter/material.dart';
import 'package:koskaki/screens/auth/otp_page.dart';
import 'package:koskaki/widgets/kk_button.dart';
import 'package:koskaki/theme/app_theme.dart';
import 'package:country_code_picker/country_code_picker.dart';

class PhoneInput extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final phoneController = TextEditingController();
    String countryCode = "+62";

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
                  showDropDownButton: true,
                  onChanged: (code) {
                    countryCode = code.dialCode ?? "+62";
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "8xxxxxxx",
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            KKButton(
              text: "Lanjut",
              onPressed: () {
                _goToOtp(
                  context,
                  role,
                  email,
                  password,
                  countryCode,
                  phoneController.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Function terpisah agar onPressed tidak async
void _goToOtp(
    BuildContext context,
    String role,
    String email,
    String password,
    String code,
    String phone,
    ) {
  final fullPhone = "$code$phone";

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
