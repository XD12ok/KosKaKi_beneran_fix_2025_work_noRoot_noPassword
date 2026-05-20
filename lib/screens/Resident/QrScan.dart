import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  final TextEditingController codeController = TextEditingController();

  bool isScanned = false;

  late final AnimationController scanAnimationController;
  late final Animation<double> scanAnimation;

  @override
  void initState() {
    super.initState();

    scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: scanAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    scanAnimationController.dispose();
    codeController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> scanFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final result = await controller.analyzeImage(picked.path);

    if (result != null && result.barcodes.isNotEmpty) {
      final raw = result.barcodes.first.rawValue;

      if (!mounted) return;
      Navigator.pop(context, raw);
    } else {
      if (!mounted) return;

      showErrorSnack("QR tidak ditemukan di gambar");
    }
  }

  void handleDetect(BarcodeCapture capture) {
    if (isScanned) return;

    if (capture.barcodes.isEmpty) return;

    final raw = capture.barcodes.first.rawValue;

    if (raw == null) return;

    isScanned = true;

    Navigator.pop(context, raw);
  }

  String formatManualCode(String value) {
    final clean = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .substring(
          0,
          value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').length > 6
              ? 6
              : value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').length,
        );

    if (clean.length <= 3) {
      return clean;
    }

    return "${clean.substring(0, 3)}-${clean.substring(3)}";
  }

  bool isValidManualCode(String code) {
    return RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{3}$').hasMatch(code);
  }

  void showErrorSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> showInputCodeSheet() async {
    codeController.clear();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D2F8F), Color(0xFF5B5FEF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2D2F8F).withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.keyboard_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        "Masukkan Kode Kos",
                        style: TextStyle(
                          color: Color(0xFF161A33),
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Gunakan format kode seperti XXX-XXX",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: codeController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.text,
                        maxLength: 7,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9-]'),
                          ),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = formatManualCode(newValue.text);

                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }),
                        ],
                        style: const TextStyle(
                          color: Color(0xFF0A0E50),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "XXX-XXX",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
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
                          submitManualCode(sheetContext);
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2D2F8F),
                                  side: BorderSide(
                                    color: const Color(
                                      0xFF2D2F8F,
                                    ).withOpacity(0.25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text(
                                  "Batal",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D2F8F),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () {
                                  submitManualCode(sheetContext);
                                },
                                child: const Text(
                                  "Gunakan Kode",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void submitManualCode(BuildContext sheetContext) {
    final code = codeController.text.trim().toUpperCase();

    if (!isValidManualCode(code)) {
      showErrorSnack("Format kode harus XXX-XXX");
      return;
    }

    Navigator.pop(sheetContext);

    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// CAMERA VIEW
          Positioned.fill(
            child: MobileScanner(
              controller: controller,
              onDetect: handleDetect,
            ),
          ),

          /// DARK GRADIENT OVERLAY
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.72),
                      Colors.black.withOpacity(0.20),
                      Colors.black.withOpacity(0.72),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          /// DECORATIVE BLUR CIRCLES
          Positioned(
            top: 120,
            left: -70,
            child: _blurCircle(color: const Color(0xFF5B5FEF), size: 170),
          ),

          Positioned(
            bottom: 120,
            right: -80,
            child: _blurCircle(color: const Color(0xFF2D2F8F), size: 190),
          ),

          /// TOP BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          _smallGlassButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.pop(context),
                          ),

                          const SizedBox(width: 12),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Scan QR Code",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Scan QR atau input kode kos",
                                  style: TextStyle(
                                    color: Colors.white70,
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
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// SCAN AREA
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 64),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 270,
                        height: 270,
                        child: CustomPaint(painter: _QrFramePainter()),
                      ),

                      AnimatedBuilder(
                        animation: scanAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: 22 + (scanAnimation.value * 214),
                            left: 24,
                            right: 24,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.95),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.75),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      Positioned(
                        bottom: 18,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.30),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.16),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.center_focus_strong_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Posisikan QR di tengah",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.82,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      child: const Text(
                        "Scan QR atau masukkan kode untuk bergabung kedalam kos.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.45,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// BOTTOM TOMBOL
          Positioned(
            bottom: 34,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _actionButton(
                            icon: Icons.image_rounded,
                            label: "Galeri",
                            onTap: scanFromGallery,
                          ),
                          _actionButton(
                            icon: Icons.flash_on_rounded,
                            label: "Flash",
                            onTap: () => controller.toggleTorch(),
                          ),
                          _actionButton(
                            icon: Icons.keyboard_rounded,
                            label: "Kode",
                            onTap: showInputCodeSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurCircle({required Color color, required double size}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.38),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _smallGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.26),
                  Colors.white.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint cornerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFBFC6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );

    canvas.drawRRect(rect, borderPaint);

    const double cornerLength = 48;
    const double gap = 10;

    canvas.drawLine(
      const Offset(gap, gap),
      const Offset(gap + cornerLength, gap),
      cornerPaint,
    );
    canvas.drawLine(
      const Offset(gap, gap),
      const Offset(gap, gap + cornerLength),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(size.width - gap, gap),
      Offset(size.width - gap - cornerLength, gap),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - gap, gap),
      Offset(size.width - gap, gap + cornerLength),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(gap, size.height - gap),
      Offset(gap + cornerLength, size.height - gap),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(gap, size.height - gap),
      Offset(gap, size.height - gap - cornerLength),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(size.width - gap, size.height - gap),
      Offset(size.width - gap - cornerLength, size.height - gap),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - gap, size.height - gap),
      Offset(size.width - gap, size.height - gap - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
