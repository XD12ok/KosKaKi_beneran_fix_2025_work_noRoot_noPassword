import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:koskaki/service/api_service.dart';

class AddKostPage extends StatefulWidget {
  const AddKostPage({super.key});

  @override
  State<AddKostPage> createState() => _AddKostPageState();
}

class _AddKostPageState extends State<AddKostPage> {
  // =========================
  // CONTROLLER
  // =========================

  final titleController = TextEditingController();
  final descController = TextEditingController();
  final addressController = TextEditingController();
  final maxPeopleController = TextEditingController();

  final nightlyPriceController = TextEditingController();
  final weeklyPriceController = TextEditingController();
  final monthlyPriceController = TextEditingController();
  final yearlyPriceController = TextEditingController();

  // =========================
  // DATA
  // =========================

  List<File> images = [];

  bool isLoading = false;

  List<Map<String, dynamic>> cities = [];

  int? selectedCityId;

  // =========================
  // PROPERTY FEATURES
  // =========================

  List<String> propertyFeatures = [];

  final List<String> propertyFeatureOptions = [
    "WiFi",
    "CCTV",
    "Parkir Motor",
    "Parkir Mobil",
    "Dapur Bersama",
    "Laundry",
    "Ruang Tamu",
    "Keamanan 24 Jam",
    "Mushola",
  ];

  // =========================
  // ROOM FEATURES
  // =========================

  List<String> roomFeatures = [];

  final List<String> roomFeatureOptions = [
    "AC",
    "TV",
    "Kasur",
    "Lemari",
    "Meja",
    "Kursi",
    "Kulkas",
    "Kamar Mandi Dalam",
  ];

  // =========================
  // PROPERTY POLICIES
  // =========================

  List<Map<String, dynamic>> propertyPolicies = [
    {
      "title": TextEditingController(),
      "description": TextEditingController(),
    }
  ];

  // =========================
  // ROOM POLICIES
  // =========================

  List<Map<String, dynamic>> roomPolicies = [
    {
      "title": TextEditingController(),
      "description": TextEditingController(),
    }
  ];

  // =========================
  // INIT
  // =========================

  @override
  void initState() {
    super.initState();
    loadCities();
  }

  // =========================
  // LOAD CITIES
  // =========================

