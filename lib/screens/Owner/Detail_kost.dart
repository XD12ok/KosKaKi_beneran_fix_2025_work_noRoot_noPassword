import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/Edit_kost.dart';

class DetailKostPage extends StatefulWidget {
  final Map<String, dynamic> kost;

  const DetailKostPage({
    super.key,
    required this.kost,
  });

  @override
  State<DetailKostPage> createState() =>
      _DetailKostPageState();
}

class _DetailKostPageState extends State<DetailKostPage> {
  bool isLoading = true;

  Map<String, dynamic>? detail;

  List<dynamic> images = [];
  List<dynamic> features = [];
  List<dynamic> policies = [];

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  // =========================
  // GET DETAIL
  // =========================

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

      final decoded = jsonDecode(response.body);
      final data = decoded['data'] ?? decoded;

      setState(() {
        detail = Map<String, dynamic>.from(data);
        images = data['images'] ?? [];
        features = data['features'] ?? [];
        policies = data['policies'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // =========================
  // PRICE
  // =========================

  String getPrice() {
    final d = detail ?? {};

    final night = d['price_perNight'];
    final week = d['price_perWeek'];
    final month = d['price_perMonth'];
    final year = d['price_perYear'];

    if (night != null) return "Rp $night / malam";
    if (week != null) return "Rp $week / minggu";
    if (month != null) return "Rp $month / bulan";
    if (year != null) return "Rp $year / tahun";

    return "Harga belum tersedia";
  }

  // =========================
  // DELETE
  // =========================

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.body)),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  // =========================
  // EDIT NAVIGATION
  // =========================

  void goEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditKostPage(
          kost: detail!,
        ),
      ),
    ).then((value) {
      if (value == true) {
        getDetail();
      }
    });
  }

  // =========================
  // IMAGE FIX
  // =========================

  String fixUrl(dynamic img) {
    String url = "";

    if (img is String) {
      url = img;
    } else if (img is Map) {
      url = img['url'] ?? "";
    }

    if (url.isNotEmpty && !url.startsWith("http")) {
      url =
      "https://koskaki-api.servermbud.online/storage/$url";
    }

    return url;
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Detail Kost"),
      ),

      // =========================
      // BOTTOM BUTTON
      // =========================
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: goEdit,
                icon: const Icon(Icons.edit),
                label: const Text("Edit"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () async {
                  final ok = await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Hapus?"),
                      content: const Text(
                        "Yakin mau hapus kost ini?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Batal"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Hapus"),
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    deleteKost();
                  }
                },
                icon: const Icon(Icons.delete),
                label: const Text("Hapus"),
              ),
            ),
          ],
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? const Center(child: Text("Data kosong"))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            SizedBox(
              height: 250,
              child: images.isEmpty
                  ? Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 80),
              )
                  : PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, i) {
                  final img = fixUrl(images[i]);

                  return Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail!['title'] ?? "-",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    getPrice(),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF0A0E50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Fasilitas",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    children: features.map((f) {
                      return Chip(
                        label: Text(f['name'] ?? "-"),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Peraturan",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Column(
                    children: policies.map((p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] ?? "-",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(p['description'] ?? "-"),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}