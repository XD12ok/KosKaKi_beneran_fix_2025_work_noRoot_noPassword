import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
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

  final Color _barColor = const Color(0xFFEAF5EB);

  final Color _activeColor = const Color(0xFF0A0E50);

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();

      final response = await api.getUser();

      final propertyResponse =
      await api.getOwnerPropertiesWithMembers();

      setState(() {
        userData = {
          "username": response?['name'] ?? "Owner",
        };

        properties = propertyResponse;

        loading = false;
      });
    } catch (e) {
      print("ERROR LOAD USER API: $e");

      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,

        title: Text(
          loading ? "Hai, ..." : "Hai, ${userData?['username'] ?? 'Owner'}",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListOwnerPage(),
                ),
              );
            },
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
            properties: properties,
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
        height: 65,
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
            color: currentIndex == 0
                ? Colors.white
                : _activeColor,
          ),

          Icon(
            Icons.business_outlined,
            size: 30,
            color: currentIndex == 1
                ? Colors.white
                : _activeColor,
          ),

          Icon(
            Icons.assessment_outlined,
            size: 30,
            color: currentIndex == 2
                ? Colors.white
                : _activeColor,
          ),

          Icon(
            Icons.settings_outlined,
            size: 30,
            color: currentIndex == 3
                ? Colors.white
                : _activeColor,
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

  const BerandaPage({
    super.key,
    required this.userData,
    required this.loading,
    required this.properties,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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

          const SizedBox(height: 30),

          const Text(
            "Kos Saya",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          if (properties.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Belum ada kos yang ditambahkan",
              ),
            ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: properties.length,

            itemBuilder: (context, index) {
              final property = properties[index];

              final members = property['members'] ?? [];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PropertyMembersPage(
                        property: property,
                      ),
                    ),
                  );
                },

                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),

                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0A0E50,
                              ).withOpacity(0.1),

                              borderRadius:
                              BorderRadius.circular(14),
                            ),

                            child: const Icon(
                              Icons.home_work_outlined,
                              color: Color(0xFF0A0E50),
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [
                                Text(
                                  property['name'] ??
                                      'Kos Saya',

                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  "${members.length} penghuni",
                                  style: TextStyle(
                                    color:
                                    Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ],
                      ),

                      if (members.isNotEmpty)
                        const SizedBox(height: 20),

                      if (members.isNotEmpty)
                        Column(
                          children: members.take(3).map<Widget>((
                              member,
                              ) {
                            final user =
                                member['user'] ?? {};

                            return Padding(
                              padding:
                              const EdgeInsets.only(
                                bottom: 12,
                              ),

                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 20,
                                    child: Icon(Icons.person),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                      children: [
                                        Text(
                                          user['name'] ??
                                              '-',

                                          style:
                                          const TextStyle(
                                            fontWeight:
                                            FontWeight
                                                .w600,
                                          ),
                                        ),

                                        Text(
                                          user['email'] ??
                                              '-',

                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors
                                                .grey
                                                .shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
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
            ),
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

              child: Icon(
                icon,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

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

            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class PropertyMembersPage extends StatelessWidget {
  final Map<String, dynamic> property;

  const PropertyMembersPage({
    super.key,
    required this.property,
  });

  @override
  Widget build(BuildContext context) {
    final members = property['members'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          property['name'] ?? 'Penghuni Kos',
        ),
      ),

      body: members.isEmpty
          ? const Center(
        child: Text(
          "Belum ada penghuni",
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: members.length,

        itemBuilder: (context, index) {
          final member = members[index];

          final user = member['user'] ?? {};

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),

              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),

            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        user['name'] ?? '-',

                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        user['email'] ?? '-',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}