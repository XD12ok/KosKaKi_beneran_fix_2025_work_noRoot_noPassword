import 'package:koskaki/models/kos_model.dart';

List<KosModel> dummyKos = [
  // 1. Rahes Residence
  KosModel(
    name: "Rahes Residence",
    location: "Klipang, Semarang",
    price: "Rp. 5.000.000 - 10.000.000",

    image: "assets/cover2.png",

    images: [
    "assets/carousel1.png",
    "assets/carousel2.png",
    "assets/carousel3.png",
    "assets/carousel4.png",
    "assets/carousel5.png",
    "assets/carousel6.png",
  ],

    availableRooms: 3,
    facilities: ["TV", "Lemari", "Tempat Tidur", "AC"],
    rules: [
      "Wajib menjaga kebersihan",
      "Tidak boleh membawa hewan",
      "Tidak merokok di kamar",
      "Wajib makan di area yang disediakan",
      "Tidak boleh membuat keributan setelah pukul 22.00",
      "Wajib mematuhi jam malam pukul 23.00",
    ],
    description:
        "Kos nyaman dengan fasilitas lengkap dan lingkungan aman enak juicy luicy mahalini rizky febian hindia bisa bayar online, qris, ewallet.",
    address: "Jl. Kendeng IV No. 23, Bendan Ngisor, Kec. Gajahmungkur, Kota Semarang, Jawa Tengah 50233",
  ),

  KosModel(
    name: "Kos Arsa IT",
    location: "Semarang",
    price: "Rp. 1.000.000 - 4.500.000",

    image: "assets/cover3.png",

    images: [
      "assets/kos/kos3/carousel1.png",
      "assets/kos/kos3/carousel2.png",
      "assets/kos/kos3/carousel3.png",
    ],
    availableRooms: 4,
    facilities: ["TV", "Lemari", "Tempat Tidur", "AC"],
    rules: [
      "Wajib menjaga kebersihan",
      "Tidak merokok",
      "Tidak boleh membawa hewan",
      "Tidak boleh membuat keributan setelah pukul 22.00",
      "Wajib mematuhi jam malam pukul 23.00",
      "Wajib makan di area yang disediakan",
    ],
    description:
        "Hunian modern dengan fasilitas lengkap dan nyaman untuk mahasiswa di Semarang.",
    address: "Jl. Kendeng IV No. 23, Bendan Ngisor, Kec. Gajahmungkur, Kota Semarang, Jawa Tengah 50233",
  ),

  // 3. Freya Kos
  KosModel(
    name: "Freya Kos",
    location: "Medoho, Semarang",
    price: "Rp. 1.000.000 - 2.500.000",

    image: "assets/cover4.png",

      images: [
        "assets/kos/kos4/carousel1.png",
        "assets/kos/kos4/carousel2.png",
        "assets/kos/kos4/carousel3.png",
        "assets/kos/kos4/carousel4.png",
      ],

    availableRooms: 5,
    facilities: ["TV", "Lemari", "Tempat Tidur"],
    rules: [
      "Tidak boleh membawa hewan",
      "Tidak merokok",
      "Wajib menjaga kebersihan",
      "Tidak boleh membuat keributan setelah pukul 22.00",
      "Wajib mematuhi jam malam pukul 23.00",
      "Wajib makan di area yang disediakan",
    ],
    description:
        "Kos murah dan nyaman untuk mahasiswa di Semarang yang menyediakan fasilitas lengkap dan lingkungan aman.",
    address: "Jl. Medoho Raya, Semarang",
  ),

  // 4. Daisy Residence
  KosModel(
    name: "Daisy Residence",
    location: "Semarang City",
    price: "Rp. 3.000.000 - 5.500.000",

    image: "assets/cover5.png",

      images: [
          "assets/kos/kos5/carousel1.png",
          "assets/kos/kos5/carousel2.png",
          "assets/kos/kos5/carousel3.png",
          "assets/kos/kos5/carousel4.png",
        ],

    availableRooms: 2,
    facilities: ["AC", "Tempat Tidur"],
    rules: [
      "Wajib menjaga kebersihan",
      "Tidak merokok",
      "Tidak boleh membawa hewan",
      "Tidak boleh membuat keributan setelah pukul 22.00",
      "Wajib mematuhi jam malam pukul 23.00",
    ],
    description:
        "Lingkungan aman dan bersih. Fasilitas lengkap untuk kenyamanan mahasiswa di Semarang. Kos nyaman dengan fasilitas lengkap dan lingkungan aman.",
    address: "Jl. Pandanaran, Semarang",
  ),

  // 5. Berkah Kos
  KosModel(
    name: "Berkah Kos",
    location: "Semarang",
    price: "Rp. 750.000 - 1.250.000",

    image: "assets/cover5.png",

      images: [
        "assets/kos/kos6/carousel1.png",
        "assets/kos/kos6/carousel2.png",
        "assets/kos/kos6/carousel3.png",
        "assets/kos/kos6/carousel4.png",
      ],

    availableRooms: 3,
    facilities: ["TV", "Lemari", "Tempat Tidur", "AC"],
    rules: [
      "Wajib menjaga kebersihan",
      "Tidak merokok",
      "Tidak boleh membawa hewan",
      "Tidak boleh membuat keributan setelah pukul 22.00",
      "Wajib mematuhi jam malam pukul 23.00",
      "Wajib makan di area yang disediakan",
    ],
    description:
        "Kos nyaman dengan fasilitas lengkap dan lingkungan aman untuk mahasiswa di Semarang.",
    address: "Jl. Pandanaran, Semarang",
    isHidden: true,
  )
];
