import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/RatingKos.dart';
import 'package:koskaki/screens/Owner/Edit_kost.dart';
import 'package:koskaki/service/api_service.dart';

class DetailKostPage extends StatefulWidget {
  final Map<String, dynamic> kost;

  const DetailKostPage({super.key, required this.kost});

  @override
  State<DetailKostPage> createState() => _DetailKostPageState();
}

class _DetailKostPageState extends State<DetailKostPage> {
  bool isLoading = true;

  Map<String, dynamic>? detail;

  List<dynamic> images = [];
  List<dynamic> nearbyPlaces = [];

  int currentImageIndex = 0;

  final Color primaryColor = const Color(0xFF0A0E50);
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

      final id = widget.kost['id'];

      if (id == null) {
        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(widget.kost);
          images = extractImages(widget.kost).take(15).toList();
          nearbyPlaces = parseDynamicList(
            widget.kost['nearby_places'] ??
                widget.kost['nearbyPlaces'] ??
                widget.kost['nearby'] ??
                widget.kost['property_nearby_places'],
          );
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

      debugPrint("DETAIL OWNER STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("DETAIL OWNER BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final data = decoded is Map<String, dynamic>
            ? decoded['data'] ?? decoded
            : widget.kost;

        List<dynamic> nearbyData = parseDynamicList(
          data['nearby_places'] ??
              data['nearbyPlaces'] ??
              data['nearby'] ??
              data['property_nearby_places'],
        );

        try {
          final nearbyResponse = await http.get(
            Uri.parse("${ApiService.baseUrl}/properties/$id/nearby-places"),
            headers: {
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
          );

          debugPrint("NEARBY OWNER URL:");
          debugPrint("${ApiService.baseUrl}/properties/$id/nearby-places");

          debugPrint("NEARBY OWNER STATUS:");
          debugPrint(nearbyResponse.statusCode.toString());

          debugPrint("NEARBY OWNER BODY:");
          debugPrint(nearbyResponse.body);

          if (nearbyResponse.statusCode == 200) {
            final nearbyDecoded = jsonDecode(nearbyResponse.body);

            final endpointNearby = parseDynamicList(nearbyDecoded);

            debugPrint("NEARBY OWNER PARSED LENGTH:");
            debugPrint(endpointNearby.length.toString());

            if (endpointNearby.isNotEmpty) {
              nearbyData = endpointNearby;
            }
          }
        } catch (e) {
          debugPrint("GET NEARBY OWNER ERROR:");
          debugPrint(e.toString());
        }

        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(data);
          images = extractImages(data).take(15).toList();
          nearbyPlaces = nearbyData;
          currentImageIndex = 0;
          isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          detail = Map<String, dynamic>.from(widget.kost);
          images = extractImages(widget.kost).take(15).toList();
          nearbyPlaces = parseDynamicList(
            widget.kost['nearby_places'] ??
                widget.kost['nearbyPlaces'] ??
                widget.kost['nearby'] ??
                widget.kost['property_nearby_places'],
          );
          currentImageIndex = 0;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("GET DETAIL OWNER ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        detail = Map<String, dynamic>.from(widget.kost);
        images = extractImages(widget.kost).take(15).toList();
        nearbyPlaces = parseDynamicList(
          widget.kost['nearby_places'] ??
              widget.kost['nearbyPlaces'] ??
              widget.kost['nearby'] ??
              widget.kost['property_nearby_places'],
        );
        currentImageIndex = 0;
        isLoading = false;
      });
    }
  }

