import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerMapsPage extends StatefulWidget {
  final String? initialAddress;
  final double? latitude;
  final double? longitude;

  const OwnerMapsPage({
    super.key,
    this.initialAddress,
    this.latitude,
    this.longitude,
  });

  @override
  State<OwnerMapsPage> createState() => _OwnerMapsPageState();
}

class _OwnerMapsPageState extends State<OwnerMapsPage> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color greenColor = const Color(0xFF20B455);

  late final TextEditingController locationController;

  @override
  void initState() {
    super.initState();

    locationController = TextEditingController(
      text: widget.initialAddress?.trim().isNotEmpty == true
          ? widget.initialAddress!.trim()
          : "Kendeng badminton stadium, Semarang",
    );
  }

  @override
  void dispose() {
    locationController.dispose();
    super.dispose();
  }

  String get mapQuery {
    final typed = locationController.text.trim();

    if (typed.isNotEmpty) {
      return typed;
    }

    if (widget.latitude != null && widget.longitude != null) {
      return "${widget.latitude},${widget.longitude}";
    }

    return "Kendeng badminton stadium, Semarang";
  }

  Future<void> openGoogleMapsSearch() async {
    final uri = Uri.https(
      "www.google.com",
      "/maps/search/",
      {
        "api": "1",
        "query": mapQuery,
      },
    );

    await launchExternalUrl(uri);
  }

  Future<void> openGoogleMapsDirection() async {
    final uri = Uri.https(
      "www.google.com",
      "/maps/dir/",
      {
        "api": "1",
        "destination": mapQuery,
        "travelmode": "driving",
      },
    );

    await launchExternalUrl(uri);
  }

  Future<void> launchExternalUrl(Uri uri) async {
    final success = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Gagal membuka Google Maps"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  void useThisLocation() {
    Navigator.pop(context, mapQuery);
  }

  Widget topSearchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: primaryColor,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller: locationController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: "Cari / tulis lokasi kost",
                filled: true,
                fillColor: const Color(0xFFF4F6FA),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          InkWell(
            onTap: openGoogleMapsSearch,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget floatingBackButton() {
    return Positioned(
      left: 18,
      bottom: 188,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget floatingTargetButton() {
    return Positioned(
      right: 18,
      bottom: 188,
      child: InkWell(
        onTap: openGoogleMapsSearch,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location_rounded,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget bottomLocationCard() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: greenColor,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lokasi Kost",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mapQuery,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: openGoogleMapsDirection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(
                          color: primaryColor.withOpacity(0.28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text(
                        "Rute",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: useThisLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        "Gunakan",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F7),
      body: Stack(
        children: [
          Positioned.fill(
            child: FakeMapBackground(
              primaryColor: primaryColor,
              greenColor: greenColor,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                topSearchCard(),
                const Spacer(),
              ],
            ),
          ),

          floatingBackButton(),

          floatingTargetButton(),

          bottomLocationCard(),
        ],
      ),
    );
  }
}

class FakeMapBackground extends StatelessWidget {
  final Color primaryColor;
  final Color greenColor;

  const FakeMapBackground({
    super.key,
    required this.primaryColor,
    required this.greenColor,
  });

  Widget road({
    required double left,
    required double top,
    required double width,
    required double height,
    required double angle,
    Color color = const Color(0xFFCAD4E0),
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(40),
          ),
        ),
      ),
    );
  }

  Widget building({
    required double left,
    required double top,
    required double width,
    required double height,
    double angle = 0,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F4E9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget mapLabel({
    required String text,
    required double left,
    required double top,
    double angle = 0,
    Color color = const Color(0xFF6D7D8D),
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  Widget greenMarker() {
    return Positioned(
      left: 150,
      top: 205,
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: greenColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: greenColor.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          CustomPaint(
            size: const Size(20, 14),
            painter: MarkerTrianglePainter(
              color: greenColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget currentLocationCircle() {
    return Positioned(
      left: 102,
      top: 282,
      child: SizedBox(
        height: 190,
        width: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 190,
              width: 190,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.13),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              height: 18,
              width: 18,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget smallPlaceIcon({
    required IconData icon,
    required double left,
    required double top,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD9E0E8)),
        ),
        child: Icon(
          icon,
          size: 17,
          color: const Color(0xFF7E8C98),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        color: const Color(0xFFEFF3F7),
        child: Stack(
          children: [
            road(
              left: -55,
              top: 68,
              width: 500,
              height: 46,
              angle: -0.20,
            ),
            road(
              left: -30,
              top: 196,
              width: 470,
              height: 54,
              angle: -0.18,
            ),
            road(
              left: -80,
              top: 360,
              width: 540,
              height: 54,
              angle: -0.18,
            ),
            road(
              left: 238,
              top: -20,
              width: 58,
              height: 560,
              angle: 0.15,
            ),
            road(
              left: -70,
              top: 520,
              width: 560,
              height: 92,
              angle: -0.07,
              color: const Color(0xFF7F9FBE),
            ),

            building(left: 24, top: 28, width: 80, height: 70, angle: -0.1),
            building(left: 120, top: 18, width: 88, height: 62, angle: -0.1),
            building(left: 265, top: 20, width: 65, height: 76, angle: 0.08),
            building(left: 15, top: 130, width: 88, height: 74, angle: -0.15),
            building(left: 115, top: 135, width: 48, height: 86, angle: -0.1),
            building(left: 305, top: 126, width: 82, height: 92, angle: 0.08),
            building(left: 32, top: 275, width: 82, height: 74, angle: -0.18),
            building(left: 250, top: 275, width: 98, height: 86, angle: 0.05),
            building(left: 120, top: 420, width: 108, height: 78, angle: -0.12),
            building(left: 250, top: 430, width: 74, height: 94, angle: 0.1),

            mapLabel(
              text: "Jl. Kendeng II",
              left: 114,
              top: 72,
              angle: -0.20,
            ),
            mapLabel(
              text: "Jl. Kendeng III",
              left: 98,
              top: 214,
              angle: -0.18,
            ),
            mapLabel(
              text: "Jl. Kendeng IV",
              left: 42,
              top: 297,
              angle: -0.18,
            ),
            mapLabel(
              text: "Jl. Kendeng V",
              left: 170,
              top: 392,
              angle: -0.18,
            ),
            mapLabel(
              text: "Al Barokah",
              left: 6,
              top: 158,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            mapLabel(
              text: "KOST PUTRI",
              left: 292,
              top: 162,
              color: const Color(0xFFB64D89),
              fontSize: 12,
            ),
            mapLabel(
              text: "Kendeng\nbadminton stadium",
              left: 170,
              top: 270,
              color: const Color(0xFF25A568),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            mapLabel(
              text: "Perpustakaan\nUNISBANK Kendeng",
              left: 122,
              top: 374,
              color: const Color(0xFF6C7B8A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),

            smallPlaceIcon(
              icon: Icons.restaurant_rounded,
              left: 76,
              top: 152,
            ),
            smallPlaceIcon(
              icon: Icons.menu_book_rounded,
              left: 90,
              top: 374,
            ),

            currentLocationCircle(),

            Positioned(
              left: 135,
              top: 246,
              child: Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: greenColor,
                    width: 4,
                  ),
                ),
              ),
            ),

            greenMarker(),
          ],
        ),
      ),
    );
  }
}

class MarkerTrianglePainter extends CustomPainter {
  final Color color;

  MarkerTrianglePainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MarkerTrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}