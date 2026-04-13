import 'package:flutter/material.dart';

class AcceptKost extends StatelessWidget {
  const AcceptKost({super.key});

  @override
  Widget build(BuildContext context) {
    // 👉 tanggal mulai kos (contoh: tanggal 2)
    final int startDate = 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // 🔙 kembali
                    },
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Pengajuan Kos",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 6,
                            color: Colors.black12,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              "https://picsum.photos/120",
                              width: 100,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "Kost Arsa IT",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "Putri",
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Semarang Selatan",
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Rp. 1.000.000",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    sectionBox(
                      title: "Informasi Penyewa",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Nama Penyewa"),
                          Text("GARNETA KARIN",
                              style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 10),
                          Text("Nomor Hp"),
                          Text("08XX XXXX XXXX",
                              style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 10),
                          Text("Jenis Kelamin"),
                          Text("Perempuan",
                              style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 10),
                          Text("Pekerjaan"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    sectionBox(
                      title: "Tanggal Mulai Ngekos",
                      child: Column(
                        children: [
                          const Text("Januari 2025"),
                          const SizedBox(height: 10),

                          GridView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount: 31,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                            ),
                            itemBuilder: (context, index) {
                              int day = index + 1;

                              bool isStartDate = day == startDate;

                              return Container(
                                decoration: BoxDecoration(
                                  color: isStartDate
                                      ? const Color(0xFF0A0E50)
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "$day",
                                  style: TextStyle(
                                    color: isStartDate
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: isStartDate
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Rp1.000.000",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A0E50),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Terima Sewa",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  static Widget sectionBox({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child
        ],
      ),
    );
  }
}