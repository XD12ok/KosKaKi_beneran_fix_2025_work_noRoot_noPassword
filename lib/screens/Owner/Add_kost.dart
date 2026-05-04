import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:koskaki/service/api_service.dart';

class AddKostPage extends StatefulWidget {
  const AddKostPage({super.key});

  @override
  State<AddKostPage> createState() => _AddKostPageState();
}

class _AddKostPageState extends State<AddKostPage> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final addressController = TextEditingController();
  final cityIdController = TextEditingController();
  final maxPeopleController = TextEditingController();

  File? image;
  bool isLoading = false;


  final NumberFormat rupiahFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String formatRupiah(String value) {
    if (value.isEmpty) return "";
    final number = int.parse(value);
    return rupiahFormat.format(number);
  }

  String getCleanPrice() {
    return priceController.text
        .replaceAll("Rp", "")
        .replaceAll(".", "")
        .trim();
  }


  Future pickImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  Future<void> tambahKost() async {
    final cleanPrice = getCleanPrice();

    if (titleController.text.isEmpty ||
        descController.text.isEmpty ||
        cleanPrice.isEmpty ||
        addressController.text.isEmpty ||
        cityIdController.text.isEmpty ||
        maxPeopleController.text.isEmpty) {
      showMessage("Semua field wajib diisi");
      return;
    }

    setState(() => isLoading = true);

    try {
      final token = await ApiService().getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiService.baseUrl}/properties"),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = titleController.text;
      request.fields['description'] = descController.text;
      request.fields['price_perMonth'] = cleanPrice;
      request.fields['address'] = addressController.text;
      request.fields['city_id'] = cityIdController.text;
      request.fields['max_people'] = maxPeopleController.text;
      request.fields['status'] = "active";

      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', image!.path),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        showMessage("Kost berhasil ditambahkan", success: true);
        Navigator.pop(context);
      } else {
        showMessage("Gagal menambahkan kost");
      }
    } catch (e) {
      showMessage("Error: $e");
    }

    setState(() => isLoading = false);
  }

  void showMessage(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget input(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Harga / Bulan",
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              String text =
                  newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

              if (text.isEmpty) {
                return const TextEditingValue(text: '');
              }

              final number = int.parse(text);
              final newText = rupiahFormat.format(number);

              return TextEditingValue(
                text: newText,
                selection:
                    TextSelection.collapsed(offset: newText.length),
              );
            })
          ],
          decoration: InputDecoration(
            hintText: "Rp 0",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Tambah Kost"),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // IMAGE
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.image, size: 40),
                          SizedBox(height: 8),
                          Text("Tambah Foto Kost"),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // FORM
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  input("Nama Kost", titleController),
                  input("Deskripsi", descController),
                  inputHarga(),
                  input("Alamat", addressController),
                  input("City ID", cityIdController,
                      type: TextInputType.number),
                  input("Max Orang", maxPeopleController,
                      type: TextInputType.number),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : tambahKost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A0E50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text(
                        "Simpan Kost",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
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