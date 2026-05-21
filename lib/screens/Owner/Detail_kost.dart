import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/Edit_kost.dart';

class DetailKostPage extends StatefulWidget {
  final Map<String, dynamic> kost;

  const DetailKostPage({super.key, required this.kost});

  @override
  State<DetailKostPage> createState() => _DetailKostPageState();
}

class _DetailKostPageState extends State<DetailKostPage> {
  bool isLoading = true;

  Map<String, dynamic>? detail;

  List<dynamic> images = [];

  int currentImageIndex = 0;

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  Future<void> getDetail() async {
    try {
      final token = await ApiService().getToken();

      final id = widget.kost['id'];

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties/$id"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print("DETAIL STATUS:");
      print(response.statusCode);

      print("DETAIL BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final data = decoded['data'] ?? decoded;

        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(data);

          images = data['images'] is List
              ? List<dynamic>.from(data['images']).take(15).toList()
              : [];

          currentImageIndex = 0;

          isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          detail = null;
          images = [];
          currentImageIndex = 0;
          isLoading = false;
        });
      }
    } catch (e) {
      print("GET DETAIL ERROR:");
      print(e);

      if (!mounted) return;

      setState(() {
        detail = null;
        images = [];
        currentImageIndex = 0;
        isLoading = false;
      });
    }
  }

  String formatRupiah(dynamic value) {
    if (value == null) return "";

    final number = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

    if (number.isEmpty) return "";

    final buffer = StringBuffer();

    int count = 0;

    for (int i = number.length - 1; i >= 0; i--) {
      buffer.write(number[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  String getPrice() {
    final d = detail ?? {};

    final night = d['price_perNight'] ?? d['price_per_night'];
    final week = d['price_perWeek'] ?? d['price_per_week'];
    final month = d['price_perMonth'] ?? d['price_per_month'];
    final year = d['price_perYear'] ?? d['price_per_year'];

    if (month != null && month.toString().isNotEmpty) {
      return "Rp ${formatRupiah(month)} / bulan";
    }

    if (year != null && year.toString().isNotEmpty) {
      return "Rp ${formatRupiah(year)} / tahun";
    }

    if (week != null && week.toString().isNotEmpty) {
      return "Rp ${formatRupiah(week)} / minggu";
    }

    if (night != null && night.toString().isNotEmpty) {
      return "Rp ${formatRupiah(night)} / malam";
    }

    return "Harga belum ditambahkan";
  }

  Future<void> deleteKost() async {
    try {
      final token = await ApiService().getToken();

      final id = widget.kost['id'];

      final res = await http.delete(
        Uri.parse("${ApiService.baseUrl}/properties/$id"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        showMessage(res.body);
      }
    } catch (e) {
      print("DELETE ERROR:");
      print(e);

      showMessage("Gagal menghapus kost");
    }
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void goEdit() {
    if (detail == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditKostPage(kost: detail!)),
    ).then((value) {
      if (value == true) {
        getDetail();
      }
    });
  }

  String fixUrl(dynamic img) {
    String url = "";

    if (img is String) {
      url = img;
    } else if (img is Map) {
      final fullImageUrl = img['full_image_url']?.toString() ?? "";
      final normalUrl = img['url']?.toString() ?? "";

      if (fullImageUrl.isNotEmpty &&
          fullImageUrl.startsWith("http") &&
          !fullImageUrl.endsWith("/storage")) {
        url = fullImageUrl;
      } else {
        url = normalUrl;
      }
    }

    if (url.isNotEmpty && !url.startsWith("http")) {
      url = "https://koskaki-api.servermbud.online/storage/$url";
    }

    return url;
  }

  List<String> parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) {
            if (e is Map) {
              return e['feature']?.toString() ??
                  e['name']?.toString() ??
                  e['title']?.toString() ??
                  "";
            }

            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (value is String) {
      if (value.trim().isEmpty) return [];

      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return decoded
              .map((e) {
                if (e is Map) {
                  return e['feature']?.toString() ??
                      e['name']?.toString() ??
                      e['title']?.toString() ??
                      "";
                }

                return e.toString();
              })
              .where((e) => e.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}

      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> parsePolicyList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map<Map<String, dynamic>>((e) {
            if (e is Map) {
              final map = Map<String, dynamic>.from(e);

              final title = map['title']?.toString() ?? "";
              final description = map['description']?.toString() ?? "";
              final desc = map['desc']?.toString() ?? "";
              final policy = map['policy']?.toString() ?? "";

              if (title.isEmpty && policy.isNotEmpty) {
                map['title'] = "Aturan";
              }

              if (description.isEmpty && desc.isEmpty && policy.isNotEmpty) {
                map['description'] = policy;
              }

              return map;
            }

            return {"title": "Aturan", "description": e.toString()};
          })
          .where((e) {
            final title = e['title']?.toString() ?? "";
            final description = e['description']?.toString() ?? "";
            final desc = e['desc']?.toString() ?? "";
            final policy = e['policy']?.toString() ?? "";

            return title.isNotEmpty ||
                description.isNotEmpty ||
                desc.isNotEmpty ||
                policy.isNotEmpty;
          })
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return parsePolicyList(decoded);
        }
      } catch (_) {}

      return [
        {"title": "Aturan", "description": value},
      ];
    }

    return [];
  }

  String normalizeText(String value) {
    if (value.trim().isEmpty) return "-";

    return value
        .replaceAll("_", " ")
        .split(" ")
        .where((e) => e.isNotEmpty)
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(" ");
  }

  IconData getFacilityIcon(String value) {
    final text = value.toLowerCase();

    if (text.contains("24") || text.contains("24 jam")) {
      return Icons.watch_later_rounded;
    }

    if (text.contains("wifi")) {
      return Icons.wifi_rounded;
    }

    if (text.contains("cctv")) {
      return Icons.videocam_rounded;
    }

    if (text.contains("parkir motor")) {
      return Icons.two_wheeler_rounded;
    }

    if (text.contains("parkir mobil")) {
      return Icons.directions_car_rounded;
    }

    if (text.contains("parkir")) {
      return Icons.local_parking_rounded;
    }

    if (text.contains("dapur")) {
      return Icons.kitchen_rounded;
    }

    if (text.contains("laundry")) {
      return Icons.local_laundry_service_rounded;
    }

    if (text.contains("ruang tamu")) {
      return Icons.weekend_rounded;
    }

    if (text.contains("keamanan")) {
      return Icons.security_rounded;
    }

    if (text.contains("mushola")) {
      return Icons.mosque_rounded;
    }

    if (text.contains("ac")) {
      return Icons.ac_unit_rounded;
    }

    if (text.contains("tv")) {
      return Icons.tv_rounded;
    }

    if (text.contains("kasur")) {
      return Icons.bed_rounded;
    }

    if (text.contains("lemari")) {
      return Icons.inventory_2_rounded;
    }

    if (text.contains("meja")) {
      return Icons.table_restaurant_rounded;
    }

    if (text.contains("kursi")) {
      return Icons.chair_rounded;
    }

    if (text.contains("kulkas")) {
      return Icons.kitchen_rounded;
    }

    if (text.contains("kamar mandi")) {
      return Icons.bathtub_rounded;
    }

    return Icons.check_circle_outline_rounded;
  }

  IconData getPolicyIcon(
    String title,
    String description,
    String sectionTitle,
  ) {
    final text = "$title $description $sectionTitle".toLowerCase();

    if (text.contains("tamu") || text.contains("guest")) {
      return Icons.groups_rounded;
    }

    if (text.contains("lapor") ||
        text.contains("izin") ||
        text.contains("identitas") ||
        text.contains("ktp")) {
      return Icons.assignment_ind_rounded;
    }

    if (text.contains("rokok") || text.contains("merokok")) {
      return Icons.smoke_free_rounded;
    }

    if (text.contains("hewan") ||
        text.contains("peliharaan") ||
        text.contains("binatang")) {
      return Icons.pets_rounded;
    }

    if (text.contains("bersih") ||
        text.contains("kebersihan") ||
        text.contains("sampah")) {
      return Icons.cleaning_services_rounded;
    }

    if (text.contains("jam") ||
        text.contains("malam") ||
        text.contains("pulang") ||
        text.contains("batas")) {
      return Icons.schedule_rounded;
    }

    if (text.contains("bayar") ||
        text.contains("pembayaran") ||
        text.contains("uang") ||
        text.contains("sewa")) {
      return Icons.payments_rounded;
    }

    if (text.contains("parkir")) {
      return Icons.local_parking_rounded;
    }

    if (text.contains("kunci")) {
      return Icons.key_rounded;
    }

    if (text.contains("dapur")) {
      return Icons.kitchen_rounded;
    }

    if (text.contains("kamar mandi") || text.contains("mandi")) {
      return Icons.bathtub_rounded;
    }

    if (text.contains("kamar")) {
      return Icons.meeting_room_rounded;
    }

    if (text.contains("berisik") ||
        text.contains("gaduh") ||
        text.contains("musik") ||
        text.contains("suara")) {
      return Icons.volume_off_rounded;
    }

    if (text.contains("rusak") ||
        text.contains("kerusakan") ||
        text.contains("barang")) {
      return Icons.build_circle_rounded;
    }

    if (text.contains("listrik")) {
      return Icons.electrical_services_rounded;
    }

    if (text.contains("air")) {
      return Icons.water_drop_rounded;
    }

    if (text.contains("kost")) {
      return Icons.rule_rounded;
    }

    return Icons.gavel_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final d = detail ?? {};

    final title = d['title']?.toString() ?? "Detail Kost";
    final description = d['description']?.toString() ?? "";
    final address = d['address']?.toString() ?? "";
    final maxPeople = d['max_people']?.toString() ?? "";
    final status = d['status']?.toString() ?? "active";

    final kostFacilities = parseStringList(
      d['kost_features'] ?? d['kost_facilities'] ?? d['property_features'],
    );

    final roomFacilities = parseStringList(
      d['place_features'] ?? d['room_facilities'] ?? d['features'],
    );

    final kostRules = parsePolicyList(
      d['kost_policies'] ?? d['kost_rules'] ?? d['property_policies'],
    );

    final roomRules = parsePolicyList(
      d['place_policies'] ?? d['room_rules'] ?? d['policies'],
    );

    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Detail Kost",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),

      bottomNavigationBar: detail == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: goEdit,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text(
                            "Edit",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text("Hapus Kost?"),
                                content: const Text(
                                  "Yakin ingin menghapus kost ini? Data yang dihapus tidak bisa dikembalikan.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context, false);
                                    },
                                    child: const Text("Batal"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context, true);
                                    },
                                    child: const Text("Hapus"),
                                  ),
                                ],
                              ),
                            );

                            if (ok == true) {
                              deleteKost();
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text(
                            "Hapus",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : detail == null
          ? _buildErrorState()
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: getDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageHeader(title: title, status: status),

                    const SizedBox(height: 20),

                    _sectionCard(
                      title: "Informasi Kost",
                      icon: Icons.info_outline,
                      children: [
                        _infoTile(
                          icon: Icons.home_work_outlined,
                          title: "Nama Kost",
                          value: title,
                        ),

                        _infoTile(
                          icon: Icons.payments_outlined,
                          title: "Harga",
                          value: getPrice(),
                        ),

                        _infoTile(
                          icon: Icons.people_alt_outlined,
                          title: "Kapasitas",
                          value: maxPeople.isEmpty
                              ? "Belum ditambahkan"
                              : "$maxPeople orang",
                        ),

                        _infoTile(
                          icon: Icons.location_on_outlined,
                          title: "Alamat",
                          value: address.isEmpty
                              ? "Alamat belum ditambahkan"
                              : address,
                        ),

                        _infoTile(
                          icon: Icons.description_outlined,
                          title: "Deskripsi",
                          value: description.isEmpty
                              ? "Deskripsi belum ditambahkan"
                              : description,
                        ),
                      ],
                    ),

                    _facilitySection(
                      title: "Fasilitas Kost",
                      icon: Icons.maps_home_work_outlined,
                      items: kostFacilities,
                    ),

                    _facilitySection(
                      title: "Fasilitas Kamar",
                      icon: Icons.bed_outlined,
                      items: roomFacilities,
                    ),

                    _policySection(
                      title: "Aturan Kost",
                      icon: Icons.rule_outlined,
                      policies: kostRules,
                    ),

                    _policySection(
                      title: "Aturan Kamar",
                      icon: Icons.meeting_room_outlined,
                      policies: roomRules,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageHeader({required String title, required String status}) {
    final int imageCount = images.length > 15 ? 15 : images.length;

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: images.isEmpty
                  ? _imageEmptyState()
                  : PageView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const PageScrollPhysics(),
                      itemCount: imageCount,
                      onPageChanged: (index) {
                        setState(() {
                          currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final img = fixUrl(images[index]);

                        return Image.network(
                          img,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return _imageEmptyState(
                              icon: Icons.broken_image_outlined,
                              text: "Gambar gagal dimuat",
                            );
                          },
                        );
                      },
                    ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.58),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 16,
              left: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: status == "active"
                        ? Colors.green.withOpacity(0.95)
                        : Colors.orange.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == "active"
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: Colors.white,
                        size: 15,
                      ),

                      const SizedBox(width: 5),

                      Text(
                        status == "active" ? "Aktif" : status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (images.isNotEmpty)
              Positioned(
                top: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 16,
                          color: primaryColor,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          "${currentImageIndex + 1}/$imageCount",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 18,
              right: 18,
              bottom: imageCount > 1 ? 40 : 18,
              child: IgnorePointer(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),

            if (imageCount > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: IgnorePointer(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imageCount, (index) {
                          final isActive = currentImageIndex == index;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: isActive ? 22 : 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imageEmptyState({
    IconData icon = Icons.image_outlined,
    String text = "Gambar belum ditambahkan",
  }) {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade500),

          const SizedBox(height: 10),

          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ...children,
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final bool emptyValue =
        value.trim().isEmpty ||
        value.toLowerCase().contains("belum") ||
        value.toLowerCase().contains("tersedia");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 22),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value.trim().isEmpty ? "Belum ditambahkan" : value,
                  style: TextStyle(
                    color: emptyValue ? Colors.grey.shade600 : Colors.black,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _facilitySection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return _sectionCard(
      title: title,
      icon: icon,
      children: [
        if (items.isEmpty)
          _emptyMiniState(
            icon: Icons.widgets_outlined,
            text: "$title belum ditambahkan",
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final item = normalizeText(items[index]);

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getFacilityIcon(item),
                        color: primaryColor,
                        size: 23,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      item,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _policySection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> policies,
  }) {
    return _sectionCard(
      title: title,
      icon: icon,
      children: [
        if (policies.isEmpty)
          _emptyMiniState(
            icon: Icons.rule_outlined,
            text: "$title belum ditambahkan",
          )
        else
          Column(
            children: policies.map((policy) {
              final policyTitle =
                  policy['title']?.toString() ??
                  policy['policy']?.toString() ??
                  "";

              final policyDesc =
                  policy['description']?.toString() ??
                  policy['desc']?.toString() ??
                  policy['policy']?.toString() ??
                  "";

              final policyIcon = getPolicyIcon(policyTitle, policyDesc, title);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(policyIcon, color: primaryColor, size: 23),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policyTitle.isEmpty
                                ? "Aturan belum diberi judul"
                                : policyTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            policyDesc.isEmpty
                                ? "Deskripsi aturan belum ditambahkan"
                                : policyDesc,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
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
    );
  }

  Widget _emptyMiniState({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),

      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade500),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),

            const SizedBox(height: 14),

            const Text(
              "Data tidak ditemukan",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              "Detail kost belum bisa dimuat. Coba refresh halaman ini.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: getDetail,
              icon: const Icon(Icons.refresh),
              label: const Text("Muat Ulang"),
            ),
          ],
        ),
      ),
    );
  }
}
