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

  @override
  void initState() {
    super.initState();
    getKost();
  }

  // =========================
  // GET PRICE
  // =========================

  String getAvailablePrice(
      Map<String, dynamic> kost,
      ) {
    final night =
        kost['price_perNight'] ??
            kost['price_per_night'];

    final week =
        kost['price_perWeek'] ??
            kost['price_per_week'];

    final month =
        kost['price_perMonth'] ??
            kost['price_per_month'];

    final year =
        kost['price_perYear'] ??
            kost['price_per_year'];

    if (night != null &&
        night.toString().isNotEmpty) {
      return "Rp $night / malam";
    }

    if (week != null &&
        week.toString().isNotEmpty) {
      return "Rp $week / minggu";
    }

    if (month != null &&
        month.toString().isNotEmpty) {
      return "Rp $month / bulan";
    }

    if (year != null &&
        year.toString().isNotEmpty) {
      return "Rp $year / tahun";
    }

    return "Harga belum tersedia";
  }

  // =========================
  // GET KOST
  // =========================

  Future<void> getKost() async {
    try {
      final token =
      await ApiService().getToken();

      final response = await http.get(
        Uri.parse(
          "${ApiService.baseUrl}/my-properties",
        ),
        headers: {
          "Authorization":
          "Bearer $token",
          "Accept":
          "application/json",
        },
      );

      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final decoded =
        jsonDecode(response.body);

        setState(() {
          if (decoded['data'] != null &&
              decoded['data']['data'] !=
                  null) {
            kostList =
            decoded['data']['data'];
          } else if (decoded['data'] !=
              null) {
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
      backgroundColor: Colors.white,

      body: isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : kostList.isEmpty
          ? const Center(
        child: Text(
          "Belum ada kost",
        ),
      )
          : RefreshIndicator(
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
            Map<String, dynamic>
                .from(
              kostList[index],
            );

            print(jsonEncode(kost));

            // =========================
            // DATA
            // =========================

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

            // =========================
            // IMAGE
            // =========================

            String thumbnail = "";

            try {
              if (kost[
              'main_image'] !=
                  null) {
                final mainImage =
                kost[
                'main_image'];

                if (mainImage
                is String) {
                  thumbnail =
                      mainImage;
                } else if (mainImage
                is Map) {
                  thumbnail =
                      mainImage['url']
                          ?.toString() ??
                          "";
                }
              }

              if (thumbnail
                  .isEmpty &&
                  kost['images'] !=
                      null &&
                  kost['images']
                  is List &&
                  kost['images']
                      .isNotEmpty) {
                thumbnail =
                    kost['images'][0]
                    ['url']
                        ?.toString() ??
                        "";
              }
              if (thumbnail.isNotEmpty &&
                  !thumbnail.startsWith("http")) {
                thumbnail =
                "https://koskaki-api.servermbud.online/storage/$thumbnail";
              }

              print(thumbnail);
            } catch (e) {
              print(
                "IMAGE ERROR: $e",
              );
            }

            return GestureDetector(
              onTap: () {
                // pindah detail
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

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(
                        0.05,
                      ),

                      blurRadius: 10,

                      offset:
                      const Offset(
                        0,
                        4,
                      ),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    // =========================
                    // IMAGE
                    // =========================

                    ClipRRect(
                      borderRadius:
                      const BorderRadius.only(
                        topLeft:
                        Radius.circular(
                          20,
                        ),
                        topRight:
                        Radius.circular(
                          20,
                        ),
                      ),

                      child:
                      thumbnail
                          .isNotEmpty
                          ? Image.network(
                        thumbnail,

                        height:
                        200,

                        width:
                        double.infinity,

                        fit:
                        BoxFit.cover,

                        loadingBuilder:
                            (
                            context,
                            child,
                            loadingProgress,
                            ) {
                          if (loadingProgress ==
                              null) {
                            return child;
                          }

                          return Container(
                            height:
                            200,

                            color:
                            Colors.grey[200],

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
                            Colors.grey[300],

                            child:
                            const Center(
                              child:
                              Icon(
                                Icons.broken_image,
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
                        Colors.grey[300],

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
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          Text(
                            title,

                            style:
                            const TextStyle(
                              fontSize:
                              20,

                              fontWeight:
                              FontWeight.bold,
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
                              FontWeight.bold,

                              color:
                              Color(
                                0xFF0A0E50,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          Row(
                            children: [
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                  horizontal:
                                  12,
                                  vertical:
                                  6,
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

                                child:
                                Row(
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
                                      "$maxPeople orang",

                                      style:
                                      const TextStyle(
                                        color:
                                        Colors.green,

                                        fontWeight:
                                        FontWeight.w600,
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
              ),
            );
          },
        ),
      ),

      floatingActionButton:
      FloatingActionButton(
        backgroundColor:
        const Color(0xFF0A0E50),

        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),

        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => const AddKostPage(),
            ),
          );

          getKost();
        },
      ),
    );
  }
}