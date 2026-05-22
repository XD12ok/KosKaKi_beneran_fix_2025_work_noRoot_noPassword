import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
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
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final addressController = TextEditingController();
  final maxPeopleController = TextEditingController();

  final nightlyPriceController = TextEditingController();
  final weeklyPriceController = TextEditingController();
  final monthlyPriceController = TextEditingController();
  final yearlyPriceController = TextEditingController();

  final nearbyDistanceController = TextEditingController();

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  List<File> images = [];

  bool isLoading = false;
  bool isLoadingPlaces = false;

  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> places = [];

  int? selectedCityId;
  Map<String, dynamic>? selectedNearbyPlace;

  List<String> selectedKostFacilities = [];
  List<String> selectedRoomFacilities = [];

  List<Map<String, TextEditingController>> kostRules = [];
  List<Map<String, TextEditingController>> roomRules = [];

  final List<String> kostFacilityOptions = [
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

  final List<String> roomFacilityOptions = [
    "AC",
    "TV",
    "Kasur",
    "Lemari",
    "Meja",
    "Kursi",
    "Kulkas",
    "Kamar Mandi Dalam",
  ];

  @override
  void initState() {
    super.initState();

    loadCities();

    kostRules.add({
      "title": TextEditingController(),
      "desc": TextEditingController(),
    });

    roomRules.add({
      "title": TextEditingController(),
      "desc": TextEditingController(),
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    addressController.dispose();
    maxPeopleController.dispose();

    nightlyPriceController.dispose();
    weeklyPriceController.dispose();
    monthlyPriceController.dispose();
    yearlyPriceController.dispose();

    nearbyDistanceController.dispose();

    for (final item in kostRules) {
      item["title"]?.dispose();
      item["desc"]?.dispose();
    }

    for (final item in roomRules) {
      item["title"]?.dispose();
      item["desc"]?.dispose();
    }

    super.dispose();
  }

  Future<void> loadCities() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/cities"),
        headers: {'Accept': 'application/json'},
      );

      print("CITY STATUS:");
      print(response.statusCode);

      print("CITY BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> cityData = [];

        if (decoded is List) {
          cityData = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          cityData = decoded['data'];
        } else if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          cityData = decoded['data']['data'];
        }

        if (!mounted) return;

        setState(() {
          cities = cityData.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
        });

        print("TOTAL CITIES:");
        print(cities.length);
      } else {
        showMessage("Gagal mengambil data kota");
      }
    } catch (e) {
      print("LOAD CITY ERROR:");
      print(e);
      showMessage("Error mengambil kota: $e");
    }
  }

  Future<void> loadPlacesByCity(int cityId) async {
    if (!mounted) return;

    setState(() {
      isLoadingPlaces = true;
      places = [];
      selectedNearbyPlace = null;
      nearbyDistanceController.clear();
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/cities/$cityId/places"),
        headers: {'Accept': 'application/json'},
      );

      print("PLACES STATUS:");
      print(response.statusCode);

      print("PLACES BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> placeData = [];

        if (decoded is List) {
          placeData = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          placeData = decoded['data'];
        } else if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          placeData = decoded['data']['data'];
        }

        if (!mounted) return;

        setState(() {
          places = placeData.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
        });

        print("TOTAL PLACES:");
        print(places.length);
      } else {
        showMessage("Gagal mengambil data tempat");
      }
    } catch (e) {
      print("LOAD PLACES ERROR:");
      print(e);
      showMessage("Error mengambil tempat: $e");
    }

    if (!mounted) return;

    setState(() {
      isLoadingPlaces = false;
    });
  }

  String cleanPrice(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String cleanDistance(String value) {
    String result = value
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');

    final parts = result.split('.');

    if (parts.length > 2) {
      result = '${parts.first}.${parts.skip(1).join()}';
    }

    return result;
  }

  String getPlaceName(Map<String, dynamic> item) {
    return item['name']?.toString() ??
        item['title']?.toString() ??
        item['place_name']?.toString() ??
        item['nama']?.toString() ??
        "-";
  }

  String getPlaceType(Map<String, dynamic> item) {
    return item['type']?.toString() ??
        item['category']?.toString() ??
        item['place_type']?.toString() ??
        item['kategori']?.toString() ??
        "";
  }

  String selectedListToDatabaseString(List<String> values) {
    return values
        .map((item) {
          return item
              .toLowerCase()
              .replaceAll(" ", "_")
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        })
        .where((item) => item.isNotEmpty)
        .join(',');
  }

  List<Map<String, String>> buildRulesPayload(
    List<Map<String, TextEditingController>> source,
  ) {
    return source
        .map((item) {
          return {
            "title": item["title"]?.text.trim() ?? "",
            "description": item["desc"]?.text.trim() ?? "",
          };
        })
        .where((item) {
          return item["title"]!.isNotEmpty || item["description"]!.isNotEmpty;
        })
        .toList();
  }

  Future<void> pickImage() async {
    final pickedImages = await ImagePicker().pickMultiImage();

    if (pickedImages.isEmpty) return;

    if ((images.length + pickedImages.length) > 15) {
      showMessage("Maksimal 15 gambar");
      return;
    }

    List<File> compressedImages = [];

    for (var picked in pickedImages) {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        "${picked.path}_compressed.jpg",
        quality: 60,
      );

      if (compressed != null) {
        compressedImages.add(File(compressed.path));
      }
    }

    setState(() {
      images.addAll(compressedImages);
    });
  }

  Future<void> uploadKostFeatures({
    required String propertyId,
    required String token,
  }) async {
    final String placeId = propertyId;

    for (final feature in selectedKostFacilities) {
      final response = await http.post(
        Uri.parse(
          "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/features",
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'feature': feature},
      );

      print("UPLOAD KOST FEATURE:");
      print(feature);

      print("UPLOAD KOST FEATURE STATUS:");
      print(response.statusCode);

      print("UPLOAD KOST FEATURE BODY:");
      print(response.body);
    }
  }

  Future<void> uploadRoomFeatures({
    required String propertyId,
    required String token,
  }) async {
    for (final feature in selectedRoomFacilities) {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/features"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'feature': feature},
      );

      print("UPLOAD ROOM FEATURE:");
      print(feature);

      print("UPLOAD ROOM FEATURE STATUS:");
      print(response.statusCode);

      print("UPLOAD ROOM FEATURE BODY:");
      print(response.body);
    }
  }

  Future<void> uploadKostPolicies({
    required String propertyId,
    required String token,
  }) async {
    final String placeId = propertyId;

    final rules = buildRulesPayload(kostRules);

    for (final rule in rules) {
      final response = await http.post(
        Uri.parse(
          "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/policies",
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'title': rule['title'] ?? '',
          'description': rule['description'] ?? '',
        },
      );

      print("UPLOAD KOST POLICY:");
      print(rule);

      print("UPLOAD KOST POLICY STATUS:");
      print(response.statusCode);

      print("UPLOAD KOST POLICY BODY:");
      print(response.body);
    }
  }

  Future<void> uploadRoomPolicies({
    required String propertyId,
    required String token,
  }) async {
    final rules = buildRulesPayload(roomRules);

    for (final rule in rules) {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/policies"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'title': rule['title'] ?? '',
          'description': rule['description'] ?? '',
        },
      );

      print("UPLOAD ROOM POLICY:");
      print(rule);

      print("UPLOAD ROOM POLICY STATUS:");
      print(response.statusCode);

      print("UPLOAD ROOM POLICY BODY:");
      print(response.body);
    }
  }

  Future<void> uploadNearbyPlace({
    required String propertyId,
    required String token,
  }) async {
    final place = selectedNearbyPlace;
    final distance = cleanDistance(nearbyDistanceController.text.trim());

    if (place == null || distance.isEmpty) {
      return;
    }

    final String placeId = place['id'].toString();

    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/properties/$propertyId/nearby-places"),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      body: {
        'place_id': placeId,
        'placeId': placeId,
        'nearby_place_id': placeId,
        'distance': distance,
        'distance_km': distance,
        'distance_unit': 'km',
      },
    );

    print("UPLOAD NEARBY PLACE:");
    print({'place_id': placeId, 'distance': distance, 'distance_unit': 'km'});

    print("UPLOAD NEARBY PLACE STATUS:");
    print(response.statusCode);

    print("UPLOAD NEARBY PLACE BODY:");
    print(response.body);
  }

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

    final bool hasNearbyInput =
        selectedNearbyPlace != null ||
        nearbyDistanceController.text.trim().isNotEmpty;

    if (hasNearbyInput) {
      if (selectedNearbyPlace == null ||
          nearbyDistanceController.text.trim().isEmpty) {
        showMessage("Pilih lokasi terdekat dan isi jaraknya");
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final token = await ApiService().getToken();

      if (token == null || token.isEmpty) {
        showMessage("Token tidak ditemukan, silakan login ulang");

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      final kostFacilitiesString = selectedListToDatabaseString(
        selectedKostFacilities,
      );

      final roomFacilitiesString = selectedListToDatabaseString(
        selectedRoomFacilities,
      );

      final kostRulesJson = jsonEncode(buildRulesPayload(kostRules));

      final roomRulesJson = jsonEncode(buildRulesPayload(roomRules));

      final Map<String, String> body = {
        'title': titleController.text,
        'description': descController.text,
        'address': addressController.text,
        'city_id': selectedCityId.toString(),
        'max_people': maxPeopleController.text,
        'status': 'active',

        'kost_facilities': kostFacilitiesString,
        'room_facilities': roomFacilitiesString,
        'kost_rules': kostRulesJson,
        'room_rules': roomRulesJson,

        'property_features': kostFacilitiesString,
        'place_features': roomFacilitiesString,
        'property_policies': kostRulesJson,
        'place_policies': roomRulesJson,

        'feature': kostFacilitiesString,
        'features': kostFacilitiesString,
        'policies': kostRulesJson,
      };

      final nightlyPrice = cleanPrice(nightlyPriceController.text);
      final weeklyPrice = cleanPrice(weeklyPriceController.text);
      final monthlyPrice = cleanPrice(monthlyPriceController.text);
      final yearlyPrice = cleanPrice(yearlyPriceController.text);

      if (nightlyPrice.isNotEmpty) {
        body['price_perNight'] = nightlyPrice;
      }

      if (weeklyPrice.isNotEmpty) {
        body['price_perWeek'] = weeklyPrice;
      }

      if (monthlyPrice.isNotEmpty) {
        body['price_perMonth'] = monthlyPrice;
      }

      if (yearlyPrice.isNotEmpty) {
        body['price_perYear'] = yearlyPrice;
      }

      print("BODY YANG DIKIRIM:");
      print(body);

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
        showMessage("Gagal membuat kost");

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      final Map<String, dynamic> decoded = jsonDecode(createResponse.body);

      final String propertyId = decoded['data']['id'].toString();

      print("PROPERTY ID:");
      print(propertyId);

      await uploadKostFeatures(propertyId: propertyId, token: token);

      await uploadRoomFeatures(propertyId: propertyId, token: token);

      await uploadKostPolicies(propertyId: propertyId, token: token);

      await uploadRoomPolicies(propertyId: propertyId, token: token);

      await uploadNearbyPlace(propertyId: propertyId, token: token);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/images"),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      for (var image in images) {
        request.files.add(
          await http.MultipartFile.fromPath('images[]', image.path),
        );
      }

      final uploadResponse = await request.send();

      print("UPLOAD IMAGE STATUS:");
      print(uploadResponse.statusCode);

      showMessage("Kost berhasil dibuat", success: true);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("ERROR TAMBAH KOST:");
      print(e);

      showMessage("Error: $e");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String msg, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget input(
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    IconData icon = Icons.edit_outlined,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: maxLines == 1
                  ? Icon(icon, color: primaryColor)
                  : null,
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget priceInput(
    String label,
    TextEditingController controller, {
    IconData icon = Icons.payments_outlined,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "0",
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              prefixText: "Rp ",
              prefixStyle: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
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

  Widget featureChip({
    required String feature,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      selected: selected,
      label: Text(
        feature,
        style: TextStyle(
          color: selected ? Colors.white : primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: selected
          ? const Icon(Icons.check_circle, color: Colors.white, size: 18)
          : null,
      backgroundColor: const Color(0xFFF4F6FA),
      selectedColor: primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? primaryColor : Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      onSelected: onSelected,
    );
  }

  Widget policyCard(List<Map<String, TextEditingController>> list, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Aturan ${index + 1}",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (list.length > 1)
                IconButton(
                  onPressed: () {
                    setState(() {
                      list[index]["title"]?.dispose();
                      list[index]["desc"]?.dispose();
                      list.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 8),

          input(
            "Judul Aturan",
            list[index]["title"]!,
            icon: Icons.rule_folder_outlined,
            hint: "Contoh: Tamu wajib lapor",
          ),

          input(
            "Deskripsi Aturan",
            list[index]["desc"]!,
            maxLines: 3,
            hint: "Tulis detail aturan di sini...",
          ),
        ],
      ),
    );
  }

  Widget buildPolicySection({
    required String title,
    required IconData icon,
    required List<Map<String, TextEditingController>> policies,
  }) {
    return sectionCard(
      title: title,
      icon: icon,
      children: [
        ...List.generate(policies.length, (index) {
          return policyCard(policies, index);
        }),

        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              setState(() {
                policies.add({
                  "title": TextEditingController(),
                  "desc": TextEditingController(),
                });
              });
            },
            icon: const Icon(Icons.add),
            label: Text(
              title == "Aturan Kost"
                  ? "Tambah Aturan Kost"
                  : "Tambah Aturan Kamar",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildImagePicker() {
    return GestureDetector(
      onTap: pickImage,
      child: Container(
        width: double.infinity,
        height: images.isEmpty ? 230 : 260,
        decoration: BoxDecoration(
          gradient: images.isEmpty
              ? LinearGradient(
                  colors: [primaryColor, const Color(0xFF18227A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: images.isEmpty ? null : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: images.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Tambah Foto Kost",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Upload maksimal 15 gambar",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(12),
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
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: primaryColor,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${images.length} Foto Dipilih",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              Text(
                                "Ketuk area ini untuk tambah foto lagi",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: images.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  images[index],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      images.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFF18227A)],
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
                    "Form Owner",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Tambah Kost Baru",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Lengkapi data kos agar mudah ditemukan penyewa.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.add_home_work_outlined,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  Widget cityDropdown() {
    return DropdownSearch<Map<String, dynamic>>(
      items: cities,
      itemAsString: (item) {
        return item['name']?.toString() ?? "-";
      },
      compareFn: (item1, item2) {
        return item1['id'] == item2['id'];
      },
      popupProps: const PopupProps.modalBottomSheet(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(hintText: "Cari kota..."),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          hintText: cities.isEmpty ? "Data kota belum tersedia" : "Pilih Kota",
          prefixIcon: Icon(Icons.location_city_outlined, color: primaryColor),
          filled: true,
          fillColor: const Color(0xFFF4F6FA),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onChanged: (value) {
        final int? cityId = value?['id'];

        setState(() {
          selectedCityId = cityId;
          places = [];
          selectedNearbyPlace = null;
          nearbyDistanceController.clear();
        });

        print("SELECTED CITY ID:");
        print(selectedCityId);

        if (cityId != null) {
          loadPlacesByCity(cityId);
        }
      },
    );
  }

  Widget nearbyPlaceInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.near_me_outlined,
                  color: primaryColor,
                  size: 18,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lokasi Terdekat",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedCityId == null
                          ? "Pilih kota terlebih dahulu"
                          : isLoadingPlaces
                          ? "Mengambil data tempat..."
                          : "Pilih tempat dari database",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (selectedNearbyPlace != null ||
                  nearbyDistanceController.text.trim().isNotEmpty)
                IconButton(
                  tooltip: "Kosongkan",
                  onPressed: () {
                    setState(() {
                      selectedNearbyPlace = null;
                      nearbyDistanceController.clear();
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          DropdownSearch<Map<String, dynamic>>(
            enabled: selectedCityId != null && !isLoadingPlaces,
            items: places,
            selectedItem: selectedNearbyPlace,
            compareFn: (item1, item2) {
              return item1['id'] == item2['id'];
            },
            itemAsString: (item) {
              final type = getPlaceType(item);
              final name = getPlaceName(item);

              if (type.isEmpty) {
                return name;
              }

              return "$type - $name";
            },
            popupProps: const PopupProps.modalBottomSheet(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(hintText: "Cari tempat..."),
              ),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                hintText: selectedCityId == null
                    ? "Pilih kota dulu"
                    : isLoadingPlaces
                    ? "Mengambil tempat..."
                    : places.isEmpty
                    ? "Tempat belum tersedia"
                    : "Pilih tempat terdekat",
                prefixIcon: isLoadingPlaces
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      )
                    : Icon(Icons.place_outlined, color: primaryColor, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.4),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {
                selectedNearbyPlace = value;
                nearbyDistanceController.clear();
              });

              print("SELECTED PLACE:");
              print(selectedNearbyPlace);
            },
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectedNearbyPlace == null
                ? const SizedBox.shrink()
                : Column(
                    key: ValueKey(selectedNearbyPlace?['id']),
                    children: [
                      const SizedBox(height: 14),

                      nearbySmallTextField(
                        label:
                            "Jarak dari ${getPlaceName(selectedNearbyPlace!)}",
                        hint: "Contoh: 2.5",
                        controller: nearbyDistanceController,
                        icon: Icons.social_distance_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        suffixText: "KM",
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Contoh: ${getPlaceName(selectedNearbyPlace!)} berjarak 3 KM dari kost",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget nearbySmallTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: primaryColor,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffixText,
            prefixIcon: Icon(icon, color: primaryColor, size: 19),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 1.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Tambah Kost",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          child: Column(
            children: [
              buildHeader(),

              buildImagePicker(),

              const SizedBox(height: 20),

              sectionCard(
                title: "Informasi Utama",
                icon: Icons.home_work_outlined,
                children: [
                  input(
                    "Nama Kost",
                    titleController,
                    icon: Icons.apartment_outlined,
                    hint: "Contoh: Kost Melati Semarang",
                  ),

                  input(
                    "Deskripsi",
                    descController,
                    maxLines: 4,
                    hint: "Jelaskan kondisi, fasilitas, dan keunggulan kost...",
                  ),

                  input(
                    "Alamat",
                    addressController,
                    maxLines: 3,
                    hint: "Masukkan alamat lengkap kost...",
                  ),

                  Text(
                    "Pilih Kota",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 8),

                  cityDropdown(),

                  const SizedBox(height: 14),

                  nearbyPlaceInput(),

                  const SizedBox(height: 16),

                  input(
                    "Max Orang",
                    maxPeopleController,
                    type: TextInputType.number,
                    icon: Icons.people_alt_outlined,
                    hint: "Contoh: 2",
                  ),
                ],
              ),

              sectionCard(
                title: "Harga Sewa",
                icon: Icons.payments_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: priceInput(
                          "Harga Malam",
                          nightlyPriceController,
                          icon: Icons.nightlight_round,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: priceInput(
                          "Harga Minggu",
                          weeklyPriceController,
                          icon: Icons.calendar_view_week_outlined,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: priceInput(
                          "Harga Bulan",
                          monthlyPriceController,
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: priceInput(
                          "Harga Tahun",
                          yearlyPriceController,
                          icon: Icons.date_range_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              sectionCard(
                title: "Fasilitas Kost",
                icon: Icons.maps_home_work_outlined,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kostFacilityOptions.map((feature) {
                      return featureChip(
                        feature: feature,
                        selected: selectedKostFacilities.contains(feature),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              selectedKostFacilities.add(feature);
                            } else {
                              selectedKostFacilities.remove(feature);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              sectionCard(
                title: "Fasilitas Kamar",
                icon: Icons.bed_outlined,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: roomFacilityOptions.map((feature) {
                      return featureChip(
                        feature: feature,
                        selected: selectedRoomFacilities.contains(feature),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              selectedRoomFacilities.add(feature);
                            } else {
                              selectedRoomFacilities.remove(feature);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              buildPolicySection(
                title: "Aturan Kost",
                icon: Icons.rule_outlined,
                policies: kostRules,
              ),

              buildPolicySection(
                title: "Aturan Kamar",
                icon: Icons.meeting_room_outlined,
                policies: roomRules,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : tambahKost,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: Colors.grey,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_alt_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          "Simpan Kost",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String formatted = _formatNumber(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(String value) {
    final buffer = StringBuffer();

    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      buffer.write(value[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}
