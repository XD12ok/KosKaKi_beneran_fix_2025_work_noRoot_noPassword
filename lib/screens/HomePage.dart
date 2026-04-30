import 'package:flutter/material.dart';
import '../data/dummy_kos.dart';
import '../models/kos_model.dart';
import '../data/RatingKos.dart';
import 'DetailKos_page.dart';
import 'Profile.dart';
import 'search_page.dart';
import 'KosTermurah_page.dart';
import 'KosTerbaru_page.dart';
import 'KosTerlengkap_page.dart';
import 'RiwayatPemesanan_page.dart';

const primaryColor = Color(0xFF2D2F8F);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<KosModel> filteredKos = [];

  @override
  void initState() {
    super.initState();
    filteredKos = dummyKos.where((k) => !k.isHidden).toList();
  }

  Widget buildRating(String name) {
    final rating = RatingKos.getAverage(name);

    return Row(
      children: [
        Row(
          children: List.generate(
            5,
            (index) => const Icon(Icons.star,
                color: Colors.amber, size: 14),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          rating == 0 ? "-" : rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// ================= HEADER =================
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfilePage(),
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      radius: 25,
                      backgroundImage: AssetImage("assets/profile.jpg"),
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hai, Kucing!",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        SizedBox(height: 2),
                        Text("Senang bertemu denganmu!",
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                  const Icon(Icons.favorite_border),
                  const SizedBox(width: 12),
                  const Icon(Icons.notifications_none),

                  const SizedBox(width: 10),

                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code, color: primaryColor),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// ================= SEARCH =================
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchPage(),
                    ),
                  );
                },
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: primaryColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text("Cari Kos Anda"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// ================= MENU =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KosTermurahPage(),
                        ),
                      );
                    },
                    child: const MenuItem(Icons.attach_money, "Termurah"),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KosTerbaruPage(),
                        ),
                      );
                    },
                    child: const MenuItem(Icons.home, "Terbaru"),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KosTerlengkapPage(),
                        ),
                      );
                    },
                    child: const MenuItem(Icons.grid_view, "Terlengkap"),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              /// ================= RIWAYAT =================
              const Text("Riwayat Pemesanan",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 12),

              /// 🔥 SEKARANG BISA DIKLIK
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiwayatPemesananPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          "assets/cover1.png",
                          width: 95,
                          height: 95,
                          fit: BoxFit.cover,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Coer Kos",
                                style: TextStyle(fontWeight: FontWeight.bold)),

                            const SizedBox(height: 6),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "14 Feb 2024 - 14 Okt 2024",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),

                            const SizedBox(height: 6),

                            buildRating("Coer Kos"),

                            const SizedBox(height: 6),

                            const Text(
                              "Sangat nyaman dan worth it, suka banget!",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              /// ================= REKOMENDASI =================
              const Text("Rekomendasi Terbaik",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredKos.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 260,
                ),
                itemBuilder: (context, index) {
                  final kos = filteredKos[index];

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailKosPage(kos: kos),
                        ),
                      );

                      setState(() {}); // refresh rating
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              kos.image,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(kos.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),

                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.grey),
                              Expanded(
                                child: Text(kos.location,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          buildRating(kos.name),

                          const Spacer(),

                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              kos.price,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const MenuItem(this.icon, this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }
}