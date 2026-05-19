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

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  List<File> images = [];

  bool isLoading = false;

  List<Map<String, dynamic>> cities = [];

  int? selectedCityId;

  List<String> selectedFeatures = [];

  final List<String> featureOptions = [
    "WiFi",
    "CCTV",
    "Parkir Motor",
    "Parkir Mobil",
    "Dapur Bersama",
    "Laundry",
    "Ruang Tamu",
    "Keamanan 24 Jam",
    "Mushola",
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

    super.dispose();
  }

  // =========================
  // LOAD CITIES
  // =========================

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

  // =========================
  // CLEAN PRICE
  // =========================

  String cleanPrice(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
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

  // =========================
  // CREATE KOST
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

      final Map<String, String> body = {
        'title': titleController.text,
        'description': descController.text,
        'address': addressController.text,
        'city_id': selectedCityId.toString(),
        'max_people': maxPeopleController.text,
        'status': 'active',
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

        setState(() {
          isLoading = false;
        });

        return;
      }

      Map<String, dynamic> decoded = jsonDecode(createResponse.body);

      final String propertyId = decoded['data']['id'].toString();

      print("PROPERTY ID:");
      print(propertyId);

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

      print("UPLOAD STATUS:");
      print(uploadResponse.statusCode);

      for (var feature in selectedFeatures) {
        await http.post(
          Uri.parse("${ApiService.baseUrl}/properties/$propertyId/features"),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: {"name": feature},
        );
      }

      showMessage("Kost berhasil dibuat", success: true);

      Navigator.pop(context);
    } catch (e) {
      print(e);
      showMessage("Error: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void showMessage(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // =========================
  // NORMAL INPUT
  // =========================

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

  // =========================
  // PRICE INPUT
  // =========================

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
        setState(() {
          selectedCityId = value?['id'];
        });

        print("SELECTED CITY ID:");
        print(selectedCityId);
      },
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
                title: "Fasilitas",
                icon: Icons.widgets_outlined,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,

                    children: featureOptions.map((feature) {
                      return featureChip(
                        feature: feature,
                        selected: selectedFeatures.contains(feature),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              selectedFeatures.add(feature);
                            } else {
                              selectedFeatures.remove(feature);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
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

// =========================
// FORMATTER RUPIAH
// =========================

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

List<dynamic> parseJsonData(String response) {
  return jsonDecode(response);
}
