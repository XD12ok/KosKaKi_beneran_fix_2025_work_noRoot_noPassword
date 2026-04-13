import 'package:flutter/material.dart';

class KostPage extends StatelessWidget {
  const KostPage({super.key}); // Tambahkan const di sini

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> kosList = [
      {
        'nama': 'Kos Mambu',
        'alamat': 'Jl. Melati No. 10, Kec. Lowokwaru',
        'harga': 'Rp 1.200.000/bulan',
        'status': 'Tersedia',
      },
      {
        'nama': 'Kos Apel Hijau',
        'alamat': 'Jl. Anggrek No. 5, Kec. Klojen',
        'harga': 'Rp 1.000.000/bulan',
        'status': 'Penuh',
      },
      {
        'nama': 'Kos Lulus Keren',
        'alamat': 'Jl. Flamboyan Raya No. 22',
        'harga': 'Rp 1.500.000/bulan',
        'status': 'Tersedia',
      },
    ];

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kosList.length,
        itemBuilder: (context, index) {
          final kos = kosList[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.house, size: 32, color: Color(0xFF0A0E50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kos['nama']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kos['alamat']!,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        kos['harga']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0E50),
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kos['status'] == 'Tersedia'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          kos['status']!,
                          style: TextStyle(
                            color: kos['status'] == 'Tersedia' ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fitur tambah kos segera hadir')),
          );
        },
        backgroundColor: const Color(0xFF0A0E50),
        child: const Icon(Icons.add),
      ),
    );
  }
}