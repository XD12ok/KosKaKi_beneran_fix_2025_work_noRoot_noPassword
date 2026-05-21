import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/ListChat.dart';
import 'package:koskaki/screens/Resident/DetailKos_page.dart';
import 'package:koskaki/screens/Resident/Profile.dart';
import 'package:koskaki/screens/Resident/QrScan.dart';
import 'package:koskaki/screens/Resident/SearchResult.dart';
import 'package:koskaki/service/api_service.dart';

const Color primaryColor = Color(0xFF2D2F8F);
const Color secondaryColor = Color(0xFF5B5FEF);
const Color softBlue = Color(0xFFEFF2FF);
const Color darkText = Color(0xFF161A33);

enum KosFilter { rekomendasi, termurah, terbaru, terlengkap }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> kosList = [];

  Map<String, dynamic>? userData;

  bool loadingUser = true;
  bool loadingKos = true;

  KosFilter selectedFilter = KosFilter.rekomendasi;

  @override
  void initState() {
    super.initState();
    loadUser();
    loadKosFromApi();
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();
      final user = await api.getUser();

      if (!mounted) return;

      setState(() {
        userData = {
          "username": user?['name'] ?? "User",
          "email": user?['email'] ?? "-",
        };

        loadingUser = false;
      });
    } catch (e) {
      debugPrint("ERROR LOAD USER API: $e");

      if (!mounted) return;

      setState(() {
        loadingUser = false;
      });
    }
  }

  Future<void> loadKosFromApi() async {
    try {
      if (mounted) {
        setState(() {
          loadingKos = true;
        });
      }

      final api = ApiService();
      final token = await api.getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint("STATUS LOAD KOS: ${response.statusCode}");
      debugPrint("BODY LOAD KOS: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        dynamic rawData;

        if (decoded is Map<String, dynamic>) {
          rawData = decoded['data'];

          if (rawData is Map<String, dynamic> && rawData['data'] != null) {
            rawData = rawData['data'];
          }
        } else {
          rawData = decoded;
        }

        if (rawData is List) {
          final data = rawData
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((item) {
                final status = item['status']?.toString().toLowerCase();

                return status == null ||
                    status == "active" ||
                    status == "aktif";
              })
              .toList();

          if (!mounted) return;

          setState(() {
            kosList = data;
            loadingKos = false;
          });
        } else {
          if (!mounted) return;

          setState(() {
            kosList = [];
            loadingKos = false;
          });
        }
      } else {
        if (!mounted) return;

        setState(() {
          kosList = [];
          loadingKos = false;
        });
      }
    } catch (e) {
      debugPrint("ERROR LOAD KOS API: $e");

      if (!mounted) return;

      setState(() {
        kosList = [];
        loadingKos = false;
      });
    }
  }

  int? toInt(dynamic value) {
    if (value == null) return null;

    final text = value.toString();

    if (text.isEmpty || text == "null") return null;

    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) return null;

    return int.tryParse(cleanText);
  }

  String formatRupiah(int value) {
    final result = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp $result";
  }

  int getMainPriceValue(Map<String, dynamic> kos) {
    final month = toInt(kos['price_perMonth'] ?? kos['price_per_month']);
    final night = toInt(kos['price_perNight'] ?? kos['price_per_night']);
    final week = toInt(kos['price_perWeek'] ?? kos['price_per_week']);
    final year = toInt(kos['price_perYear'] ?? kos['price_per_year']);

    return month ?? night ?? week ?? year ?? 999999999;
  }

  String getKosPrice(Map<String, dynamic> kos) {
    final month = toInt(kos['price_perMonth'] ?? kos['price_per_month']);
    final night = toInt(kos['price_perNight'] ?? kos['price_per_night']);
    final week = toInt(kos['price_perWeek'] ?? kos['price_per_week']);
    final year = toInt(kos['price_perYear'] ?? kos['price_per_year']);

    if (month != null && month > 0) {
      return "${formatRupiah(month)} / Bulan";
    }

    if (night != null && night > 0) {
      return "${formatRupiah(night)} / Malam";
    }

    if (week != null && week > 0) {
      return "${formatRupiah(week)} / Minggu";
    }

    if (year != null && year > 0) {
      return "${formatRupiah(year)} / Tahun";
    }

    return "Harga belum tersedia";
  }

  String getKosTitle(Map<String, dynamic> kos) {
    return kos['title']?.toString() ??
        kos['name']?.toString() ??
        "Nama kos tidak tersedia";
  }

  String getKosAddress(Map<String, dynamic> kos) {
    return kos['address']?.toString() ?? "Alamat belum tersedia";
  }

  String getKosCity(Map<String, dynamic> kos) {
    final city = kos['city'];

    if (city is Map) {
      return city['name']?.toString() ?? "Kota belum tersedia";
    }

    return kos['city_name']?.toString() ?? "Kota belum tersedia";
  }

  double getRatingValue(Map<String, dynamic> kos) {
    return double.tryParse(kos['rating_avg']?.toString() ?? "0") ?? 0;
  }

  int getRatingCount(Map<String, dynamic> kos) {
    return int.tryParse(kos['rating_count']?.toString() ?? "0") ?? 0;
  }

  String? getImageUrlFromValue(dynamic value) {
    if (value == null) return null;

    final baseUrlWithoutApi = ApiService.baseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );

    if (value is String) {
      if (value.isEmpty || value == "null") return null;

      if (value.startsWith("http")) return value;

      if (value.startsWith("/storage")) {
        return "$baseUrlWithoutApi$value";
      }

      if (value.startsWith("storage")) {
        return "$baseUrlWithoutApi/$value";
      }

      return "$baseUrlWithoutApi/storage/$value";
    }

    if (value is Map) {
      final possibleImage =
          value['url'] ??
          value['image'] ??
          value['path'] ??
          value['image_path'] ??
          value['file'];

      return getImageUrlFromValue(possibleImage);
    }

    return null;
  }

  String? getKosImage(Map<String, dynamic> kos) {
    final mainImage = getImageUrlFromValue(kos['main_image']);

    if (mainImage != null) return mainImage;

    final images = kos['images'];

    if (images is List && images.isNotEmpty) {
      return getImageUrlFromValue(images.first);
    }

    return null;
  }

  List<Map<String, dynamic>> get sortedKosList {
    List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
      kosList,
    );

    if (selectedFilter == KosFilter.termurah) {
      result.sort((a, b) {
        return getMainPriceValue(a).compareTo(getMainPriceValue(b));
      });
    }

    if (selectedFilter == KosFilter.terbaru) {
      result.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at']?.toString() ?? "") ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['created_at']?.toString() ?? "") ??
            DateTime(2000);

        return dateB.compareTo(dateA);
      });
    }

    if (selectedFilter == KosFilter.terlengkap) {
      result.sort((a, b) {
        final imagesA = a['images'] is List ? (a['images'] as List).length : 0;
        final imagesB = b['images'] is List ? (b['images'] as List).length : 0;

        return imagesB.compareTo(imagesA);
      });
    }

    return result;
  }

  Future<void> refreshAllData() async {
    await loadUser();
    await loadKosFromApi();
  }

  Future<void> openSearchPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchResultPage()),
    );

    if (!mounted) return;

    loadKosFromApi();
  }

  void showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$feature segera tersedia"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
      ),
    );
  }

  Future<void> openDetailPage(Map<String, dynamic> kos) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKosPage(kos: Map<String, dynamic>.from(kos)),
      ),
    );

    if (!mounted) return;

    loadKosFromApi();
  }

  Future<void> openQrScanPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
  }

  Future<void> showKosPreviewSheet(Map<String, dynamic> kos) async {
    bool isOpeningDetail = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> goToDetail() async {
          if (isOpeningDetail) return;

          isOpeningDetail = true;

          Navigator.of(sheetContext).pop();

          await Future.delayed(const Duration(milliseconds: 180));

          if (!mounted) return;

          await openDetailPage(kos);
        }

        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent >= 0.93) {
              goToDetail();
            }

            return false;
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.52,
            minChildSize: 0.35,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.52, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.10),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: buildPreviewImage(kos),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    getKosTitle(kos),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: darkText,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: softBlue,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        getRatingValue(kos) == 0
                                            ? "Baru"
                                            : getRatingValue(
                                                kos,
                                              ).toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              getKosPrice(kos),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            buildPreviewInfo(
                              icon: Icons.location_on_rounded,
                              title: "Lokasi",
                              value:
                                  "${getKosAddress(kos)}, ${getKosCity(kos)}",
                            ),
                            buildPreviewInfo(
                              icon: Icons.home_work_rounded,
                              title: "Kota",
                              value: getKosCity(kos),
                            ),
                            buildPreviewInfo(
                              icon: Icons.verified_rounded,
                              title: "Status",
                              value:
                                  kos['status']?.toString().toLowerCase() ==
                                      "active"
                                  ? "Tersedia"
                                  : kos['status']?.toString() ?? "Tersedia",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: goToDetail,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryColor, secondaryColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.22),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.swipe_up_rounded, color: Colors.white),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Tarik ke atas untuk membuka detail kos",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          "Atau ketuk area ungu di atas untuk langsung membuka detail.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget buildPreviewImage(Map<String, dynamic> kos) {
    final imageUrl = getKosImage(kos);

    if (imageUrl == null) {
      return Image.asset(
        "assets/cover1.png",
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: 190,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: 190,
          width: double.infinity,
          color: softBlue,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          "assets/cover1.png",
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget buildPreviewInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildKosImage(Map<String, dynamic> kos) {
    final imageUrl = getKosImage(kos);

    if (imageUrl == null) {
      return Image.asset(
        "assets/cover1.png",
        height: 132,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: 132,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: 132,
          width: double.infinity,
          color: softBlue,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          "assets/cover1.png",
          height: 132,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget buildUserLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: primaryColor, size: 32),
    );
  }

  Widget buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget buildHeader() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.28),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -18,
              top: -26,
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 38,
              top: 18,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -34,
              bottom: -54,
              child: Container(
                width: 115,
                height: 115,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      child: buildUserLogo(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: loadingUser
                          ? const Text(
                              "Memuat data...",
                              style: TextStyle(color: Colors.white),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hai, ${userData?['username'] ?? 'User'} 👋",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "${userData?['email'] ?? '-'}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.82),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    buildHeaderActionButton(
                      tooltip: "Chat",
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatListOwnerPage(),
                          ),
                        );
                      },
                    ),
                    buildHeaderActionButton(
                      tooltip: "Scan QR",
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: openQrScanPage,
                    ),
                    buildHeaderActionButton(
                      tooltip: "Notifikasi",
                      icon: Icons.notifications_none_rounded,
                      onTap: () => showComingSoon("Notifikasi"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Temukan kos nyaman\nsesuai kebutuhanmu",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: openSearchPage,
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: primaryColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Cari kos, alamat, atau kota",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.black38,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMenuSection() {
    return Row(
      children: [
        Expanded(
          child: MenuItem(
            icon: Icons.auto_awesome_rounded,
            title: "Rekomendasi",
            active: selectedFilter == KosFilter.rekomendasi,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.rekomendasi;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuItem(
            icon: Icons.payments_rounded,
            title: "Termurah",
            active: selectedFilter == KosFilter.termurah,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.termurah;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuItem(
            icon: Icons.home_work_rounded,
            title: "Terbaru",
            active: selectedFilter == KosFilter.terbaru,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.terbaru;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuItem(
            icon: Icons.grid_view_rounded,
            title: "Lengkap",
            active: selectedFilter == KosFilter.terlengkap,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.terlengkap;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget buildHistoryCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => showComingSoon("Riwayat pemesanan"),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.10),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Riwayat Pemesanan",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: darkText,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Fitur pemesanan belum digunakan. Saat ini hanya menampilkan detail kos.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildKosLoading() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        mainAxisExtent: 280,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget buildKosEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: softBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.home_work_outlined,
              size: 42,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Belum ada kos tersedia",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Kos yang ditambahkan owner akan muncul di sini.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget buildKosGrid() {
    final data = sortedKosList;

    if (data.isEmpty) {
      return buildKosEmpty();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: GridView.builder(
        key: ValueKey("${selectedFilter.name}-${data.length}"),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          mainAxisExtent: 300,
        ),
        itemBuilder: (context, index) {
          final kos = data[index];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 420 + (index * 80)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - value)),
                  child: Transform.scale(
                    scale: 0.96 + (0.04 * value),
                    child: child,
                  ),
                ),
              );
            },
            child: KosCard(
              kos: kos,
              title: getKosTitle(kos),
              address: getKosAddress(kos),
              city: getKosCity(kos),
              price: getKosPrice(kos),
              rating: getRatingValue(kos),
              ratingCount: getRatingCount(kos),
              imageBuilder: buildKosImage,
              onTap: () async {
                await showKosPreviewSheet(Map<String, dynamic>.from(kos));
              },
            ),
          );
        },
      ),
    );
  }

  String getSectionTitle() {
    switch (selectedFilter) {
      case KosFilter.termurah:
        return "Kos Termurah";
      case KosFilter.terbaru:
        return "Kos Terbaru";
      case KosFilter.terlengkap:
        return "Kos Terlengkap";
      case KosFilter.rekomendasi:
        return "Rekomendasi Terbaik";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshAllData,
          color: primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(),
                const SizedBox(height: 22),
                buildMenuSection(),
                const SizedBox(height: 24),
                buildHistoryCard(),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        getSectionTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: darkText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: softBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "${sortedKosList.length} kos",
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (loadingKos)
                  buildKosLoading()
                else if (kosList.isEmpty)
                  buildKosEmpty()
                else
                  buildKosGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.05 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: active
                    ? primaryColor.withOpacity(0.22)
                    : Colors.black.withOpacity(0.05),
                blurRadius: active ? 20 : 14,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : primaryColor, size: 24),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : darkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KosCard extends StatelessWidget {
  final Map<String, dynamic> kos;
  final String title;
  final String address;
  final String city;
  final String price;
  final double rating;
  final int ratingCount;
  final Widget Function(Map<String, dynamic>) imageBuilder;
  final VoidCallback onTap;

  const KosCard({
    super.key,
    required this.kos,
    required this.title,
    required this.address,
    required this.city,
    required this.price,
    required this.rating,
    required this.ratingCount,
    required this.imageBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            splashColor: primaryColor.withOpacity(0.08),
            highlightColor: primaryColor.withOpacity(0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: imageBuilder(kos),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.34),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.48),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating == 0 ? "Baru" : rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.94),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: softBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
