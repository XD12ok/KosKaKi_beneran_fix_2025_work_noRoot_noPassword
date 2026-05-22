import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/KostPage.dart';
import 'package:koskaki/screens/Owner/Laporan.dart';
import 'package:koskaki/screens/Owner/PengaturanOwner.dart';
import 'package:koskaki/screens/Owner/ListChat.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  Map<String, dynamic>? userData;

  bool loading = true;

  int currentIndex = 0;

  List<dynamic> properties = [];

  int totalKos = 0;

  Map<String, dynamic>? latestProperty;

  final Color _barColor = const Color(0xFFEAF5EB);

  final Color _activeColor = const Color(0xFF0A0E50);

  final Color _backgroundColor = const Color(0xFFF6F8FA);

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();

      final response = await api.getUser();

      final token = await api.getToken();

      print("TOKEN:");
      print(token);

      final propertyResponse = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/my-properties"),
            headers: {
              "Authorization": "Bearer $token",
              "Accept": "application/json",
            },
          )
          .timeout(const Duration(seconds: 15));

      print("GET MY PROPERTIES STATUS:");
      print(propertyResponse.statusCode);

      print("GET MY PROPERTIES BODY:");
      print(propertyResponse.body);

      List<dynamic> propertyList = [];

      if (propertyResponse.statusCode == 200) {
        final decoded = jsonDecode(propertyResponse.body);

        if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          propertyList = decoded['data']['data'];
        } else if (decoded is Map && decoded['data'] is List) {
          propertyList = decoded['data'];
        } else if (decoded is List) {
          propertyList = decoded;
        }
      }

      final List<Map<String, dynamic>> sortedProperties = propertyList
          .map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          })
          .toList();

      sortedProperties.sort((a, b) {
        final aCreated = a['created_at']?.toString();
        final bCreated = b['created_at']?.toString();

        if (aCreated != null && bCreated != null) {
          final aDate = DateTime.tryParse(aCreated);
          final bDate = DateTime.tryParse(bCreated);

          if (aDate != null && bDate != null) {
            return bDate.compareTo(aDate);
          }
        }

        final aId = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final bId = int.tryParse(b['id']?.toString() ?? '0') ?? 0;

        return bId.compareTo(aId);
      });

      if (!mounted) return;

      setState(() {
        userData = {
          "id": response?['id'],
          "role": response?['role'],
          "username": response?['name'] ?? "Owner",
        };

        properties = sortedProperties;

        totalKos = sortedProperties.length;

        latestProperty = sortedProperties.isNotEmpty
            ? sortedProperties.first
            : null;
      });
    } catch (e) {
      print("ERROR LOAD USER API:");
      print(e);

      if (!mounted) return;

      setState(() {
        userData = {"username": "Owner"};

        properties = [];

        totalKos = 0;

        latestProperty = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      backgroundColor: _backgroundColor,

      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loading ? "Hai, ..." : "Hai, ${userData?['username'] ?? 'Owner'}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A0E50),
              ),
            ),

            const SizedBox(height: 2),

            Text(
              "Kelola kos kamu hari ini",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: IconButton(
              icon: const Icon(
                Icons.message_outlined,
                color: Color(0xFF0A0E50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatListOwnerPage()),
                );
              },
            ),
          ),
        ],
      ),

      body: IndexedStack(
        index: currentIndex,
        children: [
          BerandaPage(
            userData: userData,
            loading: loading,
            properties: properties,
            totalKos: totalKos,
            latestProperty: latestProperty,
          ),

          const KostPage(),

          const LaporanPage(),

          PengaturanOwnerPage(userData: userData, loading: loading),
        ],
      ),

      // NAVIGATION BAR TIDAK DIGANTI
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 65,

        color: _barColor,
        buttonBackgroundColor: _activeColor,

        backgroundColor: Colors.transparent,

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

  final List<dynamic> properties;

  final int totalKos;

  final Map<String, dynamic>? latestProperty;

  const BerandaPage({
    super.key,
    required this.userData,
    required this.loading,
    required this.properties,
    required this.totalKos,
    required this.latestProperty,
  });

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _buildHeroCard(),

          const SizedBox(height: 22),

          _buildStatCard(
            icon: Icons.home_work_outlined,
            title: "$totalKos",
            subtitle: "Total Kos",
            color: primaryColor,
          ),

          const SizedBox(height: 26),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.description_outlined,
                  iconColor: Colors.blue,
                  title: 'Pengajuan Sewa',
                  subtitle: 'Balas pengajuan penyewa',
                  onTap: () {},
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: Colors.orange,
                  title: 'Tagihan',
                  subtitle: 'Ingatkan pembayaran',
                  onTap: () {},
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildWideActionCard(
            icon: Icons.home_repair_service_outlined,
            iconColor: Colors.green,
            title: 'Kelola Data Kos',
            subtitle: 'Lihat dan atur data kos yang kamu miliki',
            onTap: () {},
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: Text(
                  "Kos Saya",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: softGreen,
                  borderRadius: BorderRadius.circular(30),
                ),

                child: Text(
                  latestProperty == null ? "0 Kos" : "Terbaru",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (latestProperty == null)
            _buildEmptyKosCard()
          else
            _buildPropertyCard(context: context, property: latestProperty!),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E50), Color(0xFF18227A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),

                  child: const Text(
                    "Dashboard Owner",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Pantau Kos Lebih Mudah",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Kelola data kos, tagihan, dan pengajuan dalam satu tempat.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          Container(
            height: 74,
            width: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "Aktif",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),

      child: Container(
        height: 145,
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor, size: 25),
            ),

            const Spacer(),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),

              child: Icon(icon, color: iconColor, size: 26),
            ),

            const SizedBox(width: 14),

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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyKosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        children: [
          Container(
            height: 82,
            width: 82,
            decoration: BoxDecoration(color: softGreen, shape: BoxShape.circle),
            child: Icon(
              Icons.home_work_outlined,
              size: 42,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            "Belum Ada Kos",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            "Kos yang kamu tambahkan akan muncul di bagian ini.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard({
    required BuildContext context,
    required Map<String, dynamic> property,
  }) {
    final propertyName =
        property['title'] ??
        property['name'] ??
        property['nama'] ??
        property['property_name'] ??
        'Kos Saya';

    final address =
        property['address'] ??
        property['alamat'] ??
        property['city']?['name'] ??
        'Alamat belum tersedia';

    final status = property['status']?.toString() ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, const Color(0xFF18227A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),

            child: const Icon(
              Icons.home_work_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  propertyName.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        address.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status == "active"
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),

                  child: Text(
                    status == "active" ? "Aktif" : status,
                    style: TextStyle(
                      color: status == "active"
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.arrow_forward_ios, size: 15, color: primaryColor),
          ),
        ],
      ),
    );
  }
}
