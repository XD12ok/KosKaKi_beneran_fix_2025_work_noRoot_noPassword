import 'package:flutter/material.dart';
import 'package:koskaki/service/api_service.dart';
import 'QrScan.dart';
import 'Profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();

      final user = await api.getUser();

      print("USER API: $user");

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      setState(() {
        userData = {
          "username": user['name'] ?? "User",
          "email": user['email'],
          "avatar": null, // kalau API belum ada avatar
        };
        loading = false;
      });
    } catch (e) {
      print("ERROR LOAD USER API: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildProfileHeader(context),
                    const SizedBox(height: 20),
                    buildSearchBar(),
                    const SizedBox(height: 20),
                    buildMenuCategory(),
                    const SizedBox(height: 25),
                    const Text(
                      "Riwayat Pemesanan",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _riwayatCard(),
                    const SizedBox(height: 25),
                    const Text(
                      "Rekomendasi Terbaik",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _rekomendasiCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget buildProfileHeader(BuildContext context) {
    if (userData == null) {
      return Row(
        children: const [
          CircleAvatar(radius: 28, child: Icon(Icons.person)),
          SizedBox(width: 12),
          Text("Memuat...", style: TextStyle(fontSize: 18)),
        ],
      );
    }

    final avatar = userData!['avatar'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
          child: CircleAvatar(
            radius: 28,
            backgroundImage: avatar != null
                ? NetworkImage(avatar)
                : const AssetImage("assets/profile.jpg") as ImageProvider,
          ),
        ),

        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hai, ${userData?['username'] ?? 'User'}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${userData?['email'] ?? '-'}",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),

        const Spacer(),

        Row(
          children: [
            const Icon(Icons.favorite_border, size: 26),
            const SizedBox(width: 14),
            const Icon(Icons.notifications_none, size: 26),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrScanPage()),
                );
              },
              child: const Icon(Icons.qr_code_scanner, size: 28),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: const Color(0xFFF1F1F1),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Cari kost anda",
          border: InputBorder.none,
          icon: Icon(Icons.search),
        ),
      ),
    );
  }

  // MENU
  Widget buildMenuCategory() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _menuItem(Icons.attach_money, "Termurah"),
        _menuItem(Icons.inventory_2_outlined, "Terlengkap"),
        _menuItem(Icons.home_work_outlined, "Terbaru"),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF020477),
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _riwayatCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              "assets/kost1.jpg",
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text("Contoh riwayat..."),
          )
        ],
      ),
    );
  }

  Widget _rekomendasiCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Text("Contoh rekomendasi..."),
    );
  }
}