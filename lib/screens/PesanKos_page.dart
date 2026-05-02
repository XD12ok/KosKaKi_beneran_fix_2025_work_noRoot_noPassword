import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kos_model.dart';
import 'MetodePembayaran_page.dart'; 

const primaryColor = Color(0xFF2D2F8F);

class PesanKosPage extends StatefulWidget {
  final KosModel kos;

  const PesanKosPage({super.key, required this.kos});

  @override
  State<PesanKosPage> createState() => _PesanKosPageState();
}

class _PesanKosPageState extends State<PesanKosPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  DateTime selectedDate = DateTime(2026, 1, 1);
  int duration = 1;

  final currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// DROPDOWN
  final LayerLink layerLink = LayerLink();
  OverlayEntry? overlayEntry;

  double dropdownWidth = 0;

  void toggleDropdown() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    dropdownWidth = renderBox.size.width - 32;

    if (overlayEntry == null) {
      overlayEntry = _createOverlay();
      Overlay.of(context).insert(overlayEntry!);
    } else {
      removeDropdown();
    }
  }

  void removeDropdown() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    return OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: removeDropdown,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: layerLink,
                  offset: const Offset(0, 55),
                  showWhenUnlinked: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: dropdownWidth,
                        child: Container(
                          constraints:
                              const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [1, 3, 6, 12].map((e) {
                              return ListTile(
                                title: Text("$e Bulan"),
                                onTap: () {
                                  setState(() => duration = e);
                                  removeDropdown();
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// HARGA
  int get hargaPerBulan {
    final price = widget.kos.price.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(price.substring(0, price.length ~/ 2)) ?? 1000000;
  }

  int get totalHarga => (hargaPerBulan * duration) + 5000;

  @override
  Widget build(BuildContext context) {
    final kos = widget.kos;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Image.asset(
                  kos.image,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kos.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(kos.location),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(kos.price,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),

                    const SizedBox(height: 20),

                    const Text("Informasi Kontak",
                        style: TextStyle(fontWeight: FontWeight.bold)),

                    const SizedBox(height: 10),

                    _inputField("Nama", nameController),
                    const SizedBox(height: 10),
                    _inputField("Nomor HP", phoneController),

                    const SizedBox(height: 16),

                    const Text("Tanggal Pemesanan",
                        style: TextStyle(fontWeight: FontWeight.bold)),

                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2026),
                          lastDate: DateTime(2035),
                        );

                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: _box(
                          "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                    ),

                    const SizedBox(height: 10),

                    CompositedTransformTarget(
                      link: layerLink,
                      child: GestureDetector(
                        onTap: toggleDropdown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: primaryColor),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text("$duration Bulan"),
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _row("Kost $duration Bulan",
                              currency.format(hargaPerBulan * duration)),
                          _row("Platform Fee", "Rp 5.000"),
                          const Divider(),
                          _row("Total Harga",
                              currency.format(totalHarga),
                              bold: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 🔥 FIX DI SINI
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MetodePembayaranPage(
                                kos: kos,
                                totalHarga: totalHarga,
                              ),
                            ),
                          );
                        },
                        child: const Text("Konfirmasi Pemesanan",
                            style: TextStyle(
                                color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _box(String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text),
          const Icon(Icons.calendar_today, size: 18),
        ],
      ),
    );
  }

  Widget _row(String left, String right, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(left),
          Text(right,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}