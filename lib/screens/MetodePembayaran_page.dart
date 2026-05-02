import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kos_model.dart';

const primaryColor = Color(0xFF2D2F8F);

class MetodePembayaranPage extends StatefulWidget {
  final KosModel kos;
  final int totalHarga;

  const MetodePembayaranPage({
    super.key,
    required this.kos,
    required this.totalHarga,
  });

  @override
  State<MetodePembayaranPage> createState() =>
      _MetodePembayaranPageState();
}

class _MetodePembayaranPageState
    extends State<MetodePembayaranPage> {
  int step = 1;
  String selectedMethod = "";

  final List<Map<String, dynamic>> methods = [
    {"name": "E-Wallet", "icon": Icons.account_balance_wallet},
    {"name": "VISA", "icon": Icons.credit_card},
    {"name": "PayPal", "icon": Icons.account_balance},
    {"name": "Master Card", "icon": Icons.credit_card},
  ];

  int fee = 5000;

  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [

            /// HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (step == 1) {
                        Navigator.pop(context);
                      } else {
                        setState(() => step--);
                      }
                    },
                    child: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Metode Pembayaran",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            Expanded(
              child: step == 1
                  ? buildStep1()
                  : step == 2
                      ? buildStep2()
                      : buildStep3(),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= STEP 1 =================
  Widget buildStep1() {
    final kos = widget.kos;

    return Column(
      children: [

        /// CARD KOS
        _kosCard(kos),

        const SizedBox(height: 30),

        /// BUTTON
        GestureDetector(
          onTap: () => setState(() => step = 2),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: primaryColor),
            ),
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text("Pilih Metode Pembayaran"),
                Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ================= STEP 2 =================
  Widget buildStep2() {
    return Column(
      children: [

        Expanded(
          child: ListView.builder(
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final m = methods[index];

              final isSelected =
                  selectedMethod == m["name"];

              return Container(
                color: isSelected
                    ? primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                child: ListTile(
                  leading: Icon(m["icon"]),
                  title: Text(m["name"]),
                  trailing: Text(
                    currency.format(widget.totalHarga),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                  ),
                  onTap: () {
                    setState(() {
                      selectedMethod = m["name"];
                    });
                  },
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize:
                  const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: selectedMethod.isEmpty
                ? null
                : () => setState(() => step = 3),
            child: const Text("Lanjutkan",
                style: TextStyle(color: Colors.white)),
          ),
        )
      ],
    );
  }

  /// ================= STEP 3 =================
  Widget buildStep3() {
    final kos = widget.kos;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [

          /// CARD KOS (WAJIB ADA DI FIGMA)
          _kosCard(kos),

          const SizedBox(height: 16),

          /// METODE TERPILIH
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: primaryColor),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedMethod),
                Text(
                  currency.format(widget.totalHarga),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// RINCIAN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: Column(
              children: [
                rowHarga(
                    "Kos", widget.totalHarga - fee),
                rowHarga("Platform Fee", fee),
                const Divider(),
                rowHarga("Total Harga",
                    widget.totalHarga,
                    bold: true),
              ],
            ),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => step = 2),
                  child: const Text("Kembali"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor),
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content:
                          Text("Pembayaran berhasil!"),
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text("Bayar Sekarang"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  /// CARD KOS
  Widget _kosCard(KosModel kos) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              kos.image,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(kos.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                Text(kos.price),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.grey),
                    Text(kos.location),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget rowHarga(String title, int value,
      {bool bold = false}) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(currency.format(value),
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}