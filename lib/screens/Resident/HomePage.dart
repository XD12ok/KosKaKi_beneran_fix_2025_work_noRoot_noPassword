import 'package:flutter/material.dart';
import 'package:koskaki/data/dummy_kos.dart';
import 'package:koskaki/models/kos_model.dart';
import 'package:koskaki/data/RatingKos.dart';
import 'package:koskaki/screens/Resident/DetailKos_page.dart';
import 'package:koskaki/screens/Resident/Profile.dart';
import 'package:koskaki/screens/Resident/search_page.dart';
import 'package:koskaki/screens/Resident/KosTermurah_page.dart';
import 'package:koskaki/screens/Resident/KosTerbaru_page.dart';
import 'package:koskaki/screens/Resident/KosTerlengkap_page.dart';
import 'package:koskaki/screens/Resident/RiwayatPemesanan_page.dart';
import 'package:koskaki/service/api_service.dart';

const primaryColor = Color(0xFF2D2F8F);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<KosModel> filteredKos = [];

  Map<String, dynamic>? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    /// ✅ tetap load kos
    filteredKos = dummyKos.where((k) => !k.isHidden).toList();

    /// ✅ ambil user API
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();
      final user = await api.getUser();

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      setState(() {
        userData = {
          "username": user['name'] ?? "User",
          "email": user['email'],
        };
        loading = false;
      });
    } catch (e) {
      print("ERROR LOAD USER API: $e");
      setState(() => loading = false);
    }
  }

  /// ✅ pakai versi average (lebih bagus)
  Widget buildRating(String name) {
    final rating = RatingKos.getAverage(name);

    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating.round()
                  ? Icons.star
                  : Icons.star_border,
              size: 14,
              color: Colors.amber,
            );
          }),
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

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hai, ${userData?['username'] ?? 'User'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${userData?['email'] ?? '-'}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.favorite_border),
                  const SizedBox(width: 12),
                  const Icon(Icons.notifications_none),
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
                      Expanded(child: Text("Cari Kos Anda")),
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
                            buildRating("Coer Kos"),
                            const SizedBox(height: 6),
                            const Text(
                              "Sangat nyaman dan worth it!",
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

                      setState(() {});
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
                          Image.asset(kos.image, height: 120, fit: BoxFit.cover),
                          const SizedBox(height: 6),
                          Text(kos.name),
                          buildRating(kos.name),
                          const Spacer(),
                          Text(kos.price),
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