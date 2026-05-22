import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Resident/DetailKos_page.dart';
import 'package:koskaki/service/api_service.dart';

const Color _primaryColor = Color(0xFF2D2F8F);
const Color _secondaryColor = Color(0xFF5B5FEF);
const Color _softBlue = Color(0xFFEFF2FF);
const Color _darkText = Color(0xFF161A33);

enum SearchPriceType { semua, malam, minggu, bulan, tahun }

enum SearchOrder { rekomendasi, termurah, termahal, terbaru, terlengkap }

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key, this.initialKeyword = ""});

  final String initialKeyword;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> kosList = [];

  bool loadingKos = true;

  String searchKeyword = "";

  SearchPriceType selectedPriceType = SearchPriceType.semua;
  SearchOrder selectedOrder = SearchOrder.rekomendasi;

  int? minPrice;
  int? maxPrice;

  Set<String> selectedKostFacilities = {};
  Set<String> selectedRoomFacilities = {};

  final List<String> kostFacilityOptions = [
    "WiFi",
    "CCTV",
    "Kasur",
    "Lemari",
    "Parkir Motor",
    "Parkir Mobil",
    "Dapur Bersama",
    "Laundry",
    "Ruang Tamu",
    "Keamanan 24 Jam",
    "Mushola",
  ];

  final List<String> roomFacilityOptions = [
    "AC",
    "TV",
    "Parkir Mobil",
    "Kasur",
    "Lemari",
    "Meja",
    "Kursi",
    "Kulkas",
    "Kamar Mandi Dalam",
  ];

  @override
  void initState() {
    super.initState();

    searchKeyword = widget.initialKeyword;
    searchController.text = widget.initialKeyword;

    loadKosFromApi();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadKosFromApi() async {
    try {
      if (mounted) {
        setState(() {
          loadingKos = true;
        });
      }

      final api = ApiService();
      final token = await api.getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint("STATUS SEARCH KOS: ${response.statusCode}");
      debugPrint("BODY SEARCH KOS: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        dynamic rawData;

        if (decoded is Map<String, dynamic>) {
          rawData = decoded['data'];

          if (rawData is Map<String, dynamic> && rawData['data'] != null) {
            rawData = rawData['data'];
          }
        } else {
          rawData = decoded;
        }

        if (rawData is List) {
          final basicData = rawData
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((item) {
                final status = item['status']?.toString().toLowerCase();

                return status == null ||
                    status == "active" ||
                    status == "aktif";
              })
              .toList();

          final detailData = await Future.wait(
            basicData.map((kos) async {
              return attachFacilitiesToKos(kos);
            }),
          );

          for (final kos in detailData) {
            debugPrint("DEBUG TITLE: ${getKosTitle(kos)}");
            debugPrint("DEBUG PROPERTY ID: ${getPropertyId(kos)}");
            debugPrint("DEBUG PLACE IDS: ${getPlacePropertyIds(kos)}");
            debugPrint(
              "DEBUG KOST FACILITIES: ${kos['_search_kost_facilities']}",
            );
            debugPrint(
              "DEBUG ROOM FACILITIES: ${kos['_search_room_facilities']}",
            );
            debugPrint("DEBUG ALL FACILITIES: ${getAllFacilities(kos)}");
          }

          if (!mounted) return;

          setState(() {
            kosList = detailData;
            loadingKos = false;
          });
        } else {
          if (!mounted) return;

          setState(() {
            kosList = [];
            loadingKos = false;
          });
        }
      } else {
        if (!mounted) return;

        setState(() {
          kosList = [];
          loadingKos = false;
        });
      }
    } catch (e) {
      debugPrint("ERROR SEARCH KOS API: $e");

      if (!mounted) return;

      setState(() {
        kosList = [];
        loadingKos = false;
      });
    }
  }

  dynamic getPropertyId(Map<String, dynamic> kos) {
    return kos['id'] ??
        kos['property_id'] ??
        kos['propertyId'] ??
        kos['kos_id'] ??
        kos['kosId'];
  }

  List<dynamic> getPlacePropertyIds(Map<String, dynamic> kos) {
    final List<dynamic> result = [];

    void addId(dynamic value) {
      if (value == null) return;

      if (value is int || value is String) {
        final text = value.toString();

        if (text.isNotEmpty && text != "null") {
          result.add(value);
        }

        return;
      }

      if (value is List) {
        for (final item in value) {
          addId(item);
        }

        return;
      }

      if (value is Map) {
        final id =
            value['id'] ??
            value['place_property_id'] ??
            value['placePropertyId'] ??
            value['place_id'] ??
            value['placeId'] ??
            value['property_place_id'] ??
            value['propertyPlaceId'];

        addId(id);

        addId(value['place_properties']);
        addId(value['placeProperties']);
        addId(value['place_property']);
        addId(value['placeProperty']);
        addId(value['rooms']);
        addId(value['room']);
        addId(value['kamar']);

        return;
      }
    }

    addId(kos['place_properties']);
    addId(kos['placeProperties']);
    addId(kos['place_property']);
    addId(kos['placeProperty']);
    addId(kos['place_property_id']);
    addId(kos['placePropertyId']);
    addId(kos['place_id']);
    addId(kos['placeId']);
    addId(kos['rooms']);
    addId(kos['room']);
    addId(kos['kamar']);

    return result.toSet().toList();
  }

  Future<Map<String, dynamic>?> loadKosDetailById(dynamic propertyId) async {
    try {
      final api = ApiService();
      final token = await api.getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint("STATUS DETAIL PROPERTY $propertyId: ${response.statusCode}");
      debugPrint("BODY DETAIL PROPERTY $propertyId: ${response.body}");

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);

      dynamic rawData;

      if (decoded is Map<String, dynamic>) {
        rawData =
            decoded['data'] ?? decoded['property'] ?? decoded['kos'] ?? decoded;
      } else {
        rawData = decoded;
      }

      if (rawData is Map) {
        return Map<String, dynamic>.from(rawData);
      }

      return null;
    } catch (e) {
      debugPrint("ERROR LOAD DETAIL PROPERTY $propertyId: $e");
      return null;
    }
  }

  Future<List<String>> loadFeatureNamesFromUrls(List<String> urls) async {
    final Map<String, String> unique = {};

    for (final url in urls) {
      try {
        final api = ApiService();
        final token = await api.getToken();

        final response = await http.get(
          Uri.parse(url),
          headers: {
            "Accept": "application/json",
            if (token != null) "Authorization": "Bearer $token",
          },
        );

        debugPrint("STATUS FEATURE URL: $url => ${response.statusCode}");
        debugPrint("BODY FEATURE URL: $url => ${response.body}");

        if (response.statusCode != 200) {
          continue;
        }

        final decoded = jsonDecode(response.body);

        dynamic rawData;

        if (decoded is Map<String, dynamic>) {
          rawData =
              decoded['data'] ??
              decoded['features'] ??
              decoded['feature'] ??
              decoded['facilities'] ??
              decoded['facility'] ??
              decoded;
        } else {
          rawData = decoded;
        }

        final features = parseFacilityValue(rawData);

        for (final item in features) {
          final normalized = normalizeFacility(item);

          if (normalized.isNotEmpty) {
            unique[normalized] = item;
          }
        }

        if (unique.isNotEmpty) {
          break;
        }
      } catch (e) {
        debugPrint("ERROR LOAD FEATURE URL $url: $e");
      }
    }

    return unique.values.toList();
  }

  Future<Map<String, dynamic>> attachFacilitiesToKos(
    Map<String, dynamic> kos,
  ) async {
    final propertyId = getPropertyId(kos);

    if (propertyId == null) {
      return kos;
    }

    final detail = await loadKosDetailById(propertyId);

    final mergedKos = <String, dynamic>{...kos, if (detail != null) ...detail};

    final placePropertyIds = getPlacePropertyIds(mergedKos);

    final List<String> roomFacilities = [];

    roomFacilities.addAll(
      await loadFeatureNamesFromUrls([
        "${ApiService.baseUrl}/properties/$propertyId/features",
      ]),
    );

    roomFacilities.addAll(parseFacilityValue(mergedKos['features']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['feature']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['facilities']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['facility']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['fasilitas']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['room_features']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['roomFeatures']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['room_facilities']));
    roomFacilities.addAll(parseFacilityValue(mergedKos['roomFacilities']));

    final List<String> kostFacilities = [];

    kostFacilities.addAll(parseFacilityValue(mergedKos['place_properties']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['placeProperties']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['place_property']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['placeProperty']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['kost_features']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['kostFeatures']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['kost_facilities']));
    kostFacilities.addAll(parseFacilityValue(mergedKos['kostFacilities']));

    for (final placeId in placePropertyIds) {
      final features = await loadFeatureNamesFromUrls([
        "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/features",
        "${ApiService.baseUrl}/properties/place-properties/$placeId/features",
      ]);

      kostFacilities.addAll(features);
    }

    final uniqueRoomFacilities = <String, String>{};
    final uniqueKostFacilities = <String, String>{};

    for (final item in roomFacilities) {
      final normalized = normalizeFacility(item);

      if (normalized.isNotEmpty) {
        uniqueRoomFacilities[normalized] = item;
      }
    }

    for (final item in kostFacilities) {
      final normalized = normalizeFacility(item);

      if (normalized.isNotEmpty) {
        uniqueKostFacilities[normalized] = item;
      }
    }

    return {
      ...mergedKos,
      "_search_room_facilities": uniqueRoomFacilities.values.toList(),
      "_search_kost_facilities": uniqueKostFacilities.values.toList(),
    };
  }

  int? toInt(dynamic value) {
    if (value == null) return null;

    final text = value.toString();

    if (text.isEmpty || text == "null") return null;

    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) return null;

    return int.tryParse(cleanText);
  }

  int? parsePriceInput(String value) {
    final cleanText = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) return null;

    return int.tryParse(cleanText);
  }

  String formatRupiah(int value) {
    final result = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp $result";
  }

  String formatRupiahInput(int? value) {
    if (value == null) return "";

    final result = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp. $result";
  }

  String normalizeFacility(String value) {
    String text = value
        .toLowerCase()
        .replaceAll("_", " ")
        .replaceAll("-", " ")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();

    text = text.replaceAll("wi fi", "wifi");

    return text;
  }

  List<String> parseFacilityValue(dynamic raw) {
    final List<String> result = [];

    void addText(dynamic value) {
      if (value == null) return;

      String text = value.toString().trim();

      if (text.isEmpty || text.toLowerCase() == "null") return;

      text = text
          .replaceAll("[", "")
          .replaceAll("]", "")
          .replaceAll("{", "")
          .replaceAll("}", "")
          .replaceAll('"', "")
          .replaceAll("'", "");

      final parts = text.split(RegExp(r'[,;/|\n]'));

      for (final part in parts) {
        final clean = part
            .replaceAll("_", " ")
            .replaceAll("-", " ")
            .replaceAll(RegExp(r'\s+'), " ")
            .trim();

        if (clean.isNotEmpty && clean.toLowerCase() != "null") {
          result.add(clean);
        }
      }
    }

    void readValue(dynamic value) {
      if (value == null) return;

      if (value is String || value is num) {
        addText(value);
        return;
      }

      if (value is bool) {
        return;
      }

      if (value is List) {
        for (final item in value) {
          readValue(item);
        }

        return;
      }

      if (value is Map) {
        final possibleName =
            value['name'] ??
            value['nama'] ??
            value['title'] ??
            value['label'] ??
            value['value'] ??
            value['feature'] ??
            value['facility'] ??
            value['fasilitas'] ??
            value['facility_name'] ??
            value['facilityName'] ??
            value['nama_fasilitas'] ??
            value['namaFasilitas'] ??
            value['amenity'] ??
            value['amenity_name'] ??
            value['amenityName'];

        addText(possibleName);

        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();

          if (key.contains("feature") ||
              key.contains("facility") ||
              key.contains("fasilitas") ||
              key.contains("amenity") ||
              key.contains("name") ||
              key.contains("nama") ||
              key.contains("title") ||
              key.contains("label")) {
            readValue(entry.value);
          }

          if (entry.value is Map || entry.value is List) {
            readValue(entry.value);
          }
        }
      }
    }

    readValue(raw);

    final Map<String, String> unique = {};

    for (final item in result) {
      final clean = item.trim();
      final normalized = normalizeFacility(clean);

      if (clean.isNotEmpty && normalized.isNotEmpty) {
        unique[normalized] = clean;
      }
    }

    return unique.values.toList();
  }

  List<String> getKostFacilities(Map<String, dynamic> kos) {
    final raw = parseFacilityValue(
      kos['_search_kost_facilities'],
    ).map((item) => normalizeFacility(item)).toSet();

    return kostFacilityOptions.where((option) {
      final normalizedOption = normalizeFacility(option);

      return raw.contains(normalizedOption);
    }).toList();
  }

  List<String> getRoomFacilities(Map<String, dynamic> kos) {
    final raw = parseFacilityValue(
      kos['_search_room_facilities'],
    ).map((item) => normalizeFacility(item)).toSet();

    return roomFacilityOptions.where((option) {
      final normalizedOption = normalizeFacility(option);

      return raw.contains(normalizedOption);
    }).toList();
  }

  List<String> getAllFacilities(Map<String, dynamic> kos) {
    final Map<String, String> unique = {};

    for (final item in [...getKostFacilities(kos), ...getRoomFacilities(kos)]) {
      final normalized = normalizeFacility(item);

      if (normalized.isNotEmpty) {
        unique[normalized] = item;
      }
    }

    return unique.values.toList();
  }

  String getPriceTypeLabel(SearchPriceType type) {
    switch (type) {
      case SearchPriceType.semua:
        return "Semua";
      case SearchPriceType.malam:
        return "Per Malam";
      case SearchPriceType.minggu:
        return "Per Minggu";
      case SearchPriceType.bulan:
        return "Per Bulan";
      case SearchPriceType.tahun:
        return "Per Tahun";
    }
  }

  String getOrderLabel(SearchOrder order) {
    switch (order) {
      case SearchOrder.rekomendasi:
        return "Rekomendasi";
      case SearchOrder.termurah:
        return "Termurah";
      case SearchOrder.termahal:
        return "Termahal";
      case SearchOrder.terbaru:
        return "Terbaru";
      case SearchOrder.terlengkap:
        return "Terlengkap";
    }
  }

  int? getPriceByType(Map<String, dynamic> kos, SearchPriceType type) {
    switch (type) {
      case SearchPriceType.malam:
        return toInt(kos['price_perNight'] ?? kos['price_per_night']);
      case SearchPriceType.minggu:
        return toInt(kos['price_perWeek'] ?? kos['price_per_week']);
      case SearchPriceType.bulan:
        return toInt(kos['price_perMonth'] ?? kos['price_per_month']);
      case SearchPriceType.tahun:
        return toInt(kos['price_perYear'] ?? kos['price_per_year']);
      case SearchPriceType.semua:
        return getMainPriceValue(kos);
    }
  }

  int? getMainPriceValue(Map<String, dynamic> kos) {
    final month = toInt(kos['price_perMonth'] ?? kos['price_per_month']);
    final night = toInt(kos['price_perNight'] ?? kos['price_per_night']);
    final week = toInt(kos['price_perWeek'] ?? kos['price_per_week']);
    final year = toInt(kos['price_perYear'] ?? kos['price_per_year']);

    return month ?? night ?? week ?? year;
  }

  String getKosPrice(Map<String, dynamic> kos) {
    if (selectedPriceType != SearchPriceType.semua) {
      final selectedPrice = getPriceByType(kos, selectedPriceType);

      if (selectedPrice != null && selectedPrice > 0) {
        final label = getPriceTypeLabel(
          selectedPriceType,
        ).replaceAll("Per ", "");

        return "${formatRupiah(selectedPrice)} / $label";
      }
    }

    final month = toInt(kos['price_perMonth'] ?? kos['price_per_month']);
    final night = toInt(kos['price_perNight'] ?? kos['price_per_night']);
    final week = toInt(kos['price_perWeek'] ?? kos['price_per_week']);
    final year = toInt(kos['price_perYear'] ?? kos['price_per_year']);

    if (month != null && month > 0) {
      return "${formatRupiah(month)} / Bulan";
    }

    if (night != null && night > 0) {
      return "${formatRupiah(night)} / Malam";
    }

    if (week != null && week > 0) {
      return "${formatRupiah(week)} / Minggu";
    }

    if (year != null && year > 0) {
      return "${formatRupiah(year)} / Tahun";
    }

    return "Harga belum tersedia";
  }

  String getKosTitle(Map<String, dynamic> kos) {
    return kos['title']?.toString() ??
        kos['name']?.toString() ??
        "Nama kos tidak tersedia";
  }

  String getKosAddress(Map<String, dynamic> kos) {
    return kos['address']?.toString() ?? "Alamat belum tersedia";
  }

  String getKosCity(Map<String, dynamic> kos) {
    final city = kos['city'];

    if (city is Map) {
      return city['name']?.toString() ?? "Kota belum tersedia";
    }

    return kos['city_name']?.toString() ?? "Kota belum tersedia";
  }

  String getKosDescription(Map<String, dynamic> kos) {
    return kos['description']?.toString() ?? kos['desc']?.toString() ?? "";
  }

  double getRatingValue(Map<String, dynamic> kos) {
    return double.tryParse(kos['rating_avg']?.toString() ?? "0") ?? 0;
  }

  int getImageCount(Map<String, dynamic> kos) {
    final images = kos['images'];

    if (images is List) return images.length;

    return 0;
  }

  String? getImageUrlFromValue(dynamic value) {
    if (value == null) return null;

    final baseUrlWithoutApi = ApiService.baseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );

    if (value is String) {
      if (value.isEmpty || value == "null") return null;

      if (value.startsWith("http")) return value;

      if (value.startsWith("/storage")) {
        return "$baseUrlWithoutApi$value";
      }

      if (value.startsWith("storage")) {
        return "$baseUrlWithoutApi/$value";
      }

      return "$baseUrlWithoutApi/storage/$value";
    }

    if (value is Map) {
      final possibleImage =
          value['url'] ??
          value['image'] ??
          value['path'] ??
          value['image_path'] ??
          value['file'];

      return getImageUrlFromValue(possibleImage);
    }

    return null;
  }

  String? getKosImage(Map<String, dynamic> kos) {
    final mainImage = getImageUrlFromValue(kos['main_image']);

    if (mainImage != null) return mainImage;

    final images = kos['images'];

    if (images is List && images.isNotEmpty) {
      return getImageUrlFromValue(images.first);
    }

    return null;
  }

  bool get hasActiveAdvancedFilter {
    return minPrice != null ||
        maxPrice != null ||
        selectedKostFacilities.isNotEmpty ||
        selectedRoomFacilities.isNotEmpty ||
        selectedOrder != SearchOrder.rekomendasi;
  }

  bool get hasAnyFilter {
    return searchKeyword.trim().isNotEmpty ||
        selectedPriceType != SearchPriceType.semua ||
        hasActiveAdvancedFilter;
  }

  List<Map<String, dynamic>> get filteredKosList {
    List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
      kosList,
    );

    final keyword = searchKeyword.trim().toLowerCase();

    if (keyword.isNotEmpty) {
      result = result.where((kos) {
        final title = getKosTitle(kos).toLowerCase();
        final address = getKosAddress(kos).toLowerCase();
        final city = getKosCity(kos).toLowerCase();
        final description = getKosDescription(kos).toLowerCase();
        final facilities = getAllFacilities(kos).join(' ').toLowerCase();

        return title.contains(keyword) ||
            address.contains(keyword) ||
            city.contains(keyword) ||
            description.contains(keyword) ||
            facilities.contains(keyword);
      }).toList();
    }

    if (selectedPriceType != SearchPriceType.semua) {
      result = result.where((kos) {
        final price = getPriceByType(kos, selectedPriceType);

        return price != null && price > 0;
      }).toList();
    }

    if (minPrice != null || maxPrice != null) {
      result = result.where((kos) {
        final price = getPriceByType(kos, selectedPriceType);

        if (price == null || price <= 0) return false;

        if (minPrice != null && price < minPrice!) return false;

        if (maxPrice != null && price > maxPrice!) return false;

        return true;
      }).toList();
    }

    if (selectedKostFacilities.isNotEmpty ||
        selectedRoomFacilities.isNotEmpty) {
      result = result.where((kos) {
        final kosFacilities = getAllFacilities(kos)
            .map((item) => normalizeFacility(item))
            .where((item) => item.isNotEmpty)
            .toSet();

        final selectedFacilities =
            [...selectedKostFacilities, ...selectedRoomFacilities]
                .map((item) => normalizeFacility(item))
                .where((item) => item.isNotEmpty)
                .toSet();

        if (selectedFacilities.isEmpty) return true;

        return selectedFacilities.any((selectedFacility) {
          return kosFacilities.contains(selectedFacility);
        });
      }).toList();
    }

    if (selectedOrder == SearchOrder.termurah) {
      result.sort((a, b) {
        final priceA = getPriceByType(a, selectedPriceType) ?? 999999999;
        final priceB = getPriceByType(b, selectedPriceType) ?? 999999999;

        return priceA.compareTo(priceB);
      });
    }

    if (selectedOrder == SearchOrder.termahal) {
      result.sort((a, b) {
        final priceA = getPriceByType(a, selectedPriceType) ?? 0;
        final priceB = getPriceByType(b, selectedPriceType) ?? 0;

        return priceB.compareTo(priceA);
      });
    }

    if (selectedOrder == SearchOrder.terbaru) {
      result.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at']?.toString() ?? "") ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['created_at']?.toString() ?? "") ??
            DateTime(2000);

        return dateB.compareTo(dateA);
      });
    }

    if (selectedOrder == SearchOrder.terlengkap) {
      result.sort((a, b) {
        final scoreA = getImageCount(a) + getAllFacilities(a).length;
        final scoreB = getImageCount(b) + getAllFacilities(b).length;

        return scoreB.compareTo(scoreA);
      });
    }

    return result;
  }

  Future<void> refreshData() async {
    await loadKosFromApi();
  }

  void resetAllFilter() {
    setState(() {
      searchKeyword = "";
      searchController.clear();
      selectedPriceType = SearchPriceType.semua;
      selectedOrder = SearchOrder.rekomendasi;
      minPrice = null;
      maxPrice = null;
      selectedKostFacilities.clear();
      selectedRoomFacilities.clear();
    });
  }

  Future<void> openDetailPage(Map<String, dynamic> kos) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKosPage(kos: Map<String, dynamic>.from(kos)),
      ),
    );

    if (!mounted) return;

    loadKosFromApi();
  }

  Widget buildFacilityFilterSection({
    required String title,
    required IconData icon,
    required List<String> options,
    required Set<String> selectedItems,
    required StateSetter setModalState,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _softBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primaryColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((facility) {
              final active = selectedItems.contains(facility);

              return FilterChip(
                selected: active,
                label: Text(
                  facility,
                  style: TextStyle(
                    color: active ? Colors.white : _primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: Colors.white,
                selectedColor: _primaryColor,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: active ? _primaryColor : Colors.grey.shade200,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                onSelected: (value) {
                  setModalState(() {
                    if (value) {
                      selectedItems.add(facility);
                    } else {
                      selectedItems.remove(facility);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> openFilterSheet() async {
    SearchOrder tempOrder = selectedOrder;

    final Set<String> tempKostFacilities = Set<String>.from(
      selectedKostFacilities,
    );

    final Set<String> tempRoomFacilities = Set<String>.from(
      selectedRoomFacilities,
    );

    final minController = TextEditingController(
      text: formatRupiahInput(minPrice),
    );

    final maxController = TextEditingController(
      text: formatRupiahInput(maxPrice),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.86,
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primaryColor, _secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Filter Pencarian",
                              style: TextStyle(
                                color: _darkText,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Urutkan Berdasarkan",
                        style: TextStyle(
                          color: _darkText,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SearchOrder.values.map((order) {
                          final active = tempOrder == order;

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                tempOrder = order;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: active ? _primaryColor : _softBlue,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                getOrderLabel(order),
                                style: TextStyle(
                                  color: active ? Colors.white : _primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "Range Harga",
                        style: TextStyle(
                          color: _darkText,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedPriceType == SearchPriceType.semua
                            ? "Range mengikuti harga utama kos."
                            : "Range mengikuti harga ${getPriceTypeLabel(selectedPriceType).toLowerCase()}.",
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [RupiahInputFormatter()],
                              decoration: InputDecoration(
                                labelText: "Harga minimum",
                                hintText: "Rp. 100.000",
                                filled: true,
                                fillColor: _softBlue,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: maxController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [RupiahInputFormatter()],
                              decoration: InputDecoration(
                                labelText: "Harga maksimum",
                                hintText: "Rp. 1.500.000",
                                filled: true,
                                fillColor: _softBlue,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Fasilitas",
                              style: TextStyle(
                                color: _darkText,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (tempKostFacilities.isNotEmpty ||
                              tempRoomFacilities.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  tempKostFacilities.clear();
                                  tempRoomFacilities.clear();
                                });
                              },
                              child: const Text(
                                "Hapus fasilitas",
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      buildFacilityFilterSection(
                        title: "Fasilitas Kost",
                        icon: Icons.maps_home_work_outlined,
                        options: kostFacilityOptions,
                        selectedItems: tempKostFacilities,
                        setModalState: setModalState,
                      ),
                      buildFacilityFilterSection(
                        title: "Fasilitas Kamar",
                        icon: Icons.bed_outlined,
                        options: roomFacilityOptions,
                        selectedItems: tempRoomFacilities,
                        setModalState: setModalState,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryColor,
                                side: const BorderSide(color: _primaryColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  tempOrder = SearchOrder.rekomendasi;
                                  tempKostFacilities.clear();
                                  tempRoomFacilities.clear();
                                  minController.clear();
                                  maxController.clear();
                                });
                              },
                              child: const Text(
                                "Reset",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();

                                setState(() {
                                  selectedOrder = tempOrder;

                                  selectedKostFacilities = Set<String>.from(
                                    tempKostFacilities,
                                  );

                                  selectedRoomFacilities = Set<String>.from(
                                    tempRoomFacilities,
                                  );

                                  minPrice = parsePriceInput(
                                    minController.text,
                                  );

                                  maxPrice = parsePriceInput(
                                    maxController.text,
                                  );
                                });

                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                "Terapkan",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 120));

    minController.dispose();
    maxController.dispose();
  }

  Widget buildKosImage(
    Map<String, dynamic> kos, {
    required double height,
    required double width,
  }) {
    final imageUrl = getKosImage(kos);

    if (imageUrl == null) {
      return Image.asset(
        "assets/cover1.png",
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: height,
      width: width,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: height,
          width: width,
          color: _softBlue,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          "assets/cover1.png",
          height: height,
          width: width,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget buildHeader() {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -18,
            top: -28,
            child: Container(
              width: 142,
              height: 142,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 22,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -34,
            bottom: -54,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Pencarian Kos",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: openFilterSheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                          if (hasActiveAdvancedFilter)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                "Cari kos yang paling cocok\nbuat kebutuhanmu",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: _primaryColor,
                      size: 25,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        cursorColor: _primaryColor,
                        onChanged: (value) {
                          setState(() {
                            searchKeyword = value;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: "Cari nama, alamat, kota, fasilitas",
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: const TextStyle(
                          color: _darkText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (searchKeyword.trim().isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          searchController.clear();

                          setState(() {
                            searchKeyword = "";
                          });
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _softBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildPriceTypeSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          buildPriceTypeChip(
            type: SearchPriceType.semua,
            icon: Icons.home_work_rounded,
            label: "Semua",
          ),
          buildPriceTypeChip(
            type: SearchPriceType.malam,
            icon: Icons.nights_stay_rounded,
            label: "Per Malam",
          ),
          buildPriceTypeChip(
            type: SearchPriceType.minggu,
            icon: Icons.date_range_rounded,
            label: "Per Minggu",
          ),
          buildPriceTypeChip(
            type: SearchPriceType.bulan,
            icon: Icons.calendar_month_rounded,
            label: "Per Bulan",
          ),
          buildPriceTypeChip(
            type: SearchPriceType.tahun,
            icon: Icons.event_available_rounded,
            label: "Per Tahun",
          ),
        ],
      ),
    );
  }

  Widget buildPriceTypeChip({
    required SearchPriceType type,
    required IconData icon,
    required String label,
  }) {
    final active = selectedPriceType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPriceType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: active
                  ? _primaryColor.withOpacity(0.22)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : _primaryColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _darkText,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActiveFilterInfo() {
    if (!hasAnyFilter) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _primaryColor, size: 21),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Mode semua aktif. Semua kos yang tersedia akan muncul di sini.",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<String> filterTexts = [];

    if (searchKeyword.trim().isNotEmpty) {
      filterTexts.add("Kata kunci: ${searchKeyword.trim()}");
    }

    if (selectedPriceType != SearchPriceType.semua) {
      filterTexts.add("Harga: ${getPriceTypeLabel(selectedPriceType)}");
    }

    if (minPrice != null || maxPrice != null) {
      final minText = minPrice == null ? "0" : formatRupiah(minPrice!);
      final maxText = maxPrice == null ? "∞" : formatRupiah(maxPrice!);

      filterTexts.add("Range: $minText - $maxText");
    }

    final totalSelectedFacilities =
        selectedKostFacilities.length + selectedRoomFacilities.length;

    if (totalSelectedFacilities > 0) {
      filterTexts.add("Fasilitas: $totalSelectedFacilities dipilih");
    }

    if (selectedOrder != SearchOrder.rekomendasi) {
      filterTexts.add("Sortir: ${getOrderLabel(selectedOrder)}");
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              color: _primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              filterTexts.join(" • "),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: resetAllFilter,
            child: const Text(
              "Reset",
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLoadingList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(4, (index) {
          return Container(
            height: 158,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }),
      ),
    );
  }

  Widget buildEmptyResult() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _primaryColor,
              size: 44,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "Kos tidak ditemukan",
            style: TextStyle(
              color: _darkText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Coba ubah kata kunci, jenis harga, range harga, atau fasilitas yang dipilih.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResultHeader() {
    final data = filteredKosList;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedPriceType == SearchPriceType.semua
                  ? "Semua Kos"
                  : "Kos ${getPriceTypeLabel(selectedPriceType)}",
              style: const TextStyle(
                color: _darkText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "${data.length} kos",
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResultList() {
    final data = filteredKosList;

    if (loadingKos) {
      return buildLoadingList();
    }

    if (data.isEmpty) {
      return buildEmptyResult();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: ValueKey(
          "${selectedPriceType.name}-${selectedOrder.name}-$searchKeyword-${data.length}-${selectedKostFacilities.length}-${selectedRoomFacilities.length}-$minPrice-$maxPrice",
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final kos = data[index];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 360 + (index * 45)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0).toDouble(),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: SearchKosCard(
              kos: kos,
              title: getKosTitle(kos),
              address: getKosAddress(kos),
              city: getKosCity(kos),
              price: getKosPrice(kos),
              rating: getRatingValue(kos),
              facilities: getAllFacilities(kos),
              imageBuilder: (item) {
                return buildKosImage(item, height: 142, width: 118);
              },
              onTap: () {
                openDetailPage(kos);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshData,
          color: _primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: buildHeader(),
                ),
                const SizedBox(height: 18),
                buildPriceTypeSection(),
                const SizedBox(height: 16),
                buildActiveFilterInfo(),
                const SizedBox(height: 22),
                buildResultHeader(),
                const SizedBox(height: 14),
                buildResultList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchKosCard extends StatelessWidget {
  final Map<String, dynamic> kos;
  final String title;
  final String address;
  final String city;
  final String price;
  final double rating;
  final List<String> facilities;
  final Widget Function(Map<String, dynamic>) imageBuilder;
  final VoidCallback onTap;

  const SearchKosCard({
    super.key,
    required this.kos,
    required this.title,
    required this.address,
    required this.city,
    required this.price,
    required this.rating,
    required this.facilities,
    required this.imageBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shownFacilities = facilities.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.09),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            splashColor: _primaryColor.withOpacity(0.08),
            highlightColor: _primaryColor.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 118,
                          height: 142,
                          child: imageBuilder(kos),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.50),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating == 0
                                      ? "Baru"
                                      : rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: SizedBox(
                      height: 142,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _darkText,
                              fontSize: 15,
                              height: 1.18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: _primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          if (shownFacilities.isNotEmpty)
                            SizedBox(
                              height: 24,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: shownFacilities.length,
                                separatorBuilder: (context, index) {
                                  return const SizedBox(width: 5);
                                },
                                itemBuilder: (context, index) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _softBlue,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      shownFacilities[index],
                                      style: const TextStyle(
                                        color: _primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            const SizedBox(height: 24),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _softBlue,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    price,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _primaryColor,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  String _formatDigits(String digits) {
    final number = int.tryParse(digits);

    if (number == null) return "";

    final formattedNumber = number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp. $formattedNumber";
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: "",
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }

    final formatted = _formatDigits(digits);

    if (formatted.isEmpty) {
      return const TextEditingValue(
        text: "",
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}
