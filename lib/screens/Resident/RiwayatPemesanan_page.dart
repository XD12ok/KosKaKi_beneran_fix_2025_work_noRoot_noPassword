import 'package:flutter/material.dart';
import 'package:koskaki/data/RatingKos.dart';

const primaryColor = Color(0xFF2D2F8F);

class RiwayatPemesananPage extends StatelessWidget {
  const RiwayatPemesananPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [

            /// ================= HEADER =================
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Riwayat Pemesanan Kos",
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

            /// ================= LIST =================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [

                  HistoryItem(
                    image: "assets/cover1.png",
                    name: "Kos Mentari, Semarang",
                    date: "1 Jan 2022 - 1 Jan 2023",
                    location: "Mentari Raya",
                  ),

                  HistoryItem(
                    image: "assets/cover2.png",
                    name: "L Residence, Jakarta",
                    date: "20 Mar 2022 - 20 Mar 2023",
                    location: "Jakarta, Jakarta Utara",
                  ),

                  HistoryItem(
                    image: "assets/cover3.png",
                    name: "GJLs Residence, Surabaya",
                    date: "20 Mar 2022 - 20 Mar 2023",
                    location: "Surabaya, Jawa Timur",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryItem extends StatefulWidget {
  final String image;
  final String name;
  final String date;
  final String location;

  const HistoryItem({
    super.key,
    required this.image,
    required this.name,
    required this.date,
    required this.location,
  });

  @override
  State<HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<HistoryItem> {
  bool sudahRating = false;

  void showRatingDialog() {
    int selected = 0;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Beri Rating"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setStateDialog(() {
                        selected = index + 1;
                      });
                    },
                    child: Icon(
                      index < selected
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 30,
                    ),
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              onPressed: selected == 0
                  ? null
                  : () {
                      RatingKos.addRating(widget.name, selected);

                      setState(() {
                        sudahRating = true;
                      });

                      Navigator.pop(context);
                    },
              child: const Text("Kirim",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [

          /// IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              widget.image,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 10),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  widget.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 6),

                /// DATE
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      widget.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                /// LOCATION
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      widget.location,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                /// STATUS
                Row(
                  children: const [
                    Icon(Icons.check_circle,
                        size: 14, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      "Selesai",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                /// ULASAN / RATING
                GestureDetector(
                  onTap: sudahRating ? null : showRatingDialog,
                  child: Row(
                    children: [
                      Icon(
                        sudahRating
                            ? Icons.star
                            : Icons.chat_bubble_outline,
                        size: 14,
                        color: sudahRating
                            ? Colors.amber
                            : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sudahRating
                            ? "Sudah memberi rating"
                            : "Tulis Ulasan",
                        style: TextStyle(
                          fontSize: 11,
                          color: sudahRating
                              ? Colors.amber
                              : Colors.blue,
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
}