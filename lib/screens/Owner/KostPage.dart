import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/Add_kost.dart';
import 'package:koskaki/service/api_service.dart';

class KostPage extends StatefulWidget {
  const KostPage({super.key});

  @override
  State<KostPage> createState() => _KostPageState();
}

class _KostPageState extends State<KostPage> {
  List<dynamic> kostList = [];
  bool isLoading = true;

  String getKostPrice(Map<String, dynamic> kost) {
    final price =
        kost['price_perMonth'] ??
        kost['price_per_month'] ??
        kost['pricePerMonth'] ??
        kost['price_permonth'] ??
        kost['price'];

    if (price == null) return "0";

    return price.toString();
  }

  @override
  void initState() {
    super.initState();
    getKost();
  }

  Future<void> getKost() async {
    try {
      final token = await ApiService().getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/my-properties"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print("STATUS : ${response.statusCode}");
      print("BODY : ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          if (decoded['data'] != null && decoded['data']['data'] != null) {
            kostList = decoded['data']['data'];
          } else if (decoded['data'] != null) {
            kostList = decoded['data'];
          } else if (decoded['properties'] != null) {
            kostList = decoded['properties'];
          } else if (decoded is List) {
            kostList = decoded;
          }

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : kostList.isEmpty
          ? const Center(child: Text("Belum ada kost"))
          : RefreshIndicator(
              onRefresh: getKost,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: kostList.length,
                itemBuilder: (context, index) {
                  final kost = kostList[index];

                  final kostData = Map<String, dynamic>.from(kost);

                  print("KOST DATA:");
                  print(jsonEncode(kostData));

                  final title = kostData['title'] ?? "Tanpa Nama";

                  final price = getKostPrice(kostData);
                  final availableRoom =
                      kostData['max_people']?.toString() ?? "0";

                  String thumbnail = "";
                  if (kostData['main_image'] != null) {
                    if (kostData['main_image'] is String) {
                      thumbnail = kostData['main_image'];
                    } else if (kostData['main_image']['image_url'] != null) {
                      thumbnail = kostData['main_image']['image_url'];
                    }
                  } else if (kostData['images'] != null &&
                      kostData['images'].isNotEmpty) {
                    thumbnail = kostData['images'][0]['image_url'] ?? "";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: thumbnail.isNotEmpty
                              ? Image.network(
                                  thumbnail,
                                  height: 190,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 190,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  height: 190,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // TITLE
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // PRICE
                              Text(
                                "Rp $price / bulan",
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A0E50),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // AVAILABLE ROOM
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.bed,
                                          size: 18,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "$availableRoom kamar tersedia",
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddKostPage()),
          );

          getKost();
        },
        backgroundColor: const Color(0xFF0A0E50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
