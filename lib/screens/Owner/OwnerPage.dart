import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart'; // Import package baru
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/KostPage.dart'; 
import 'package:koskaki/screens/Owner/Laporan.dart';
import 'package:koskaki/screens/Owner/PengaturanOwner.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  Map<String, dynamic>? userData;
  bool loading = true;
  int currentIndex = 0;

  // Warna custom menyesuaikan gambar
  final Color _barColor = const Color(0xFFEAF5EB); // Hijau sangat muda (background bar)
  final Color _activeColor = const Color(0xFF0A0E50); // Hijau tua (lingkaran aktif)

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();
      final response = await api.getUser();

      print("USER API: $response");

      if (response == null) {
        setState(() => loading = false);
        return;
      }

      setState(() {
        userData = {
          "username": response['name'] ?? "Owner"
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
      // Tambahkan warna background Scaffold agar animasi transisi kurva terlihat mulus
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          loading
              ? "Hai, ..."
              : "Hai, ${userData?['username'] ?? 'Owner'}",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),

      body: IndexedStack(
        index: currentIndex,
        children: [
          BerandaPage(
            userData: userData,
            loading: loading,
          ),
          KostPage(), 
          LaporanPage(), 
          PengaturanOwnerPage(
            userData: userData,
            loading: loading,
          ),
        ],
      ),

      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 65.0,
        color: _barColor,
        buttonBackgroundColor: _activeColor,
        backgroundColor: Colors.white, 
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: [
          Icon(
            Icons.home_outlined,
            size: 30,
            color: currentIndex == 0 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.business_outlined,
            size: 30,
            color: currentIndex == 1 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.assessment_outlined,
            size: 30,
            color: currentIndex == 2 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.settings_outlined,
            size: 30,
            color: currentIndex == 3 ? Colors.white : _activeColor,
          ),
        ],
      ),
    );
  }
}

class BerandaPage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final bool loading;

  const BerandaPage({
    super.key,
    required this.userData,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuCard(
            icon: Icons.description_outlined,
            iconColor: Colors.blue,
            title: 'Pengetujuan Sewa',
            subtitle: 'Balas pengajuan sewa pencari kos',
            onTap: () {},
          ),
          const SizedBox(height: 16),

          _buildMenuCard(
            icon: Icons.receipt_long_outlined,
            iconColor: Colors.orange,
            title: 'Tagihan Penyewa',
            subtitle: 'Ingatkan bayar kepada penyewa kos',
            onTap: () {},
          ),
          const SizedBox(height: 16),

          _buildMenuCard(
            icon: Icons.people_outline,
            iconColor: Colors.green,
            title: 'Data Penyewa',
            subtitle: 'Lihat data penyewa kos kamu disini',
            onTap: () {},
          ),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kos Saya',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Tambah lebih banyak lagi kos anda',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A0E50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tambah Kos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}