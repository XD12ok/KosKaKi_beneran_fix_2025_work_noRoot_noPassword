import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController controller = MobileScannerController();
  bool isScanned = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("QR tidak ditemukan di gambar"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// CAMERA VIEW
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (isScanned) return;
              isScanned = true;

              final raw = capture.barcodes.first.rawValue;
              if (raw != null) {
                Navigator.pop(context, raw);
              }
            },
          ),

          /// DARK OVERLAY
          Container(
            color: Colors.black.withOpacity(0.4),
          ),

          /// SCAN FRAME
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
            ),
          ),

          /// TOP GLASS BAR (BACK BUTTON)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: Colors.black.withOpacity(0.2),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Scan QR Code",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// BOTTOM BUTTONS (Torch, Switch Camera, Gallery)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleButton(
                  icon: Icons.image,
                  onTap: scanFromGallery,
                ),
                const SizedBox(width: 30),
                _circleButton(
                  icon: Icons.flash_on,
                  onTap: () => controller.toggleTorch(),
                ),
                const SizedBox(width: 30),
                _circleButton(
                  icon: Icons.cameraswitch_rounded,
                  onTap: () => controller.switchCamera(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aesthetic Circle Button
  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
} 