  Future<void> loadCities() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/cities"),
        headers: {
          'Accept': 'application/json',
        },
      );

      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          cities = List<Map<String, dynamic>>.from(
            decoded['data'],
          );
        });
      }
    } catch (e) {
      print(e);
    }
  }

  // =========================
  // PICK IMAGE
  // =========================

  Future<void> pickImage() async {
    final pickedImages = await ImagePicker().pickMultiImage();

    if (pickedImages.isEmpty) return;

    if ((images.length + pickedImages.length) > 15) {
      showMessage("Maksimal 15 gambar");
      return;
    }

    List<File> compressedImages = [];

    for (var picked in pickedImages) {
      final compressed =
      await FlutterImageCompress.compressAndGetFile(
        picked.path,
        "${picked.path}_compressed.jpg",
        quality: 60,
      );

      if (compressed != null) {
        compressedImages.add(
          File(compressed.path),
        );
      }
    }

    setState(() {
      images.addAll(compressedImages);
    });
  }

  // =========================
  // CREATE PROPERTY
  // =========================

  Future<void> tambahKost() async {
    if (titleController.text.isEmpty ||
        descController.text.isEmpty ||
        addressController.text.isEmpty ||
        maxPeopleController.text.isEmpty ||
        selectedCityId == null ||
        images.isEmpty) {
      showMessage("Semua field wajib diisi");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final token = await ApiService().getToken();

      // =========================
      // CREATE PROPERTY
      // =========================

      final Map<String, String> body = {
        'title': titleController.text,
        'description': descController.text,
        'address': addressController.text,
        'city_id': selectedCityId.toString(),
        'max_people': maxPeopleController.text,
        'status': 'active',
      };

      // nullable harga
      if (nightlyPriceController.text.isNotEmpty) {
        body['price_perNight'] = nightlyPriceController.text;
      }

      if (weeklyPriceController.text.isNotEmpty) {
        body['price_perWeek'] = weeklyPriceController.text;
      }

      if (monthlyPriceController.text.isNotEmpty) {
        body['price_perMonth'] = monthlyPriceController.text;
      }

      if (yearlyPriceController.text.isNotEmpty) {
        body['price_perYear'] = yearlyPriceController.text;
      }

      final createResponse = await http.post(
        Uri.parse("${ApiService.baseUrl}/properties"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: body,
      );

      print("CREATE STATUS:");
      print(createResponse.statusCode);

      print("CREATE BODY:");
      print(createResponse.body);

      if (createResponse.statusCode != 200 &&
          createResponse.statusCode != 201) {
        showMessage(
          "Gagal membuat kost",
        );

        setState(() {
          isLoading = false;
        });

        return;
      }

      Map<String, dynamic> decoded =
      jsonDecode(createResponse.body);

      final String propertyId =
      decoded['data']['id'].toString();

      print("PROPERTY ID:");
      print(propertyId);

      // =========================
      // UPLOAD IMAGES
      // =========================

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          "${ApiService.baseUrl}/properties/$propertyId/images",
        ),
      );

      request.headers['Authorization'] =
      'Bearer $token';

      request.headers['Accept'] =
      'application/json';

      for (var image in images) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'images[]',
            image.path,
          ),
        );
      }

      final uploadResponse = await request.send();

      print("UPLOAD STATUS:");
      print(uploadResponse.statusCode);

      // =========================
      // PROPERTY FEATURES
      // =========================

      for (var feature in propertyFeatures) {
        await http.post(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/features",
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: {
            "name": feature,
          },
        );
      }

      // =========================
      // ROOM FEATURES
      // =========================

      for (var feature in roomFeatures) {
        await http.post(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/place-properties/1/features",
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: {
            "name": feature,
          },
        );
      }

      // =========================
      // PROPERTY POLICIES
      // =========================

      for (var policy in propertyPolicies) {
        final title =
            (policy['title'] as TextEditingController)
                .text;

        final description =
            (policy['description']
            as TextEditingController)
                .text;

        if (title.isNotEmpty) {
          await http.post(
            Uri.parse(
              "${ApiService.baseUrl}/properties/$propertyId/policies",
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: {
              "title": title,
              "description": description,
            },
          );
        }
      }

      // =========================
      // ROOM POLICIES
      // =========================

      for (var policy in roomPolicies) {
        final title =
            (policy['title'] as TextEditingController)
                .text;

        final description =
            (policy['description']
            as TextEditingController)
                .text;

        if (title.isNotEmpty) {
          await http.post(
            Uri.parse(
              "${ApiService.baseUrl}/properties/$propertyId/place-properties/1/policies",
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: {
              "title": title,
              "description": description,
            },
          );
        }
      }

      showMessage(
        "Kost berhasil dibuat",
        success: true,
      );

      Navigator.pop(context);
    } catch (e) {
      print(e);

      showMessage("Error: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  // =========================
  // SNACKBAR
  // =========================

  void showMessage(
      String msg, {
        bool success = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
        success ? Colors.green : Colors.red,
      ),
    );
  }

  // =========================
  // INPUT
  // =========================

  Widget input(
      String label,
      TextEditingController controller, {
        TextInputType type = TextInputType.text,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // POLICY CARD
  // =========================

  Widget policyCard(
      List<Map<String, dynamic>> list,
      int index,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          input(
            "Judul Peraturan",
            list[index]['title'],
          ),
          input(
            "Penjelasan",
            list[index]['description'],
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: const Text("Tambah Kost"),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // =========================
              // IMAGE
              // =========================

              GestureDetector(
                onTap: pickImage,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: images.isEmpty
                      ? const Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text("Tambah Foto Kost"),
                      SizedBox(height: 5),
                      Text("Maksimal 15 gambar"),
                    ],
                  )
                      : GridView.builder(
                    padding:
                    const EdgeInsets.all(10),
                    itemCount: images.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder:
                        (context, index) {
                      return ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          12,
                        ),
                        child: Image.file(
                          images[index],
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    input(
                      "Nama Kost",
                      titleController,
                    ),

                    input(
                      "Deskripsi",
                      descController,
                      maxLines: 4,
                    ),

                    // =========================
                    // HARGA
                    // =========================

                    Row(
                      children: [

                        Expanded(
                          child: input(
                            "Harga Malam",
                            nightlyPriceController,
                            type: TextInputType.number,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: input(
                            "Harga Minggu",
                            weeklyPriceController,
                            type: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [

                        Expanded(
                          child: input(
                            "Harga Bulan",
                            monthlyPriceController,
                            type: TextInputType.number,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: input(
                            "Harga Tahun",
                            yearlyPriceController,
                            type: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    input(
                      "Alamat",
                      addressController,
                      maxLines: 3,
                    ),

                    // =========================
                    // CITY
                    // =========================

                    const Text(
                      "Pilih Kota",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    DropdownSearch<
                        Map<String, dynamic>>(
                      items: cities,
                      itemAsString: (item) =>
                          item['name'].toString(),
                      popupProps:
                      const PopupProps
                          .modalBottomSheet(
                        showSearchBox: true,
                      ),
                      dropdownDecoratorProps:
                      DropDownDecoratorProps(
                        dropdownSearchDecoration:
                        InputDecoration(
                          hintText: "Pilih Kota",
                          filled: true,
                          fillColor:
                          Colors.grey[100],
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                            BorderSide.none,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedCityId =
                          value?['id'];
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    input(
                      "Max Orang",
                      maxPeopleController,
                      type: TextInputType.number,
                    ),

                    // =========================
                    // PROPERTY FEATURES
                    // =========================

                    const Text(
                      "Fasilitas Tempat",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                      propertyFeatureOptions.map(
                            (feature) {
                          return FilterChip(
                            selected:
                            propertyFeatures
                                .contains(
                              feature,
                            ),
                            label: Text(feature),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  propertyFeatures
                                      .add(feature);
                                } else {
                                  propertyFeatures
                                      .remove(
                                    feature,
                                  );
                                }
                              });
                            },
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(height: 24),

                    // =========================
                    // ROOM FEATURES
                    // =========================

                    const Text(
                      "Fasilitas Kamar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                      roomFeatureOptions.map(
                            (feature) {
                          return FilterChip(
                            selected:
                            roomFeatures
                                .contains(
                              feature,
                            ),
                            label: Text(feature),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  roomFeatures
                                      .add(feature);
                                } else {
                                  roomFeatures
                                      .remove(
                                    feature,
                                  );
                                }
                              });
                            },
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(height: 24),

                    // =========================
                    // PROPERTY POLICY
                    // =========================

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [
                        const Text(
                          "Peraturan Tempat",
                          style: TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              propertyPolicies.add({
                                "title":
                                TextEditingController(),
                                "description":
                                TextEditingController(),
                              });
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),

                    ...List.generate(
                      propertyPolicies.length,
                          (index) => policyCard(
                        propertyPolicies,
                        index,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =========================
                    // ROOM POLICY
                    // =========================

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [
                        const Text(
                          "Peraturan Kamar",
                          style: TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              roomPolicies.add({
                                "title":
                                TextEditingController(),
                                "description":
                                TextEditingController(),
                              });
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),

                    ...List.generate(
                      roomPolicies.length,
                          (index) => policyCard(
                        roomPolicies,
                        index,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  isLoading ? null : tambahKost,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF0A0E50),
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : const Text(
                    "Simpan Kost",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<dynamic> parseJsonData(String response) {
  return jsonDecode(response);
}