import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/Add_kost.dart';
import 'package:koskaki/screens/Owner/Detail_kost.dart';
import 'package:koskaki/service/api_service.dart';

class KostPage extends StatefulWidget {
  const KostPage({super.key});

  @override
  State<KostPage> createState() => _KostPageState();
}

class _KostPageState extends State<KostPage> {
  List<dynamic> kostList = [];

  bool isLoading = true;

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);

  @override
  void initState() {
    super.initState();
    getKost();
  }

  // =========================
  // FORMAT RUPIAH
  // =========================

  String formatRupiah(dynamic value) {
    if (value == null) {
      return "";
    }

    String number = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

    if (number.isEmpty) {
      return "";
    }

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

  // =========================
  // GET PRICE
  // =========================

  String getAvailablePrice(Map<String, dynamic> kost) {
    final night = kost['price_perNight'] ?? kost['price_per_night'];

    final week = kost['price_perWeek'] ?? kost['price_per_week'];

    final month = kost['price_perMonth'] ?? kost['price_per_month'];

    final year = kost['price_perYear'] ?? kost['price_per_year'];

    // Prioritas utama: harga bulan
    if (month != null && month.toString().isNotEmpty) {
      return "Rp ${formatRupiah(month)} / Bulan";
    }

    // Kalau harga bulan kosong, baru cek harga tahun
    if (year != null && year.toString().isNotEmpty) {
      return "Rp ${formatRupiah(year)} / Tahun";
    }

    // Kalau tahun kosong, baru cek minggu
    if (week != null && week.toString().isNotEmpty) {
      return "Rp ${formatRupiah(week)} / Minggu";
    }

    // Terakhir baru harga malam
    if (night != null && night.toString().isNotEmpty) {
      return "Rp ${formatRupiah(night)} / Malam";
    }

    return "Harga belum tersedia";
  }

  // =========================
  // GET IMAGE
  // =========================

  String getImage(
      Map<String, dynamic> kost,
      ) {
    String thumbnail = "";

    try {
      // MAIN IMAGE
      if (kost['main_image'] != null) {
        final mainImage =
        kost['main_image'];

        if (mainImage is String) {
          thumbnail = mainImage;
        } else if (mainImage is Map) {
          thumbnail =
              mainImage['url']
                  ?.toString() ??
                  "";
        }
      }

      // IMAGES
      if (thumbnail.isEmpty &&
          kost['images'] != null &&
          kost['images'] is List &&
          kost['images'].isNotEmpty) {
        thumbnail =
            kost['images'][0]['url']
                ?.toString() ??
                "";
      }

      // FIX URL
      if (thumbnail.isNotEmpty &&
          !thumbnail.startsWith(
            "http",
          )) {
        thumbnail =
        "https://koskaki-api.servermbud.online/storage/$thumbnail";
      }
    } catch (e) {
      print("IMAGE ERROR: $e");
    }

    return thumbnail;
  }

  // =========================
  // GET KOST
  // =========================

  Future<void> getKost() async {
    try {
      final token = await ApiService().getToken();

      final response = await http.get(
        Uri.parse(
          "${ApiService.baseUrl}/my-properties",
        ),

        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          if (decoded['data'] != null && decoded['data']['data'] != null) {
            kostList = decoded['data']['data'];
          } else if (decoded['data'] != null) {
            kostList = decoded['data'];
          } else {
            kostList = [];
          }

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),

      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: getKost,

        child: ListView.builder(
          padding:
          const EdgeInsets.all(
            16,
          ),

          itemCount:
          kostList.length,

          itemBuilder:
              (context, index) {
            final kost =
            Map<String, dynamic>.from(
              kostList[index],
            );

            final title =
                kost['title'] ??
                    "Tanpa Nama";

            final price =
            getAvailablePrice(
              kost,
            );

            final maxPeople =
                kost['max_people']
                    ?.toString() ??
                    "0";

            final thumbnail =
            getImage(kost);

            return GestureDetector(
              onTap: () async {
                final result =
                await Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder:
                        (_) =>
                        DetailKostPage(
                          kost: kost,
                        ),
                  ),
                );

                if (result == true) {
                  getKost();
                }
              },

              child: Container(
                margin:
                const EdgeInsets.only(
                  bottom: 16,
                ),

                decoration:
                BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 68,
            width: 68,

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
            ),

            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // CARD
  // =========================

  Widget _buildKostCard({
    required String title,
    required String price,
    required String maxPeople,
    required String status,
    required String cityName,
    required String thumbnail,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),

                    topRight: Radius.circular(26),
                  ),

                  child: thumbnail.isNotEmpty
                      ? Image.network(
                          thumbnail,
                          height: 210,
                          width: double.infinity,
                          fit: BoxFit.cover,

                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                          return Container(
                            height:
                            200,

                            color:
                            Colors.grey[
                            200],

                            child:
                            const Center(
                              child:
                              CircularProgressIndicator(),
                            ),
                          );
                        },

                        errorBuilder:
                            (
                            context,
                            error,
                            stackTrace,
                            ) {
                          print(
                            error,
                          );

                          return Container(
                            height:
                            200,

                            color:
                            Colors.grey[
                            300],

                            child:
                            const Center(
                              child:
                              Icon(
                                Icons
                                    .broken_image,

                                size:
                                60,

                                color:
                                Colors.grey,
                              ),
                            ),
                          );
                        },
                      )
                          : Container(
                        height:
                        200,

                        color:
                        Colors.grey[
                        300],

                        child:
                        const Center(
                          child:
                          Icon(
                            Icons
                                .image,

                            size:
                            60,

                            color:
                            Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    // =========================
                    // CONTENT
                    // =========================

                    Padding(
                      padding:
                      const EdgeInsets.all(
                        16,
                      ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight
                                  .bold,
                        ),
                      ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            price,

                            style:
                            const TextStyle(
                              fontSize:
                              18,

                              fontWeight:
                              FontWeight
                                  .bold,

                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            color: softGreen,
                            borderRadius: BorderRadius.circular(18),
                          ),

                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),

                                decoration: BoxDecoration(
                                  color: Colors.white,

                                  borderRadius: BorderRadius.circular(12),
                                ),

                                decoration:
                                BoxDecoration(
                                  color: Colors
                                      .green
                                      .withOpacity(
                                    0.1,
                                  ),

                                  borderRadius:
                                  BorderRadius.circular(
                                    30,
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .people,

                                      size:
                                      18,

                                      color:
                                      Colors.green,
                                    ),

                                    const SizedBox(
                                      width:
                                      6,
                                    ),

                                    Text(
                                      price,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,

                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoBadge(
                          icon: Icons.people_alt_outlined,
                          title: "$maxPeople orang",
                          subtitle: "Kapasitas",
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _buildInfoBadge(
                          icon: Icons.home_work_outlined,
                          title: "Kos",
                          subtitle: "Tipe properti",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 46,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),

                      onPressed: onTap,

                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Text(
                            "Lihat Detail",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),

                          SizedBox(width: 8),

                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
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

  // =========================
  // INFO BADGE
  // =========================

  Widget _buildInfoBadge({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 22),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // IMAGE PLACEHOLDER
  // =========================

  Widget _buildImagePlaceholder({
    IconData icon = Icons.image_outlined,
    String text = "Belum ada gambar",
  }) {
    return Container(
      height: 210,
      width: double.infinity,

      decoration: BoxDecoration(color: Colors.grey.shade200),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icon, size: 54, color: Colors.grey.shade500),

          const SizedBox(height: 8),

          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // EMPTY STATE
  // =========================

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            height: 120,
            width: 120,

            decoration: BoxDecoration(color: softGreen, shape: BoxShape.circle),

            child: Icon(
              Icons.home_work_outlined,
              size: 58,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            "Belum Ada Kos",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            "Tambahkan kos pertamamu agar calon penyewa bisa melihat properti yang kamu miliki.",
            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,

              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),

        onPressed: () async {
          await Navigator.push(
            context,

            MaterialPageRoute(
              builder:
                  (_) =>
              const AddKostPage(),
            ),
          );

              getKost();
            },

            icon: const Icon(Icons.add_home_work_outlined),

            label: const Text(
              "Tambah Kos Sekarang",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
