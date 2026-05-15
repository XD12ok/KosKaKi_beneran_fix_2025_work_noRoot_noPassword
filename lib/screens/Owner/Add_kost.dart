import 'dart:convert';
import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:koskaki/service/api_service.dart';

class AddKostPage extends StatefulWidget {
  const AddKostPage({super.key});

  @override
  State<AddKostPage> createState() =>
      _AddKostPageState();
}

class _AddKostPageState
    extends State<AddKostPage> {

  final titleController =
      TextEditingController();

  final descController =
      TextEditingController();

  final priceController =
      TextEditingController();

  final addressController =
      TextEditingController();

  final maxPeopleController =
      TextEditingController();


  List<File> images = [];


  bool isLoading = false;


  List<Map<String, dynamic>> cities =
      [];

  int? selectedCityId;


  List<String> selectedFacilities =
      [];

  final List<Map<String, dynamic>>
      facilities = [
    {
      "name": "AC",
      "icon": Icons.ac_unit,
    },
    {
      "name": "WiFi",
      "icon": Icons.wifi,
    },
    {
      "name": "Kulkas",
      "icon": Icons.kitchen,
    },
    {
      "name": "TV",
      "icon": Icons.tv,
    },
    {
      "name": "Kasur",
      "icon": Icons.bed,
    },
    {
      "name": "Lemari",
      "icon": Icons.checkroom,
    },
    {
      "name": "Parkir Motor",
      "icon": Icons.two_wheeler,
    },
    {
      "name": "Parkir Mobil",
      "icon": Icons.directions_car,
    },
    {
      "name": "Kamar Mandi Dalam",
      "icon": Icons.bathroom,
    },
  ];


  final NumberFormat rupiahFormat =
      NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    loadCities();
  }

  Future<void> loadCities() async {
    try {
      final String response =
          await rootBundle.loadString(
        'assets/json/cities.json',
        
      );
      

      final List<dynamic> data = await compute(parseJsonData, response);

      setState(() {
        cities = data
            .map(
              (e) =>
                  Map<String, dynamic>.from(
                e,
              ),
            )
            .toList();
      });

      print(cities.length);
    } catch (e) {
      print(e);
    }
  }

  String getCleanPrice() {
    return priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
  }
  
  Future<void> pickImage() async {
    final pickedImages =
        await ImagePicker().pickMultiImage();

    if (pickedImages.isEmpty) return;

    if ((images.length +
            pickedImages.length) >
        15) {
      showMessage(
        "Maksimal 15 gambar",
      );
      return;
    }

    List<File> compressedImages = [];

    for (var picked in pickedImages) {
      final compressed =
          await FlutterImageCompress
              .compressAndGetFile(
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


  Future<void> tambahKost() async {

  final int? cleanPrice = int.tryParse(
    getCleanPrice(),
  );

  if (
      titleController.text.isEmpty ||
      descController.text.isEmpty ||
      cleanPrice == null ||
      addressController.text.isEmpty ||
      maxPeopleController.text.isEmpty ||
      images.isEmpty
  ) {

    showMessage(
      "Semua field wajib diisi",
    );

    return;
  }

  setState(() {
    isLoading = true;
  });

  try {

    final token =
        await ApiService().getToken();

    final createResponse = await http.post(

      Uri.parse(
        "${ApiService.baseUrl}/properties",
      ),

      headers: {

        'Authorization':
            'Bearer $token',

        'Accept':
            'application/json',

      },

      body: {

        'title':
            titleController.text,

        'description':
            descController.text,

        'price_perMonth':
            cleanPrice.toString(),

        'address':
            addressController.text,

        'city_id':
            '1',

        'max_people':
            maxPeopleController.text,

        'status':
            'active',

      },
    );

    print("CREATE STATUS:");
    print(createResponse.statusCode);

    print("CREATE BODY:");
    print(createResponse.body);

    if (
        createResponse.statusCode != 200 &&
        createResponse.statusCode != 201
    ) {

      showMessage(
        "Gagal membuat kost",
      );

      setState(() {
        isLoading = false;
      });

      return;
    }

    final decoded =
        jsonDecode(createResponse.body);

    final propertyId =

        decoded['data']?['id']
            ?.toString()

        ??

        decoded['id']
            ?.toString();

    print("PROPERTY ID:");
    print(propertyId);

    if (propertyId == null) {

      showMessage(
        "Property ID tidak ditemukan",
      );

      setState(() {
        isLoading = false;
      });

      return;
    }

    var request =
        http.MultipartRequest(

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

    request.fields['property_id'] =
        propertyId;

    final uploadResponse =
        await request.send();

    final uploadBody =
        await uploadResponse.stream
            .bytesToString();

    print("UPLOAD STATUS:");
    print(uploadResponse.statusCode);

    print("UPLOAD BODY:");
    print(uploadBody);

    if (
        uploadResponse.statusCode == 200 ||
        uploadResponse.statusCode == 201
    ) {

      showMessage(
        "Kost berhasil ditambahkan",
        success: true,
      );

      Navigator.pop(context);

    } else {

      showMessage(
        "Property berhasil dibuat tapi upload gambar gagal",
      );
    }

  } catch (e) {

    print(e);

    showMessage(
      "Error: $e",
    );

  }

  setState(() {
    isLoading = false;
  });
}


  void showMessage(
    String msg, {
    bool success = false,
  }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            success
                ? Colors.green
                : Colors.red,
      ),
    );
  }

  Widget input(
    String label,
    TextEditingController controller, {
    TextInputType type =
        TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
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

        const SizedBox(height: 16),
      ],
    );
  }

  Widget inputHarga() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          "Harga / Bulan",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        TextField(
          controller: priceController,

          keyboardType:
              TextInputType.number,

          inputFormatters: [
            TextInputFormatter.withFunction(
              (oldValue, newValue) {
                String text = newValue.text
                    .replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );

                if (text.isEmpty) {
                  return const TextEditingValue(
                    text: '',
                  );
                }

                final number =
                    int.parse(text);

                final newText =
                    rupiahFormat
                        .format(number);

                return TextEditingValue(
                  text: newText,

                  selection:
                      TextSelection.collapsed(
                    offset:
                        newText.length,
                  ),
                );
              },
            ),
          ],

          decoration: InputDecoration(
            hintText: "Rp 0",

            filled: true,

            fillColor: Colors.grey[100],

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),

              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: const Text("Tambah Kost"),
        backgroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            GestureDetector(
              onTap: pickImage,

              child: Container(
                height: 230,

                decoration: BoxDecoration(
                  color: Colors.grey[200],

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child: images.isEmpty
                    ? Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                        children: const [
                          Icon(
                            Icons.image,
                            size: 40,
                          ),

                          SizedBox(height: 10),

                          Text(
                            "Tambah Foto Kost",
                          ),

                          SizedBox(height: 5),

                          Text(
                            "Maksimal 15 gambar",
                          ),
                        ],
                      )
                    : GridView.builder(
                        padding:
                            const EdgeInsets.all(
                          10,
                        ),

                        itemCount: images.length,

                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),

                        itemBuilder:
                            (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),

                                child: Image.file(
                                  images[index],
                                  fit: BoxFit.cover,
                                  width:
                                      double.infinity,
                                  height:
                                      double.infinity,
                                ),
                              ),

                              if (index == 0)
                                Positioned(
                                  top: 5,
                                  left: 5,

                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal:
                                          8,
                                      vertical: 4,
                                    ),

                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.black,

                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                    ),

                                    child:
                                        const Text(
                                      "Thumbnail",
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize:
                                            10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding:
                  const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
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

                  inputHarga(),

                  input(
                    "Alamat",
                    addressController,
                    maxLines: 3,
                  ),

                  const Text(
                    "Pilih Kota",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  DropdownSearch<
                      Map<String, dynamic>>(
                    items: cities,

                    itemAsString: (item) =>
                        item['name']
                            .toString(),

                    popupProps:
                        PopupProps
                            .modalBottomSheet(
                      showSearchBox: true,

                      searchFieldProps:
                          TextFieldProps(
                        decoration:
                            InputDecoration(
                          hintText:
                              "Cari kota...",

                          prefixIcon:
                              const Icon(
                            Icons.search,
                          ),

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
                    ),

                    dropdownDecoratorProps:
                        DropDownDecoratorProps(
                      dropdownSearchDecoration:
                          InputDecoration(
                        hintText:
                            "Pilih Kota",

                        prefixIcon:
                            const Icon(
                          Icons.location_city,
                        ),

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
                    type:
                        TextInputType.number,
                  ),

                  const Text(
                    "Fasilitas",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,

                    children:
                        facilities.map((
                      facility,
                    ) {
                      final isSelected =
                          selectedFacilities
                              .contains(
                        facility['name'],
                      );

                      return FilterChip(
                        selected: isSelected,

                        avatar: Icon(
                          facility['icon'],
                          size: 18,
                        ),

                        label: Text(
                          facility['name'],
                        ),

                        onSelected: (
                          value,
                        ) {
                          setState(() {
                            if (value) {
                              selectedFacilities
                                  .add(
                                facility[
                                    'name'],
                              );
                            } else {
                              selectedFacilities
                                  .remove(
                                facility[
                                    'name'],
                              );
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),


            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed:
                    isLoading
                        ? null
                        : tambahKost,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF0A0E50,
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),

                child: isLoading
                    ? const CircularProgressIndicator(
                        color:
                            Colors.white,
                      )
                    : const Text(
                        "Simpan Kost",
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<dynamic> parseJsonData(String response) {
  return jsonDecode(response);
}
