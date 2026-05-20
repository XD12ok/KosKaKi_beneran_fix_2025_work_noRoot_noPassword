import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/LiveChatOwner.dart';
import 'package:koskaki/service/api_service.dart';

class DetailKosPage extends StatefulWidget {
  final Map<String, dynamic> kos;

  const DetailKosPage({super.key, required this.kos});

  @override
  State<DetailKosPage> createState() => _DetailKosPageState();
}

class _DetailKosPageState extends State<DetailKosPage> {
  bool isLoading = true;

  Map<String, dynamic>? detail;

  List<dynamic> images = [];

  int currentImageIndex = 0;

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  Future<void> getDetail() async {
    try {
      final token = await ApiService().getToken();

      final id = widget.kos['id'];

      if (id == null) {
        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(widget.kos);
          images = extractImages(widget.kos).take(15).toList();
          currentImageIndex = 0;
          isLoading = false;
        });

        return;
      }

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties/$id"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint("DETAIL RESIDENT STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("DETAIL RESIDENT BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final data = decoded is Map<String, dynamic>
            ? decoded['data'] ?? decoded
            : widget.kos;

        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(data);
          images = extractImages(data).take(15).toList();
          currentImageIndex = 0;
          isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(widget.kos);
          images = extractImages(widget.kos).take(15).toList();
          currentImageIndex = 0;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("GET DETAIL RESIDENT ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        detail = Map<String, dynamic>.from(widget.kos);
        images = extractImages(widget.kos).take(15).toList();
        currentImageIndex = 0;
        isLoading = false;
      });
    }
  }

  List<dynamic> extractImages(dynamic data) {
    final List<dynamic> result = [];

    if (data is! Map) return result;

    final mainImage = data['main_image'];

    if (mainImage != null && mainImage.toString() != "null") {
      result.add(mainImage);
    }

    final listImages = data['images'];

    if (listImages is List) {
      for (final img in listImages) {
        if (img != null && img.toString() != "null") {
          result.add(img);
        }
      }
    }

    return result.toSet().toList();
  }

  String formatRupiah(dynamic value) {
    if (value == null) return "";

    final number = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

    if (number.isEmpty) return "";

    final buffer = StringBuffer();

    int count = 0;

    for (int i = number.length - 1; i >= 0; i--) {
      buffer.write(number[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  bool hasValue(dynamic value) {
    return value != null &&
        value.toString().trim().isNotEmpty &&
        value.toString() != "null";
  }

  List<_PriceItem> getPriceItems() {
    final d = detail ?? widget.kos;

    final night = d['price_perNight'] ?? d['price_per_night'];
    final week = d['price_perWeek'] ?? d['price_per_week'];
    final month = d['price_perMonth'] ?? d['price_per_month'];
    final year = d['price_perYear'] ?? d['price_per_year'];

    final List<_PriceItem> prices = [];

    if (hasValue(month)) {
      prices.add(
        _PriceItem(
          title: "Bulanan",
          price: "Rp ${formatRupiah(month)}",
          subtitle: "per bulan",
          icon: Icons.calendar_month_rounded,
        ),
      );
    }

    if (hasValue(year)) {
      prices.add(
        _PriceItem(
          title: "Tahunan",
          price: "Rp ${formatRupiah(year)}",
          subtitle: "per tahun",
          icon: Icons.event_available_rounded,
        ),
      );
    }

    if (hasValue(week)) {
      prices.add(
        _PriceItem(
          title: "Mingguan",
          price: "Rp ${formatRupiah(week)}",
          subtitle: "per minggu",
          icon: Icons.date_range_rounded,
        ),
      );
    }

    if (hasValue(night)) {
      prices.add(
        _PriceItem(
          title: "Harian",
          price: "Rp ${formatRupiah(night)}",
          subtitle: "per malam",
          icon: Icons.night_shelter_rounded,
        ),
      );
    }

    return prices;
  }

  String getMainPrice() {
    final prices = getPriceItems();

    if (prices.isEmpty) {
      return "Harga belum ditambahkan";
    }

    return "${prices.first.price} ${prices.first.subtitle}";
  }

  String fixUrl(dynamic img) {
    String url = "";

    final baseUrlWithoutApi = ApiService.baseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );

    if (img is String) {
      url = img;
    } else if (img is Map) {
      url =
          img['url']?.toString() ??
          img['image']?.toString() ??
          img['path']?.toString() ??
          img['image_path']?.toString() ??
          img['file']?.toString() ??
          "";
    }

    if (url.isEmpty || url == "null") return "";

    if (url.startsWith("http")) return url;

    if (url.startsWith("/storage")) {
      return "$baseUrlWithoutApi$url";
    }

    if (url.startsWith("storage")) {
      return "$baseUrlWithoutApi/$url";
    }

    return "$baseUrlWithoutApi/storage/$url";
  }

  List<String> parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) {
            if (e is Map) {
              return e['name']?.toString() ??
                  e['title']?.toString() ??
                  e['label']?.toString() ??
                  "";
            }

            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (value is String) {
      if (value.trim().isEmpty || value == "null") return [];

      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return decoded
              .map((e) {
                if (e is Map) {
                  return e['name']?.toString() ??
                      e['title']?.toString() ??
                      e['label']?.toString() ??
                      "";
                }

                return e.toString();
              })
              .where((e) => e.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}

      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> parsePolicyList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map<Map<String, dynamic>>((e) {
        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }

        return {"title": "Aturan", "description": e.toString()};
      }).toList();
    }

    if (value is String && value.trim().isNotEmpty && value != "null") {
      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            }

            return {"title": "Aturan", "description": e.toString()};
          }).toList();
        }
      } catch (_) {}

      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map<Map<String, dynamic>>((e) {
            return {"title": "Aturan", "description": e};
          })
          .toList();
    }

    return [];
  }

  String normalizeText(String value) {
    if (value.trim().isEmpty) return "-";

    return value
        .replaceAll("_", " ")
        .split(" ")
        .where((e) => e.isNotEmpty)
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(" ");
  }

  double getRatingAverage(dynamic value) {
    return double.tryParse(value?.toString() ?? "0") ?? 0;
  }

  int getRatingCount(dynamic value) {
    return int.tryParse(value?.toString() ?? "0") ?? 0;
  }

  void showRentSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Fitur mulai menyewa untuk ${detail?['title'] ?? 'kos ini'} segera tersedia.",
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
      ),
    );
  }

  Future<void> goToChatOwner() async {
    final d = detail ?? widget.kos;

    final owner = d['owner'];

    final ownerName = owner is Map
        ? owner['name']?.toString() ?? "Pemilik Kos"
        : d['owner_name']?.toString() ?? "Pemilik Kos";

    final ownerId = owner is Map
        ? int.tryParse(owner['id']?.toString() ?? "")
        : int.tryParse(d['owner_id']?.toString() ?? "");

    final propertyId = int.tryParse(
      d['id']?.toString() ?? widget.kos['id']?.toString() ?? "",
    );

    if (ownerId == null || ownerId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("ID pemilik kos tidak ditemukan."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryColor,
        ),
      );

      return;
    }

    if (propertyId == null || propertyId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("ID kos tidak ditemukan."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryColor,
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Membuka chat dengan pemilik..."),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );

    final conversationId = await ApiService().createOrGetConversationId(
      ownerId: ownerId,
      placePropertyId: propertyId,
    );

    if (!mounted) return;

    if (conversationId == null || conversationId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Gagal membuat conversation. Cek log CREATE CONVERSATION BODY.",
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryColor,
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Livechatowner(username: ownerName, conversationId: conversationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = detail ?? {};

    final title =
        d['title']?.toString() ?? d['name']?.toString() ?? "Detail Kos";

    final description = d['description']?.toString() ?? "";

    final address = d['address']?.toString() ?? "";

    final maxPeople = d['max_people']?.toString() ?? "";

    final status = d['status']?.toString() ?? "active";

    final city = d['city'];

    final cityName = city is Map
        ? city['name']?.toString() ?? ""
        : d['city_name']?.toString() ?? "";

    final ratingAvg = getRatingAverage(d['rating_avg']);

    final ratingCount = getRatingCount(d['rating_count']);

    final kostFacilities = parseStringList(
      d['kost_facilities'] ??
          d['property_features'] ??
          d['features'] ??
          d['feature'] ??
          d['facilities'] ??
          d['facility'],
    );

    final roomFacilities = parseStringList(
      d['room_facilities'] ?? d['place_features'],
    );

    final kostRules = parsePolicyList(
      d['kost_rules'] ??
          d['property_policies'] ??
          d['policies'] ??
          d['rules'] ??
          d['rule'],
    );

    final roomRules = parsePolicyList(d['room_rules'] ?? d['place_policies']);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Detail Kos",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: detail == null ? null : buildBottomActionBar(),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : detail == null
          ? buildErrorState()
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: getDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildImageHeader(title: title, status: status),
                    const SizedBox(height: 20),

                    priceSection(),

                    infoSummarySection(
                      title: title,
                      cityName: cityName,
                      address: address,
                      maxPeople: maxPeople,
                      status: status,
                      ratingAvg: ratingAvg,
                      ratingCount: ratingCount,
                    ),

                    descriptionSection(description),

                    facilitySection(
                      title: "Fasilitas Kos",
                      icon: Icons.maps_home_work_outlined,
                      items: kostFacilities,
                    ),

                    facilitySection(
                      title: "Fasilitas Kamar",
                      icon: Icons.bed_outlined,
                      items: roomFacilities,
                    ),

                    policySection(
                      title: "Aturan Kos",
                      icon: Icons.rule_outlined,
                      policies: kostRules,
                    ),

                    policySection(
                      title: "Aturan Kamar",
                      icon: Icons.meeting_room_outlined,
                      policies: roomRules,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(
                      color: primaryColor.withOpacity(0.35),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: goToChatOwner,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text(
                    "Hubungi Pemilik",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: showRentSnack,
                  icon: const Icon(Icons.key_rounded),
                  label: const Text(
                    "Mulai Menyewa",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget priceSection() {
    final prices = getPriceItems();

    return sectionCard(
      title: "Harga Sewa",
      icon: Icons.payments_outlined,
      children: [
        if (prices.isEmpty)
          emptyMiniState(
            icon: Icons.money_off_csred_rounded,
            text: "Harga belum ditambahkan",
          )
        else
          Column(
            children: prices.map((item) {
              return priceItemCard(item);
            }).toList(),
          ),
      ],
    );
  }

  Widget priceItemCard(_PriceItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [softGreen, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.price,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget infoSummarySection({
    required String title,
    required String cityName,
    required String address,
    required String maxPeople,
    required String status,
    required double ratingAvg,
    required int ratingCount,
  }) {
    final ratingText = ratingAvg <= 0
        ? "Belum ada"
        : "${ratingAvg.toStringAsFixed(1)} ($ratingCount)";

    final fullAddress = address.isEmpty
        ? "Belum ditambahkan"
        : cityName.isEmpty
        ? address
        : "$address, $cityName";

    return sectionCard(
      title: "Informasi Kos",
      icon: Icons.info_outline_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: miniInfoCard(
                icon: Icons.home_work_outlined,
                title: "Nama",
                value: title,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: miniInfoCard(
                icon: Icons.location_city_rounded,
                title: "Kota",
                value: cityName.isEmpty ? "Belum ada" : cityName,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: miniInfoCard(
                icon: Icons.people_alt_outlined,
                title: "Kapasitas",
                value: maxPeople.isEmpty ? "Belum ada" : "$maxPeople orang",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: miniInfoCard(
                icon: Icons.verified_rounded,
                title: "Status",
                value: status.toLowerCase() == "active"
                    ? "Tersedia"
                    : normalizeText(status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: miniInfoCard(
                icon: Icons.star_rounded,
                title: "Rating",
                value: ratingText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: miniInfoCard(
                icon: Icons.sell_outlined,
                title: "Sewa",
                value: getMainPrice(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        fullInfoCard(
          icon: Icons.location_on_outlined,
          title: "Alamat Lengkap",
          value: fullAddress,
        ),
      ],
    );
  }

  Widget miniInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      height: 94,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 21),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget fullInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget descriptionSection(String description) {
    return sectionCard(
      title: "Deskripsi",
      icon: Icons.description_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            description.trim().isEmpty
                ? "Deskripsi belum ditambahkan"
                : description,
            style: TextStyle(
              color: description.trim().isEmpty
                  ? Colors.grey.shade600
                  : Colors.black87,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildImageHeader({required String title, required String status}) {
    final int imageCount = images.length > 15 ? 15 : images.length;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: images.isEmpty
                    ? imageEmptyState()
                    : PageView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const PageScrollPhysics(),
                        itemCount: imageCount,
                        onPageChanged: (index) {
                          setState(() {
                            currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final img = fixUrl(images[index]);

                          if (img.isEmpty) {
                            return imageEmptyState(
                              icon: Icons.broken_image_outlined,
                              text: "Gambar gagal dimuat",
                            );
                          }

                          return Image.network(
                            img,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;

                              return Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) {
                              return imageEmptyState(
                                icon: Icons.broken_image_outlined,
                                text: "Gambar gagal dimuat",
                              );
                            },
                          );
                        },
                      ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.60),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: status.toLowerCase() == "active"
                          ? Colors.green.withOpacity(0.95)
                          : Colors.orange.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status.toLowerCase() == "active"
                              ? Icons.check_circle
                              : Icons.info_outline,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status.toLowerCase() == "active"
                              ? "Tersedia"
                              : normalizeText(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (images.isNotEmpty)
                Positioned(
                  top: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "${currentImageIndex + 1}/$imageCount",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: imageCount > 1 ? 40 : 18,
                child: IgnorePointer(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              if (imageCount > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: IgnorePointer(
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(imageCount, (index) {
                            final isActive = currentImageIndex == index;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: isActive ? 22 : 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(30),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget imageEmptyState({
    IconData icon = Icons.image_outlined,
    String text = "Gambar belum ditambahkan",
  }) {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget facilitySection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return sectionCard(
      title: title,
      icon: icon,
      children: [
        if (items.isEmpty)
          emptyMiniState(
            icon: Icons.widgets_outlined,
            text: "$title belum ditambahkan",
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                backgroundColor: softGreen,
                side: BorderSide.none,
                avatar: Icon(
                  Icons.check_circle_outline,
                  color: primaryColor,
                  size: 18,
                ),
                label: Text(
                  normalizeText(item),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget policySection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> policies,
  }) {
    return sectionCard(
      title: title,
      icon: icon,
      children: [
        if (policies.isEmpty)
          emptyMiniState(
            icon: Icons.rule_outlined,
            text: "$title belum ditambahkan",
          )
        else
          Column(
            children: policies.map((policy) {
              final policyTitle = policy['title']?.toString() ?? "";
              final policyDesc =
                  policy['description']?.toString() ??
                  policy['desc']?.toString() ??
                  policy['name']?.toString() ??
                  "";

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policyTitle.isEmpty
                                ? "Aturan"
                                : normalizeText(policyTitle),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            policyDesc.isEmpty
                                ? "Deskripsi aturan belum ditambahkan"
                                : policyDesc,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget emptyMiniState({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 14),
            const Text(
              "Data tidak ditemukan",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Detail kos belum bisa dimuat. Coba refresh halaman ini.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: getDetail,
              icon: const Icon(Icons.refresh),
              label: const Text("Muat Ulang"),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceItem {
  final String title;
  final String price;
  final String subtitle;
  final IconData icon;

  const _PriceItem({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.icon,
  });
}
