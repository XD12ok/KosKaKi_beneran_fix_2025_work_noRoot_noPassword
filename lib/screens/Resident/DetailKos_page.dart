import 'dart:async';
import 'package:flutter/material.dart';
import 'package:koskaki/models/kos_model.dart';
import 'package:koskaki/data/RatingKos.dart'; 
import 'package:koskaki/screens/Resident/PesanKos_page.dart';

class DetailKosPage extends StatefulWidget {
  final KosModel kos;

  const DetailKosPage({super.key, required this.kos});

  @override
  State<DetailKosPage> createState() => _DetailKosPageState();
}

class _DetailKosPageState extends State<DetailKosPage> {
  bool isFavorite = false;
  bool showAllRules = false;
  bool showAllDesc = false;

  /// ================= RATING =================
  int userRating = 0;

  double get averageRating =>
      RatingKos.getAverage(widget.kos.name);

  int get totalUser =>
      RatingKos.getTotal(widget.kos.name);

  void rate(int star) {
    setState(() {
      userRating = star;
      RatingKos.addRating(widget.kos.name, star); // 🔥 MASUK GLOBAL
    });
  }

  /// ================= CAROUSEL =================
  late PageController _pageController;
  Timer? _timer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.9);

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (currentIndex < widget.kos.images.length - 1) {
        currentIndex++;
      } else {
        currentIndex = 0;
      }

      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kos = widget.kos;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [

              /// ===== IMAGE =====
              Stack(
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: Image.asset(kos.image, fit: BoxFit.cover),
                  ),

                  Positioned(
                    top: 40,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              /// ===== CONTENT =====
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// ===== TITLE =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(kos.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),

                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(kos.location,
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                /// ================= RATING =================
                                Row(
                                  children: [

                                    /// BELUM RATING → 5 bintang klik
                                    if (userRating == 0)
                                      Row(
                                        children: List.generate(5, (index) {
                                          return GestureDetector(
                                            onTap: () => rate(index + 1),
                                            child: const Icon(
                                              Icons.star_border,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }),
                                      ),

                                    /// SUDAH RATING → cuma 1 bintang
                                    if (userRating > 0)
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),

                                    const SizedBox(width: 6),

                                    /// ANGKA RATING GLOBAL
                                    if (averageRating > 0)
                                      Text(
                                        "${averageRating.toStringAsFixed(1)} ($totalUser)",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        size: 14, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text("${kos.availableRooms} kamar tersedia",
                                        style: const TextStyle(
                                            color: Colors.green)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          /// ===== PRICE =====
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(kos.price,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2F2E8F))),

                              const Text("/Perbulan",
                                  style: TextStyle(color: Colors.grey)),

                              const SizedBox(height: 6),

                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isFavorite = !isFavorite;
                                  });
                                },
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.red
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      /// ===== CAROUSEL =====
                      SizedBox(
                        height: 160,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: kos.images.length,
                          onPageChanged: (index) {
                            setState(() {
                              currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: AssetImage(kos.images[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          kos.images.length,
                          (index) => Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: currentIndex == index ? 10 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: currentIndex == index
                                  ? const Color(0xFF2F2E8F)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// ===== FASILITAS =====
                      const Text("Fasilitas",
                          style: TextStyle(fontWeight: FontWeight.bold)),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _facilityItem(Icons.tv, "TV"),
                          _facilityItem(Icons.chair, "Lemari"),
                          _facilityItem(Icons.bed, "Tempat Tidur"),
                          _facilityItem(Icons.ac_unit, "AC"),
                        ],
                      ),

                      const SizedBox(height: 18),

                      /// ===== KEBIJAKAN =====
                      _sectionHeaderExpandable(
                        title: "Kebijakan Properti",
                        isExpanded: showAllRules,
                        onTap: () {
                          setState(() {
                            showAllRules = !showAllRules;
                          });
                        },
                      ),

                      const SizedBox(height: 6),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (showAllRules
                                ? kos.rules
                                : kos.rules.take(2))
                            .map((r) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Text("• $r",
                                      style: const TextStyle(
                                          color: Colors.grey)),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: 18),

                      /// ===== DESKRIPSI =====
                      _sectionHeaderExpandable(
                        title: "Deskripsi Properti",
                        isExpanded: showAllDesc,
                        onTap: () {
                          setState(() {
                            showAllDesc = !showAllDesc;
                          });
                        },
                      ),

                      const SizedBox(height: 6),

                      Text(
                        kos.description,
                        maxLines: showAllDesc ? null : 2,
                        overflow: showAllDesc
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 18),

                      /// ===== LOKASI =====
                      const Text("Detail Lokasi",
                          style: TextStyle(fontWeight: FontWeight.bold)),

                      const SizedBox(height: 6),

                      Text(kos.address,
                          style: const TextStyle(color: Colors.grey)),

                      const SizedBox(height: 18),

                      /// ===== BUTTON =====
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF2F2E8F),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PesanKosPage(kos: kos),
                              ),
                            );
                          },
                          child: const Text(
                            "Pesan Kos",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _facilityItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  Widget _sectionHeaderExpandable({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            isExpanded ? "Lihat sedikit" : "Lihat semua",
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}