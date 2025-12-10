import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../service/auth_service.dart';

final supabase = Supabase.instance.client;

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  Map<String, dynamic>? userData;
  bool loading = true;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final userId = await AuthService.getUserSession();
      if (userId == null) {
        setState(() => loading = false);
        return;
      }

      final userRow = await supabase
          .from('Users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      setState(() {
        userData = {"username": userRow?['UserName'] ?? "Owner"};
        loading = false;
      });
    } catch (e) {
      print("ERROR LOAD USER: $e");
      setState(() => loading = false);
    }
  }

  List<Widget> get pages => [
    BerandaPage(userData: userData, loading: loading),
    KosPage(userData: userData, loading: loading),
    LaporanPage(userData: userData, loading: loading),
    PengaturanPage(userData: userData, loading: loading),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0A0E50), // Warna item terpilih
        unselectedItemColor: Colors.grey, // Warna item tidak terpilih
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Kos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            label: 'Laporan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

// ============================
// Halaman Beranda
// ============================
class BerandaPage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final bool loading;

  const BerandaPage({super.key, required this.userData, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tambah lebih banyak lagi kos anda',
                    style:
                    TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A0E50),
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tambah Kos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: loading
          ? const Text("Hai, ...",
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black))
          : Text(
        "Hai, ${userData!['username']}",
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black),
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
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
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
                        fontWeight: FontWeight.w600,
                        color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================
// Halaman Kos
// ============================
class KosPage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final bool loading;
  const KosPage({super.key, this.userData, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: loading
            ? const Text("Hai, ...",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black))
            : Text(
          "Hai, ${userData?['username'] ?? 'Owner'}",
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black),
        ),
      ),
      body: const Center(
        child: Text("Halaman Kos", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

// ============================
// Halaman Laporan
// ============================
class LaporanPage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final bool loading;
  const LaporanPage({super.key, this.userData, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: loading
            ? const Text("Hai, ...",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black))
            : Text(
          "Hai, ${userData?['username'] ?? 'Owner'}",
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black),
        ),
      ),
      body: const Center(
        child: Text("Halaman Laporan", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

// ============================
// Halaman Pengaturan dengan Logout
// ============================
class PengaturanPage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final bool loading;
  const PengaturanPage({super.key, this.userData, this.loading = false});

  Future<void> _logout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } catch (e) {
      print("ERROR LOGOUT: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal logout. Coba lagi.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: loading
            ? const Text("Hai, ...",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black))
            : Text(
          "Hai, ${userData?['username'] ?? 'Owner'}",
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black),
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _logout(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Logout',
            style: TextStyle(
                fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ============================
// Dummy WelcomeScreen
// ============================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Selamat Datang di Aplikasi!", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
