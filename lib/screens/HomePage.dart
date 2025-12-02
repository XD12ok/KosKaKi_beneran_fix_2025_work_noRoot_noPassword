import 'package:flutter/material.dart';
import 'QrScan.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Profile
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Foto Profil Bunder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      "assets/profile.jpg",
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),


                  const SizedBox(width: 12),

                  //Jeneng
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hai, Wedus",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Wah sepertinya sedang ramai nih",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      )
                    ],
                  ),

                  const Spacer(),

                  // Icon Kanan Atas + Scan QR
                  Row(
                    children: [
                      Icon(Icons.favorite_border, size: 26),
                      const SizedBox(width: 14),
                      Icon(Icons.notifications_none, size: 26),
                      const SizedBox(width: 14),

                      // Tombol Scan QR
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QrScanPage()),
                          );
                        },
                        child: const Icon(Icons.qr_code_scanner, size: 28),
                      ),
                    ],
                  ),

                ],
              ),

              const SizedBox(height: 20),

              // Pencarian Tai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: const Color(0xFFF1F1F1),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Cari kost anda",
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bunder Bunder murah mbek kuwi lah
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _menuItem(Icons.attach_money, "Termurah"),
                  _menuItem(Icons.inventory_2_outlined, "Terlengkap"),
                  _menuItem(Icons.home_work_outlined, "Terbaru"),
                ],
              ),

              const SizedBox(height: 25),

              //Tulisan Riwayat
              const Text(
                "Riwayat Pemesanan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              _riwayatCard(),

              const SizedBox(height: 25),

              // Tulisan Rekomen
              const Text(
                "Rekomendasi Terbaik",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              _rekomendasiCard(),
            ],
          ),
        ),
      ),
    );
  }

  // Widget
  Widget _menuItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF020477),
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        )
      ],
    );
  }

  // Riwayat Pesen Gok
  Widget _riwayatCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              "assets/kost1.jpg",
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Biba’s kos mars",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 3),

                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF020477),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "14 Feb 2024 – 14 Okt 2024",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: const [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text("4.9"),
                  ],
                ),

                const SizedBox(height: 5),

                const Text(
                  "Sangat Worth It. Saya suka saya suka dan senang tralalelo...",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // Card Rekomendari kost
  Widget _rekomendasiCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              "assets/kost2.jpg",
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Rahes Residence",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.more_vert),
            ],
          ),

          const SizedBox(height: 4),

          Row(
              children: const [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text("Los Angles", style: TextStyle(color: Colors.grey)),
              ]),

          const SizedBox(height: 6),

          Row(
            children: const [
              Icon(Icons.star, color: Colors.amber, size: 16),
              SizedBox(width: 4),
              Text("9.9"),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            "Rp. 100.000.000 / bulan",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