  List<dynamic> parseDynamicList(dynamic value) {
    if (value == null) return [];
  
    if (value is List) {
      return value;
    }
  
    if (value is Map) {
      if (value['data'] is List) {
        return List<dynamic>.from(value['data']);
      }
  
      if (value['data'] is Map && value['data']['data'] is List) {
        return List<dynamic>.from(value['data']['data']);
      }
  
      if (value['nearby_places'] is List) {
        return List<dynamic>.from(value['nearby_places']);
      }
  
      if (value['nearbyPlaces'] is List) {
        return List<dynamic>.from(value['nearbyPlaces']);
      }
  
      if (value['property_nearby_places'] is List) {
        return List<dynamic>.from(value['property_nearby_places']);
      }
  
      if (value['places'] is List) {
        return List<dynamic>.from(value['places']);
      }
  
      if (value['items'] is List) {
        return List<dynamic>.from(value['items']);
      }
  
      if (value['results'] is List) {
        return List<dynamic>.from(value['results']);
      }
    }
  
    if (value is String && value.trim().isNotEmpty && value != "null") {
      try {
        final decoded = jsonDecode(value);
        return parseDynamicList(decoded);
      } catch (_) {}
    }
  
    return [];
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

  void openImageViewer(int initialIndex) {
    if (images.isEmpty) return;

    final imageUrls = images
        .take(15)
        .map((item) {
          return fixUrl(item);
        })
        .where((url) {
          return url.trim().isNotEmpty;
        })
        .toList();

    if (imageUrls.isEmpty) return;

    if (initialIndex < 0 || initialIndex >= imageUrls.length) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: FullscreenOwnerKostImageViewer(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
    );
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
    if (value == null) return false;

    final raw = value.toString().trim();

    if (raw.isEmpty || raw == "null") return false;

    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (clean.isEmpty) return false;

    final number = int.tryParse(clean) ?? 0;

    return number > 0;
  }

  List<_PriceItem> getPriceItems() {
    final d = detail ?? widget.kost;

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
          subtitle: "Per Bulan",
          icon: Icons.calendar_month_rounded,
        ),
      );
    }

    if (hasValue(year)) {
      prices.add(
        _PriceItem(
          title: "Tahunan",
          price: "Rp ${formatRupiah(year)}",
          subtitle: "Per Tahun",
          icon: Icons.event_available_rounded,
        ),
      );
    }

    if (hasValue(week)) {
      prices.add(
        _PriceItem(
          title: "Mingguan",
          price: "Rp ${formatRupiah(week)}",
          subtitle: "Per Minggu",
          icon: Icons.date_range_rounded,
        ),
      );
    }

    if (hasValue(night)) {
      prices.add(
        _PriceItem(
          title: "Harian",
          price: "Rp ${formatRupiah(night)}",
          subtitle: "Per Malam",
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
      final fullImageUrl = img['full_image_url']?.toString() ?? "";

      if (fullImageUrl.isNotEmpty &&
          fullImageUrl.startsWith("http") &&
          !fullImageUrl.endsWith("/storage")) {
        url = fullImageUrl;
      } else {
        url =
            img['url']?.toString() ??
            img['image']?.toString() ??
            img['path']?.toString() ??
            img['image_path']?.toString() ??
            img['file']?.toString() ??
            "";
      }
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
              return e['feature']?.toString() ??
                  e['name']?.toString() ??
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
                  return e['feature']?.toString() ??
                      e['name']?.toString() ??
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
      return value
          .map<Map<String, dynamic>>((e) {
            if (e is Map) {
              final map = Map<String, dynamic>.from(e);

              final title = map['title']?.toString() ?? "";
              final description = map['description']?.toString() ?? "";
              final desc = map['desc']?.toString() ?? "";
              final policy = map['policy']?.toString() ?? "";
              final name = map['name']?.toString() ?? "";

              if (title.isEmpty && policy.isNotEmpty) {
                map['title'] = "Aturan";
              }

              if (description.isEmpty && desc.isEmpty && policy.isNotEmpty) {
                map['description'] = policy;
              }

              if (description.isEmpty &&
                  desc.isEmpty &&
                  policy.isEmpty &&
                  name.isNotEmpty) {
                map['description'] = name;
              }

              return map;
            }

            return {"title": "Aturan", "description": e.toString()};
          })
          .where((e) {
            final title = e['title']?.toString() ?? "";
            final description = e['description']?.toString() ?? "";
            final desc = e['desc']?.toString() ?? "";
            final policy = e['policy']?.toString() ?? "";
            final name = e['name']?.toString() ?? "";

            return title.isNotEmpty ||
                description.isNotEmpty ||
                desc.isNotEmpty ||
                policy.isNotEmpty ||
                name.isNotEmpty;
          })
          .toList();
    }

    if (value is String && value.trim().isNotEmpty && value != "null") {
      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return parsePolicyList(decoded);
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

  String formatDistance(dynamic value) {
    if (value == null) return "";

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return "";

    text = text.replaceAll(',', '.');

    if (text.endsWith('.0')) {
      text = text.substring(0, text.length - 2);
    }

    return text;
  }

  String getNearbyName(dynamic item) {
    if (item is! Map) return "-";
  
    final map = Map<String, dynamic>.from(item);
  
    final place =
        map['place'] ??
        map['places'] ??
        map['nearby_place'] ??
        map['nearbyPlace'] ??
        map['nearby_places'];
  
    if (place is Map) {
      final placeMap = Map<String, dynamic>.from(place);
  
      final name =
          placeMap['name']?.toString() ??
          placeMap['title']?.toString() ??
          placeMap['place_name']?.toString() ??
          placeMap['nama']?.toString() ??
          "";
  
      if (name.trim().isNotEmpty && name != "null") {
        return name;
      }
    }
  
    return map['name']?.toString() ??
        map['title']?.toString() ??
        map['place_name']?.toString() ??
        map['nama']?.toString() ??
        map['location_name']?.toString() ??
        "-";
  }

  String getNearbyType(dynamic item) {
    if (item is! Map) return "";
  
    final map = Map<String, dynamic>.from(item);
  
    final place =
        map['place'] ??
        map['places'] ??
        map['nearby_place'] ??
        map['nearbyPlace'] ??
        map['nearby_places'];
  
    if (place is Map) {
      final placeMap = Map<String, dynamic>.from(place);
  
      final type =
          placeMap['type']?.toString() ??
          placeMap['category']?.toString() ??
          placeMap['place_type']?.toString() ??
          placeMap['kategori']?.toString() ??
          "";
  
      if (type.trim().isNotEmpty && type != "null") {
        return type;
      }
    }
  
    return map['type']?.toString() ??
        map['category']?.toString() ??
        map['place_type']?.toString() ??
        map['kategori']?.toString() ??
        "";
  }

  String getNearbyDistance(dynamic item) {
    if (item is! Map) return "";
  
    final map = Map<String, dynamic>.from(item);
  
    final pivot = map['pivot'];
  
    if (pivot is Map) {
      final pivotMap = Map<String, dynamic>.from(pivot);
  
      final distance =
          pivotMap['distance']?.toString() ??
          pivotMap['distance_km']?.toString() ??
          pivotMap['jarak']?.toString() ??
          "";
  
      if (distance.trim().isNotEmpty && distance != "null") {
        return formatDistance(distance);
      }
    }
  
    final distance =
        map['distance']?.toString() ??
        map['distance_km']?.toString() ??
        map['jarak']?.toString() ??
        map['range']?.toString() ??
        "";
  
    return formatDistance(distance);
  }

  IconData getNearbyIcon(String type, String name) {
    final text = "$type $name".toLowerCase();

    if (text.contains("bandara") || text.contains("airport")) {
      return Icons.flight_takeoff_rounded;
    }

    if (text.contains("stasiun") || text.contains("station")) {
      return Icons.train_rounded;
    }

    if (text.contains("terminal") || text.contains("bus")) {
      return Icons.directions_bus_rounded;
    }

    if (text.contains("kampus") ||
        text.contains("universitas") ||
        text.contains("sekolah")) {
      return Icons.school_rounded;
    }

    if (text.contains("rumah sakit") ||
        text.contains("hospital") ||
        text.contains("rs")) {
      return Icons.local_hospital_rounded;
    }

    if (text.contains("mall") ||
        text.contains("pusat belanja") ||
        text.contains("plaza")) {
      return Icons.local_mall_rounded;
    }

    if (text.contains("pasar")) {
      return Icons.storefront_rounded;
    }

    if (text.contains("masjid") ||
        text.contains("gereja") ||
        text.contains("ibadah")) {
      return Icons.place_rounded;
    }

    if (text.contains("halte")) {
      return Icons.directions_bus_filled_rounded;
    }

    if (text.contains("alun") || text.contains("pusat kota")) {
      return Icons.location_city_rounded;
    }

    return Icons.near_me_rounded;
  }

  IconData getFacilityIcon(String value) {
    final text = value.toLowerCase();

    if (text.contains("24") || text.contains("24 jam")) {
      return Icons.watch_later_rounded;
    }

    if (text.contains("wifi")) {
      return Icons.wifi_rounded;
    }

    if (text.contains("cctv")) {
      return Icons.videocam_rounded;
    }

    if (text.contains("parkir motor")) {
      return Icons.two_wheeler_rounded;
    }

    if (text.contains("parkir mobil")) {
      return Icons.directions_car_rounded;
    }

    if (text.contains("parkir")) {
      return Icons.local_parking_rounded;
    }

    if (text.contains("dapur")) {
      return Icons.kitchen_rounded;
    }

    if (text.contains("laundry")) {
      return Icons.local_laundry_service_rounded;
    }

    if (text.contains("ruang tamu")) {
      return Icons.weekend_rounded;
    }

    if (text.contains("keamanan")) {
      return Icons.security_rounded;
    }

    if (text.contains("mushola")) {
      return Icons.mosque_rounded;
    }

    if (text.contains("ac")) {
      return Icons.ac_unit_rounded;
    }

    if (text.contains("tv")) {
      return Icons.tv_rounded;
    }

    if (text.contains("kasur")) {
      return Icons.bed_rounded;
    }

    if (text.contains("lemari")) {
      return Icons.inventory_2_rounded;
    }

    if (text.contains("meja")) {
      return Icons.table_restaurant_rounded;
    }

    if (text.contains("kursi")) {
      return Icons.chair_rounded;
    }

    if (text.contains("kulkas")) {
      return Icons.kitchen_rounded;
    }

    if (text.contains("kamar mandi")) {
      return Icons.bathtub_rounded;
    }

    return Icons.check_circle_outline_rounded;
  }

  IconData getPolicyIcon(
    String title,
    String description,
    String sectionTitle,
  ) {
    final text = "$title $description $sectionTitle".toLowerCase();

    if (text.contains("tamu") || text.contains("guest")) {
      return Icons.groups_rounded;
    }

    if (text.contains("lapor") ||
        text.contains("izin") ||
        text.contains("identitas") ||
        text.contains("ktp")) {
      return Icons.assignment_ind_rounded;
    }

    if (text.contains("rokok") || text.contains("merokok")) {
      return Icons.smoke_free_rounded;
    }

    if (text.contains("hewan") ||
        text.contains("peliharaan") ||
        text.contains("binatang")) {
      return Icons.pets_rounded;
    }

    if (text.contains("bersih") ||
        text.contains("kebersihan") ||
        text.contains("sampah")) {
      return Icons.cleaning_services_rounded;
    }

    if (text.contains("jam") ||
        text.contains("malam") ||
        text.contains("pulang") ||
        text.contains("batas")) {
      return Icons.schedule_rounded;
    }

    if (text.contains("bayar") ||
        text.contains("pembayaran") ||
        text.contains("uang") ||
        text.contains("sewa")) {
      return Icons.payments_rounded;
    }

    if (text.contains("parkir")) {
      return Icons.local_parking_rounded;
    }

    if (text.contains("kunci")) {
      return Icons.key_rounded;
    }

    if (text.contains("dapur")) {
      return Icons.kitchen_rounded;
    }

    if (text.contains("kamar mandi") || text.contains("mandi")) {
      return Icons.bathtub_rounded;
    }

    if (text.contains("kamar")) {
      return Icons.meeting_room_rounded;
    }

    if (text.contains("berisik") ||
        text.contains("gaduh") ||
        text.contains("musik") ||
        text.contains("suara")) {
      return Icons.volume_off_rounded;
    }

    if (text.contains("rusak") ||
        text.contains("kerusakan") ||
        text.contains("barang")) {
      return Icons.build_circle_rounded;
    }

    if (text.contains("listrik")) {
      return Icons.electrical_services_rounded;
    }

    if (text.contains("air")) {
      return Icons.water_drop_rounded;
    }

    if (text.contains("kost") || text.contains("kos")) {
      return Icons.rule_rounded;
    }

    return Icons.gavel_rounded;
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> deleteKost() async {
    try {
      final token = await ApiService().getToken();
      final id = (detail ?? widget.kost)['id'] ?? widget.kost['id'];

      if (id == null) {
        showMessage("ID kost tidak ditemukan");
        return;
      }

      final response = await http.delete(
        Uri.parse("${ApiService.baseUrl}/properties/$id"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint("DELETE OWNER STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("DELETE OWNER BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;

        Navigator.pop(context, true);
      } else {
        showMessage("Gagal menghapus kost");
      }
    } catch (e) {
      debugPrint("DELETE OWNER ERROR:");
      debugPrint(e.toString());

      showMessage("Gagal menghapus kost");
    }
  }

  void goEdit() {
    final d = detail ?? widget.kost;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditKostPage(kost: d)),
    ).then((value) {
      if (value == true) {
        getDetail();
      }
    });
  }

  void goToRatingPage() {
    final d = detail ?? widget.kost;
  
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingKos(
          kost: Map<String, dynamic>.from(d),
        ),
      ),
    ).then((_) {
      getDetail();
    });
  }
  
  Future<void> showDeleteDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Hapus Kost?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Yakin ingin menghapus kost ini? Data yang sudah dihapus tidak bisa dikembalikan.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Batal"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text("Hapus"),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      deleteKost();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = detail ?? {};

    final title =
        d['title']?.toString() ?? d['name']?.toString() ?? "Detail Kost";

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
      d['kost_features'] ??
          d['kost_facilities'] ??
          d['property_features'] ??
          d['features'] ??
          d['feature'] ??
          d['facilities'] ??
          d['facility'],
    );

    final roomFacilities = parseStringList(
      d['place_features'] ?? d['room_facilities'] ?? d['place_facilities'],
    );

    final kostRules = parsePolicyList(
      d['kost_policies'] ??
          d['kost_rules'] ??
          d['property_policies'] ??
          d['policies'] ??
          d['rules'] ??
          d['rule'],
    );

    final roomRules = parsePolicyList(
      d['place_policies'] ?? d['room_rules'] ?? d['place_rules'],
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Detail Kost",
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

                    nearbyPlacesSection(items: nearbyPlaces),

                    descriptionSection(description),

                    facilitySection(
                      title: "Fasilitas Kost",
                      icon: Icons.maps_home_work_outlined,
                      items: kostFacilities,
                    ),

                    facilitySection(
                      title: "Fasilitas Kamar",
                      icon: Icons.bed_outlined,
                      items: roomFacilities,
                    ),

                    policySection(
                      title: "Aturan Kost",
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
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
              child: bottomActionButton(
                label: "Edit",
                icon: Icons.edit_note_rounded,
                isPrimary: true,
                onTap: goEdit,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: bottomActionButton(
                label: "Hapus",
                icon: Icons.delete_outline_rounded,
                isPrimary: false,
                isDanger: true,
                onTap: showDeleteDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bottomActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return SizedBox(
      height: 54,
      child: isPrimary
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDanger ? Colors.red : primaryColor,
                side: BorderSide(
                  color: isDanger
                      ? Colors.red.withOpacity(0.35)
                      : primaryColor.withOpacity(0.28),
                  width: 1.3,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
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
            icon: Icons.payments_outlined,
            text: "Harga belum ditambahkan",
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.85,
            ),
            itemBuilder: (context, index) {
              return priceItemCard(prices[index]);
            },
          ),
      ],
    );
  }

  Widget priceItemCard(_PriceItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [softGreen, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 10,
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
      title: "Informasi Kost",
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
                onTap: goToRatingPage,
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
    VoidCallback? onTap,
  }) {
    final card = Container(
      height: 94,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 21),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: primaryColor.withOpacity(0.65),
                  size: 13,
                ),
            ],
          ),
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
  
    if (onTap == null) {
      return card;
    }
  
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
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

  Widget nearbyPlacesSection({required List<dynamic> items}) {
    return sectionCard(
      title: "Jarak Dengan Transportasi",
      icon: Icons.near_me_outlined,
      children: [
        if (items.isEmpty)
          emptyMiniState(
            icon: Icons.location_off_outlined,
            text: "Jarak dengan transportasi belum ditambahkan",
          )
        else
          Column(
            children: [
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    final name = getNearbyName(item);
                    final type = getNearbyType(item);
                    final distance = getNearbyDistance(item);
                    final icon = getNearbyIcon(type, name);

                    return nearbyPlaceCard(
                      name: name,
                      type: type,
                      distance: distance,
                      icon: icon,
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget nearbyPlaceCard({
    required String name,
    required String type,
    required String distance,
    required IconData icon,
  }) {
    return Container(
      width: 215,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF4F6FA), softGreen.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const Spacer(),
              if (type.trim().isNotEmpty && type != "null")
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: primaryColor.withOpacity(0.08)),
                  ),
                  child: Text(
                    normalizeText(type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.route_rounded, color: primaryColor, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  distance.trim().isEmpty
                      ? "Jarak belum tersedia"
                      : "$distance KM dari kos",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              openImageViewer(index);
                            },
                            child: Hero(
                              tag: "owner-detail-kost-image-$index",
                              child: Image.network(
                                img,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
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
                              ),
                            ),
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
                            Icons.zoom_out_map_rounded,
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final item = normalizeText(items[index]);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getFacilityIcon(item),
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              );
            },
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
              final policyTitle =
                  policy['title']?.toString() ??
                  policy['policy']?.toString() ??
                  "";

              final policyDesc =
                  policy['description']?.toString() ??
                  policy['desc']?.toString() ??
                  policy['name']?.toString() ??
                  policy['policy']?.toString() ??
                  "";

              final policyIcon = getPolicyIcon(policyTitle, policyDesc, title);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(policyIcon, color: primaryColor, size: 23),
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
              "Detail kost belum bisa dimuat. Coba refresh halaman ini.",
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

class FullscreenOwnerKostImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenOwnerKostImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullscreenOwnerKostImageViewer> createState() =>
      _FullscreenOwnerKostImageViewerState();
}

class _FullscreenOwnerKostImageViewerState
    extends State<FullscreenOwnerKostImageViewer> {
  late final PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void closeViewer() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];

              if (url.trim().isEmpty) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 70,
                  ),
                );
              }

              return Center(
                child: Hero(
                  tag: "owner-detail-kost-image-$index",
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 70,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: closeViewer,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        "${currentIndex + 1}/$total",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "Cubit untuk zoom • Geser untuk melihat foto lain",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
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
