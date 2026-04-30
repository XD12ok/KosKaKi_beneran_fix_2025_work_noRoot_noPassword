import 'package:flutter/material.dart';
import '../data/dummy_kos.dart';
import '../models/kos_model.dart';
import '../data/RatingKos.dart';
import 'DetailKos_page.dart';

const primaryColor = Color(0xFF2D2F8F);

class KosTerbaruPage extends StatelessWidget {
  const KosTerbaruPage({super.key});

  @override
  Widget build(BuildContext context) {

    List<KosModel> terbaru = List.from(dummyKos.reversed);

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
                        "Kos Terbaru",
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

            Expanded(
              child: ListView.builder(
                itemCount: terbaru.length,
                itemBuilder: (context, index) {
                  final kos = terbaru[index];

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
                    child: _cardKos(kos, rating, total),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardKos(KosModel kos, double rating, int total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(kos.name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

          const SizedBox(height: 8),

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

          Text("${kos.price} /Perbulan",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(kos.location,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
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
    );
  }
}