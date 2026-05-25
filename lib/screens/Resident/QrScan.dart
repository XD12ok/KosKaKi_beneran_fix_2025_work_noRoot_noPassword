import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final TextEditingController codeController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  String cleanToken(String? token) {
    if (token == null) return "";

    String cleaned = token.trim();

    if (cleaned.toLowerCase().startsWith("bearer ")) {
      cleaned = cleaned.substring(7).trim();
    }

    cleaned = cleaned.replaceAll('"', '').replaceAll("'", "").trim();

    return cleaned;
  }

  Map<String, String> authHeaders(String token) {
    final cleanedToken = cleanToken(token);

    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $cleanedToken",
      "X-Requested-With": "XMLHttpRequest",
    };
  }

  String formatFamilyCode(String value) {
    String clean = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .trim();

    if (clean.startsWith("FAM")) {
      clean = clean.substring(3);
    }

    if (clean.length > 6) {
      clean = clean.substring(0, 6);
    }

    if (clean.isEmpty) {
      return "FAM-";
    }

    return "FAM-$clean";
  }

  bool isValidFamilyCode(String code) {
    return RegExp(r'^FAM-[A-Z0-9]{6}$').hasMatch(code.trim().toUpperCase());
  }

  String parseResponseMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        String message = decoded["message"]?.toString() ?? fallback;

        final errors = decoded["errors"];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          } else {
            message = firstError.toString();
          }
        }

        final lowerMessage = message.toLowerCase();

        if (lowerMessage.contains("no query results for model")) {
          return "Kode family tidak ditemukan, sudah digunakan, atau sudah kadaluarsa.";
        }

        return message;
      }

      return fallback;
    } catch (_) {
      final lowerBody = body.toLowerCase();

      if (lowerBody.contains("no query results for model")) {
        return "Kode family tidak ditemukan, sudah digunakan, atau sudah kadaluarsa.";
      }

      return fallback;
    }
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Colors.red.shade600
            : const Color(0xFF2D2F8F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String getJoinFamilyErrorType({
    required int statusCode,
    required String body,
  }) {
    final text = body.toLowerCase();

    if (text.contains("no query results for model")) {
      return "not_found_or_expired";
    }

    if (statusCode == 409 ||
        text.contains("already used") ||
        text.contains("has been used") ||
        text.contains("used") ||
        text.contains("sudah digunakan") ||
        text.contains("telah digunakan") ||
        text.contains("kode sudah dipakai") ||
        text.contains("kode telah dipakai")) {
      return "used";
    }

    if (statusCode == 410 ||
        text.contains("expired") ||
        text.contains("expire") ||
        text.contains("kadaluarsa") ||
        text.contains("kedaluwarsa") ||
        text.contains("sudah habis") ||
        text.contains("masa berlaku")) {
      return "expired";
    }

    if (statusCode == 404 ||
        text.contains("not found") ||
        text.contains("tidak ditemukan")) {
      return "not_found_or_expired";
    }

    return "";
  }

  Future<void> showFamilyCodeAlert({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF161A33),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Mengerti",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> showJoinFamilyFailedAlert({
    required int statusCode,
    required String body,
  }) async {
    final errorType = getJoinFamilyErrorType(
      statusCode: statusCode,
      body: body,
    );

    final backendMessage = parseResponseMessage(
      body,
      "Gagal masuk family kost.",
    );

    if (errorType == "not_found_or_expired") {
      await showFamilyCodeAlert(
        title: "Kode Tidak Bisa Digunakan",
        message:
            "Kode family tidak ditemukan, sudah digunakan, atau sudah kadaluarsa. Minta kode family baru ke penyewa utama atau owner.",
        icon: Icons.key_off_rounded,
        color: Colors.red,
      );
      return;
    }

    if (errorType == "used") {
      await showFamilyCodeAlert(
        title: "Kode Sudah Digunakan",
        message:
            "Kode family ini sudah digunakan sebelumnya. Minta kode family baru ke penyewa utama atau owner.",
        icon: Icons.lock_clock_rounded,
        color: Colors.red,
      );
      return;
    }

    if (errorType == "expired") {
      await showFamilyCodeAlert(
        title: "Kode Sudah Kadaluarsa",
        message:
            "Kode family ini sudah melewati masa berlaku. Minta kode family baru agar bisa masuk family kost.",
        icon: Icons.timer_off_rounded,
        color: Colors.orange,
      );
      return;
    }

    await showFamilyCodeAlert(
      title: "Gagal Masuk Family",
      message: backendMessage,
      icon: Icons.error_outline_rounded,
      color: Colors.red,
    );
  }

  Future<void> joinFamily() async {
    final code = codeController.text.trim().toUpperCase();

    if (!isValidFamilyCode(code)) {
      showMessage("Format kode family harus seperti FAM-ABC123", isError: true);
      return;
    }

    final token = cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      showMessage("Token tidak ditemukan. Silakan login ulang.", isError: true);
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse("${ApiService.baseUrl}/family/join"),
            headers: authHeaders(token),
            body: jsonEncode({"code": code}),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("JOIN FAMILY STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("JOIN FAMILY BODY:");
      debugPrint(response.body);

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (success) {
        showMessage(
          parseResponseMessage(response.body, "Berhasil masuk family kost."),
        );

        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted) return;

        Navigator.pop(context, true);
        return;
      }

      await showJoinFamilyFailedAlert(
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (e) {
      debugPrint("JOIN FAMILY ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage("Terjadi kesalahan saat masuk family kost.", isError: true);
    }
  }

  void pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? "";

    if (text.trim().isEmpty) {
      showMessage("Clipboard kosong.", isError: true);
      return;
    }

    final formatted = formatFamilyCode(text);

    codeController.text = formatted;
    codeController.selection = TextSelection.collapsed(
      offset: codeController.text.length,
    );
  }

  void clearCode() {
    codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: blurCircle(color: const Color(0xFF5B5FEF), size: 260),
          ),
          Positioned(
            bottom: -110,
            right: -90,
            child: blurCircle(color: const Color(0xFF2D2F8F), size: 280),
          ),
          SafeArea(
            child: Column(
              children: [
                buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(
                      children: [
                        buildHeroCard(),
                        const SizedBox(height: 22),
                        buildInputCard(),
                        const SizedBox(height: 18),
                        buildInfoCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.18),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2D2F8F)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                smallButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Masuk Family",
                        style: TextStyle(
                          color: Color(0xFF161A33),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        "Masukkan kode family kost",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D2F8F), Color(0xFF5B5FEF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2F8F), Color(0xFF5B5FEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D2F8F).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: const Icon(Icons.key_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 18),
          const Text(
            "Gabung ke Family Kost",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Minta kode family dari penyewa utama, lalu masukkan kode tersebut di bawah.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D2F8F).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kode Family",
            style: TextStyle(
              color: Color(0xFF161A33),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Format kode: FAM-ABC123",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.text,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final formatted = formatFamilyCode(newValue.text);

                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            style: const TextStyle(
              color: Color(0xFF0A0E50),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              counterText: "",
              hintText: "FAM-ABC123",
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
              filled: true,
              fillColor: const Color(0xFFEFF2FF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: Color(0xFF2D2F8F),
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) {
              if (!isLoading) {
                joinFamily();
              }
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D2F8F),
                      side: BorderSide(
                        color: const Color(0xFF2D2F8F).withOpacity(0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: isLoading ? null : pasteCode,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text(
                      "Paste",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: isLoading ? null : clearCode,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      "Hapus",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D2F8F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: isLoading ? null : joinFamily,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                isLoading ? "Memproses..." : "Masuk ke Family",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.24)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Kode family hanya bisa dipakai satu kali. Pastikan kode yang dimasukkan benar sebelum menekan tombol masuk.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget blurCircle({required Color color, required double size}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.30),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget smallButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF2FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D2F8F).withOpacity(0.10)),
        ),
        child: Icon(icon, color: const Color(0xFF2D2F8F), size: 20),
      ),
    );
  }
}
