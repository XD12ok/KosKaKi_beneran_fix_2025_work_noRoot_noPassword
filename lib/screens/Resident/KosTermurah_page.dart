import 'package:flutter/material.dart';
import 'package:koskaki/data/dummy_kos.dart';
import 'package:koskaki/models/kos_model.dart';
import 'package:koskaki/data/RatingKos.dart';
import 'package:koskaki/screens/Resident/DetailKos_page.dart';

const primaryColor = Color(0xFF2D2F8F);

double extractPrice(String price) {
  final cleaned = price
      .replaceAll("Rp.", "")
      .replaceAll(".", "")
      .split("-")
      .first
      .trim();

  return double.tryParse(cleaned) ?? 0;
}

class KosTermurahPage extends StatelessWidget {
  const KosTermurahPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<KosModel> filtered = dummyKos
        .where((kos) => extractPrice(kos.price) <= 5000000)
        .toList();

    filtered.sort(
      (a, b) => extractPrice(a.price).compareTo(extractPrice(b.price)),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            /// HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Kos Termurah",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            /// LIST
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final kos = filtered[index];

                  double rating = RatingKos.getAverage(kos.name);
                  int total = RatingKos.getTotal(kos.name);

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailKosPage(kos: kos),
                        ),
                      );

                      (context as Element).markNeedsBuild();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          /// NAMA
                          Text(
                            kos.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 8),

                          /// IMAGE
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              kos.image,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(height: 10),

                          /// HARGA
                          Text(
                            "${kos.price} /Perbulan",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                kos.location,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                rating == 0
                                    ? "Belum ada rating"
                                    : "${rating.toStringAsFixed(1)} ($total)",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}