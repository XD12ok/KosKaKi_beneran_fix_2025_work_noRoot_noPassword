import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:koskaki/service/api_service.dart';

class EditKostPage extends StatefulWidget {
  final Map<String, dynamic> kost;

  const EditKostPage({super.key, required this.kost});

  @override
  State<EditKostPage> createState() => _EditKostPageState();
}

class _EditKostPageState extends State<EditKostPage> {
  bool isLoading = false;

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  late TextEditingController titleC;
  late TextEditingController descC;
  late TextEditingController addressC;
  late TextEditingController maxPeopleC;

  late TextEditingController nightC;
  late TextEditingController weekC;
  late TextEditingController monthC;
  late TextEditingController yearC;

  List<String> kostFeatures = [];
  List<String> roomFeatures = [];

  List<String> customKostFeatures = [];
  List<String> customRoomFeatures = [];

  List<String> originalKostFeatures = [];
  List<String> originalRoomFeatures = [];

  List<Map<String, dynamic>> originalKostFeatureObjects = [];
  List<Map<String, dynamic>> originalRoomFeatureObjects = [];

  List<Map<String, dynamic>> kostPolicies = [];
  List<Map<String, dynamic>> roomPolicies = [];

  List<Map<String, dynamic>> originalKostPolicyObjects = [];
  List<Map<String, dynamic>> originalRoomPolicyObjects = [];

  List<Map<String, dynamic>> allNearbyPlaces = [];
  List<Map<String, dynamic>> selectedNearbyPlaces = [];
  List<Map<String, dynamic>> originalNearbyPlaceObjects = [];

  bool isNearbyLoading = false;

  bool isCityLoading = false;
  List<Map<String, dynamic>> cities = [];
  int? selectedCityId;

  bool isLoadingPlaces = false;
  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? selectedNearbyPlace;
  final TextEditingController nearbyDistanceController =
      TextEditingController();

  List<Map<String, dynamic>> existingImages = [];
  List<Map<String, dynamic>> removedExistingImages = [];
  List<File> newImages = [];

  final List<String> kostFeatureOptions = [
    "WiFi",
    "CCTV",
    "Parkir Motor",
    "Parkir Mobil",
    "Dapur Bersama",
    "Laundry",
    "Ruang Tamu",
    "Keamanan 24 Jam",
    "Mushola",
  ];

  final List<String> roomFeatureOptions = [
    "AC",
    "TV",
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

    final k = widget.kost;

    selectedCityId = getInitialCityId(k);
    existingImages = extractExistingImageList(k);
    loadCities();

    titleC = TextEditingController(text: k['title']?.toString() ?? '');

    descC = TextEditingController(text: k['description']?.toString() ?? '');

    addressC = TextEditingController(text: k['address']?.toString() ?? '');

    maxPeopleC = TextEditingController(text: k['max_people']?.toString() ?? '');

    nightC = TextEditingController(
      text: formatNumber(
        getInitialPriceValue([
          'price_perNight',
          'price_per_night',
          'night_price',
          'price_night',
        ]),
      ),
    );

    weekC = TextEditingController(
      text: formatNumber(
        getInitialPriceValue([
          'price_perWeek',
          'price_per_week',
          'week_price',
          'price_week',
        ]),
      ),
    );

    monthC = TextEditingController(
      text: formatNumber(
        getInitialPriceValue([
          'price_perMonth',
          'price_per_month',
          'month_price',
          'price_month',
        ]),
      ),
    );

    yearC = TextEditingController(
      text: formatNumber(
        getInitialPriceValue([
          'price_perYear',
          'price_per_year',
          'year_price',
          'price_year',
        ]),
      ),
    );

    originalKostFeatureObjects = _parseObjectList(
      k['kost_features'] ?? k['kost_facilities'] ?? k['property_features'],
    );

    originalRoomFeatureObjects = _parseObjectList(
      k['place_features'] ?? k['room_facilities'] ?? k['features'],
    );

    kostFeatures = _parseStringList(
      k['kost_features'] ?? k['kost_facilities'] ?? k['property_features'],
    );

    roomFeatures = _parseStringList(
      k['place_features'] ?? k['room_facilities'] ?? k['features'],
    );

    originalKostFeatures = List<String>.from(kostFeatures);
    originalRoomFeatures = List<String>.from(roomFeatures);

    customKostFeatures = kostFeatures
        .where((item) => !kostFeatureOptions.contains(item))
        .toList();

    customRoomFeatures = roomFeatures
        .where((item) => !roomFeatureOptions.contains(item))
        .toList();

    final rawKostPolicies = _parsePolicyList(
      k['kost_policies'] ?? k['kost_rules'] ?? k['property_policies'],
    );

    final rawRoomPolicies = _parsePolicyList(
      k['place_policies'] ?? k['room_rules'] ?? k['policies'],
    );

    originalKostPolicyObjects = List<Map<String, dynamic>>.from(
      rawKostPolicies,
    );

    originalRoomPolicyObjects = List<Map<String, dynamic>>.from(
      rawRoomPolicies,
    );

    kostPolicies = rawKostPolicies.map((item) {
      return _policyToControllerMap(item);
    }).toList();

    roomPolicies = rawRoomPolicies.map((item) {
      return _policyToControllerMap(item);
    }).toList();

    if (kostPolicies.isEmpty) {
      kostPolicies.add(_emptyPolicyControllerMap());
    }

    if (roomPolicies.isEmpty) {
      roomPolicies.add(_emptyPolicyControllerMap());
    }

    originalNearbyPlaceObjects = parseNearbyPlaceList(
      k['nearby_places'] ??
          k['nearbyPlaces'] ??
          k['nearby'] ??
          k['property_nearby_places'],
    );

    selectedNearbyPlaces = originalNearbyPlaceObjects
        .map(nearbyToSelectedMap)
        .where((item) => cleanTextValue(item['id']).isNotEmpty)
        .toList();

    selectedNearbyPlaces = removeDuplicateNearbyPlaces(selectedNearbyPlaces);
    syncNearbyDropdownFromSelectedList(force: true);

    fetchNearbyPlaceOptions();
    fetchCurrentNearbyPlaces();

    if (selectedCityId != null) {
      loadPlacesByCity(selectedCityId!, keepSelected: true);
    }
  }

  @override
  void dispose() {
    titleC.dispose();
    descC.dispose();
    addressC.dispose();
    maxPeopleC.dispose();

    nightC.dispose();
    weekC.dispose();
    monthC.dispose();
    yearC.dispose();
    nearbyDistanceController.dispose();

    for (final item in kostPolicies) {
      (item["titleC"] as TextEditingController?)?.dispose();
      (item["descC"] as TextEditingController?)?.dispose();
    }

    for (final item in roomPolicies) {
      (item["titleC"] as TextEditingController?)?.dispose();
      (item["descC"] as TextEditingController?)?.dispose();
    }

    super.dispose();
  }

  int? getInitialCityId(Map<String, dynamic> source) {
    final direct =
        source['city_id'] ??
        source['cityId'] ??
        source['id_city'] ??
        source['kota_id'];

    final fromDirect = parseNullableInt(direct);

    if (fromDirect != null) return fromDirect;

    final city = source['city'] ?? source['kota'];

    if (city is Map) {
      return parseNullableInt(city['id']);
    }

    return null;
  }

  int? parseNullableInt(dynamic value) {
    if (value == null) return null;

    final text = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  Future<void> loadCities() async {
    try {
      if (mounted) {
        setState(() {
          isCityLoading = true;
        });
      }

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/cities"),
        headers: const {'Accept': 'application/json'},
      );

      print("EDIT CITY STATUS:");
      print(response.statusCode);

      print("EDIT CITY BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> cityData = [];

        if (decoded is List) {
          cityData = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          cityData = decoded['data'];
        } else if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          cityData = decoded['data']['data'];
        }

        if (!mounted) return;

        setState(() {
          cities = cityData.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
        });
      } else {
        showMessage("Gagal mengambil data kota");
      }
    } catch (e) {
      print("EDIT LOAD CITY ERROR:");
      print(e);
      showMessage("Error mengambil kota: $e");
    } finally {
      if (mounted) {
        setState(() {
          isCityLoading = false;
        });
      }
    }
  }

  Future<void> loadPlacesByCity(int cityId, {bool keepSelected = false}) async {
    if (!mounted) return;

    final previousSelectedId = cleanTextValue(
      selectedNearbyPlace?['id'] ??
          (selectedNearbyPlaces.isNotEmpty
              ? selectedNearbyPlaces.first['id']
              : null),
    );

    setState(() {
      isLoadingPlaces = true;
      places = [];

      if (!keepSelected) {
        selectedNearbyPlace = null;
        nearbyDistanceController.clear();
        selectedNearbyPlaces = [];
      }
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/cities/$cityId/places"),
        headers: const {'Accept': 'application/json'},
      );

      print("EDIT PLACES BY CITY STATUS:");
      print(response.statusCode);

      print("EDIT PLACES BY CITY BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> placeData = [];

        if (decoded is List) {
          placeData = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          placeData = decoded['data'];
        } else if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          placeData = decoded['data']['data'];
        } else {
          placeData = parseNearbyPlaceList(decoded);
        }

        final parsedPlaces = placeData
            .map<Map<String, dynamic>>((item) {
              if (item is Map) {
                return nearbyToSelectedMap(Map<String, dynamic>.from(item));
              }

              return {
                "id": "",
                "name": item.toString(),
                "type": "",
                "distance": "",
              };
            })
            .where((item) => cleanTextValue(item['id']).isNotEmpty)
            .toList();

        if (!mounted) return;

        setState(() {
          places = removeDuplicateNearbyPlaces(parsedPlaces);

          if (keepSelected && previousSelectedId.isNotEmpty) {
            Map<String, dynamic>? matched;

            for (final item in places) {
              if (cleanTextValue(item['id']) == previousSelectedId) {
                matched = item;
                break;
              }
            }

            if (matched != null) {
              final oldDistance = selectedNearbyPlaces.isNotEmpty
                  ? normalizeDistanceValue(
                      selectedNearbyPlaces.first['distance'],
                    )
                  : normalizeDistanceValue(nearbyDistanceController.text);

              selectedNearbyPlace = Map<String, dynamic>.from(matched);

              if (oldDistance.isNotEmpty) {
                nearbyDistanceController.text = oldDistance;
              }
            }
          }
        });
      } else {
        showMessage("Gagal mengambil data tempat");
      }
    } catch (e) {
      print("EDIT LOAD PLACES ERROR:");
      print(e);
      showMessage("Error mengambil tempat: $e");
    }

    if (!mounted) return;

    setState(() {
      isLoadingPlaces = false;
    });
  }

  String cleanDistance(String value) {
    String result = value
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');

    final parts = result.split('.');

    if (parts.length > 2) {
      result = '${parts.first}.${parts.skip(1).join()}';
    }

    return result;
  }

  String getPlaceName(Map<String, dynamic> item) {
    return item['name']?.toString() ??
        item['title']?.toString() ??
        item['place_name']?.toString() ??
        item['nama']?.toString() ??
        "-";
  }

  String getPlaceType(Map<String, dynamic> item) {
    return item['type']?.toString() ??
        item['category']?.toString() ??
        item['place_type']?.toString() ??
        item['kategori']?.toString() ??
        "";
  }

  void syncNearbyDropdownFromSelectedList({bool force = false}) {
    if (selectedNearbyPlaces.isEmpty) {
      if (force) {
        selectedNearbyPlace = null;
        nearbyDistanceController.clear();
      }

      return;
    }

    final first = selectedNearbyPlaces.first;
    final id = cleanTextValue(first['id']);
    final distance = normalizeDistanceValue(first['distance']);

    Map<String, dynamic>? matched;

    for (final place in places) {
      if (cleanTextValue(place['id']) == id) {
        matched = place;
        break;
      }
    }

    if (force || selectedNearbyPlace == null) {
      selectedNearbyPlace = Map<String, dynamic>.from(matched ?? first);
    }

    nearbyDistanceController.text = distance;
  }

  void syncSingleNearbySelection() {
    final place = selectedNearbyPlace;
    final distance = cleanDistance(nearbyDistanceController.text.trim());

    if (place == null) {
      selectedNearbyPlaces = [];
      return;
    }

    final placeId = cleanTextValue(place['id']);

    if (placeId.isEmpty) {
      selectedNearbyPlaces = [];
      return;
    }

    selectedNearbyPlaces = [
      {
        "id": placeId,
        "name": getPlaceName(place),
        "type": getPlaceType(place),
        "distance": distance,
      },
    ];
  }

  List<Map<String, dynamic>> extractExistingImageList(
    Map<String, dynamic> source,
  ) {
    final List<Map<String, dynamic>> result = [];

    void addImage(dynamic value, {bool isMain = false}) {
      if (value == null) return;

      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final url = getImageUrlFromDynamic(map);

        if (url.trim().isEmpty) return;

        final image = {
          "id":
              map['id'] ??
              map['image_id'] ??
              map['property_image_id'] ??
              map['kost_image_id'],
          "url": url,
          "raw": map,
          "is_main": isMain,
        };

        result.add(image);
        return;
      }

      final url = getImageUrlFromDynamic(value);

      if (url.trim().isEmpty) return;

      result.add({"id": null, "url": url, "raw": value, "is_main": isMain});
    }

    addImage(source['main_image'], isMain: true);
    addImage(source['image'], isMain: result.isEmpty);
    addImage(source['thumbnail'], isMain: false);

    final imageSources = [
      source['images'],
      source['property_images'],
      source['kost_images'],
      source['photos'],
    ];

    for (final item in imageSources) {
      if (item is List) {
        for (final image in item) {
          addImage(image);
        }
      }
    }

    final List<Map<String, dynamic>> unique = [];
    final Set<String> keys = {};

    for (final image in result) {
      final id = cleanTextValue(image['id']);
      final url = cleanTextValue(image['url']);
      final key = id.isNotEmpty ? "id:$id" : "url:$url";

      if (url.isEmpty || keys.contains(key)) continue;

      keys.add(key);
      unique.add(image);
    }

    return unique.take(15).toList();
  }

  String getImageUrlFromDynamic(dynamic img) {
    String url = "";

    final baseUrlWithoutApi = ApiService.baseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );

    if (img == null) return "";

    if (img is String) {
      url = img;
    } else if (img is Map) {
      final map = Map<String, dynamic>.from(img);

      final fullImageUrl = map['full_image_url']?.toString() ?? "";

      if (fullImageUrl.isNotEmpty &&
          fullImageUrl.startsWith("http") &&
          !fullImageUrl.endsWith("/storage")) {
        url = fullImageUrl;
      } else {
        url =
            map['url']?.toString() ??
            map['image']?.toString() ??
            map['image_url']?.toString() ??
            map['path']?.toString() ??
            map['image_path']?.toString() ??
            map['file']?.toString() ??
            map['filename']?.toString() ??
            "";
      }
    }

    if (url.isEmpty || url == "null") return "";

    url = url.replaceAll('\\\\', '/');

    if (url.startsWith("http")) return url;

    if (url.startsWith("/storage")) {
      return "$baseUrlWithoutApi$url";
    }

    if (url.startsWith("storage")) {
      return "$baseUrlWithoutApi/$url";
    }

    return "$baseUrlWithoutApi/storage/$url";
  }

  Future<void> pickImage() async {
    try {
      final pickedImages = await ImagePicker().pickMultiImage();

      if (pickedImages.isEmpty) return;

      final totalImage =
          existingImages.length + newImages.length + pickedImages.length;

      if (totalImage > 15) {
        showMessage("Maksimal 15 gambar");
        return;
      }

      final List<File> compressedImages = [];

      for (final picked in pickedImages) {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          picked.path,
          "${picked.path}_compressed.jpg",
          quality: 60,
        );

        if (compressed != null) {
          compressedImages.add(File(compressed.path));
        } else {
          compressedImages.add(File(picked.path));
        }
      }

      if (!mounted) return;

      setState(() {
        newImages.addAll(compressedImages);
      });
    } catch (e) {
      print("PICK EDIT IMAGE ERROR:");
      print(e);
      showMessage("Gagal memilih gambar: $e");
    }
  }

  void removeExistingImage(int index) {
    if (index < 0 || index >= existingImages.length) return;

    setState(() {
      final removed = existingImages.removeAt(index);
      removedExistingImages.add(removed);
    });
  }

  void removeNewImage(int index) {
    if (index < 0 || index >= newImages.length) return;

    setState(() {
      newImages.removeAt(index);
    });
  }

  List<String> removedImageIds() {
    return removedExistingImages
        .map((item) => cleanTextValue(item['id']))
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<bool> deleteRemovedExistingImages({
    required String propertyId,
    required String token,
  }) async {
    final ids = removedImageIds();

    if (ids.isEmpty) return true;

    bool success = true;

    for (final imageId in ids) {
      final endpoints = [
        "${ApiService.baseUrl}/properties/$propertyId/images/$imageId",
        "${ApiService.baseUrl}/property-images/$imageId",
        "${ApiService.baseUrl}/images/$imageId",
      ];

      bool deleted = false;

      for (final endpoint in endpoints) {
        try {
          final response = await http.delete(
            Uri.parse(endpoint),
            headers: {
              "Authorization": "Bearer $token",
              "Accept": "application/json",
            },
          );

          print("DELETE EDIT IMAGE ENDPOINT:");
          print(endpoint);
          print("DELETE EDIT IMAGE STATUS:");
          print(response.statusCode);
          print("DELETE EDIT IMAGE BODY:");
          print(response.body);

          if (isSuccessStatus(response.statusCode)) {
            deleted = true;
            break;
          }
        } catch (e) {
          print("DELETE EDIT IMAGE ERROR:");
          print(endpoint);
          print(e);
        }
      }

      if (!deleted) success = false;
    }

    return success;
  }

  Future<bool> uploadNewImages({
    required String propertyId,
    required String token,
  }) async {
    if (newImages.isEmpty) return true;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/images"),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      for (final image in newImages) {
        request.files.add(
          await http.MultipartFile.fromPath('images[]', image.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("UPLOAD EDIT IMAGE STATUS:");
      print(response.statusCode);
      print("UPLOAD EDIT IMAGE BODY:");
      print(response.body);

      if (isSuccessStatus(response.statusCode)) {
        return true;
      }

      return false;
    } catch (e) {
      print("UPLOAD EDIT IMAGE ERROR:");
      print(e);
      return false;
    }
  }

  dynamic getInitialPriceValue(List<String> keys) {
    final k = widget.kost;

    final fromMain = findFirstValueFromMap(k, keys);

    if (fromMain != null) return fromMain;

    final nestedKeys = [
      'place_property',
      'placeProperty',
      'place_properties',
      'placeProperties',
      'places',
      'place',
      'room',
      'rooms',
    ];

    for (final nestedKey in nestedKeys) {
      final nestedValue = k[nestedKey];
      final found = findFirstValueDeep(nestedValue, keys);

      if (found != null) return found;
    }

    return 0;
  }

  dynamic findFirstValueFromMap(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }

    return null;
  }

  dynamic findFirstValueDeep(dynamic source, List<String> keys) {
    if (source == null) return null;

    if (source is Map) {
      final direct = findFirstValueFromMap(source, keys);

      if (direct != null) return direct;

      for (final value in source.values) {
        final found = findFirstValueDeep(value, keys);

        if (found != null) return found;
      }
    }

    if (source is List) {
      for (final item in source) {
        final found = findFirstValueDeep(item, keys);

        if (found != null) return found;
      }
    }

    return null;
  }

  String normalizePriceValue(dynamic value) {
    if (value == null) return "0";

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return "0";

    text = text.replaceAll("Rp", "").replaceAll(" ", "");

    // Kalau backend mengirim decimal seperti 1000000.00,
    // angka di belakang titik tidak boleh ikut menjadi 100000000.
    if (RegExp(r'^\d+[\.,]\d{1,2}$').hasMatch(text)) {
      text = text.split(RegExp(r'[\.,]')).first;
    }

    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return "0";

    return (int.tryParse(digits) ?? 0).toString();
  }

  String formatNumber(dynamic value) {
    final number = normalizePriceValue(value);

    if (number == "0") return "0";

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

  String cleanPrice(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return "0";

    return (int.tryParse(digits) ?? 0).toString();
  }

  Map<String, String> buildPricePayload() {
    final nightPrice = cleanPrice(nightC.text);
    final weekPrice = cleanPrice(weekC.text);
    final monthPrice = cleanPrice(monthC.text);
    final yearPrice = cleanPrice(yearC.text);

    return {
      "price_perNight": nightPrice,
      "price_perWeek": weekPrice,
      "price_perMonth": monthPrice,
      "price_perYear": yearPrice,

      "price_per_night": nightPrice,
      "price_per_week": weekPrice,
      "price_per_month": monthPrice,
      "price_per_year": yearPrice,

      "night_price": nightPrice,
      "week_price": weekPrice,
      "month_price": monthPrice,
      "year_price": yearPrice,
    };
  }

  bool isSuccessStatus(int statusCode) {
    return statusCode == 200 || statusCode == 201 || statusCode == 204;
  }

  Future<bool> sendPriceRequest({
    required String endpoint,
    required String token,
    required Map<String, String> priceBody,
  }) async {
    final jsonHeaders = {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
      "Content-Type": "application/json",
    };

    final formHeaders = {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    };

    try {
      final putJson = await http.put(
        Uri.parse(endpoint),
        headers: jsonHeaders,
        body: jsonEncode(priceBody),
      );

      print("UPDATE HARGA PUT JSON ENDPOINT:");
      print(endpoint);
      print("UPDATE HARGA PUT JSON STATUS:");
      print(putJson.statusCode);
      print("UPDATE HARGA PUT JSON RESPONSE:");
      print(putJson.body);

      if (isSuccessStatus(putJson.statusCode)) return true;

      final patchJson = await http.patch(
        Uri.parse(endpoint),
        headers: jsonHeaders,
        body: jsonEncode(priceBody),
      );

      print("UPDATE HARGA PATCH JSON ENDPOINT:");
      print(endpoint);
      print("UPDATE HARGA PATCH JSON STATUS:");
      print(patchJson.statusCode);
      print("UPDATE HARGA PATCH JSON RESPONSE:");
      print(patchJson.body);

      if (isSuccessStatus(patchJson.statusCode)) return true;

      final postPutForm = await http.post(
        Uri.parse(endpoint),
        headers: formHeaders,
        body: {"_method": "PUT", ...priceBody},
      );

      print("UPDATE HARGA POST _METHOD PUT ENDPOINT:");
      print(endpoint);
      print("UPDATE HARGA POST _METHOD PUT STATUS:");
      print(postPutForm.statusCode);
      print("UPDATE HARGA POST _METHOD PUT RESPONSE:");
      print(postPutForm.body);

      if (isSuccessStatus(postPutForm.statusCode)) return true;

      final postPatchForm = await http.post(
        Uri.parse(endpoint),
        headers: formHeaders,
        body: {"_method": "PATCH", ...priceBody},
      );

      print("UPDATE HARGA POST _METHOD PATCH ENDPOINT:");
      print(endpoint);
      print("UPDATE HARGA POST _METHOD PATCH STATUS:");
      print(postPatchForm.statusCode);
      print("UPDATE HARGA POST _METHOD PATCH RESPONSE:");
      print(postPatchForm.body);

      if (isSuccessStatus(postPatchForm.statusCode)) return true;
    } catch (e) {
      print("UPDATE HARGA ERROR ENDPOINT:");
      print(endpoint);
      print(e);
    }

    return false;
  }

  Future<bool> updatePriceWithoutChangingBackend({
    required String propertyId,
    required String placeId,
    required String token,
    required Map<String, String> priceBody,
  }) async {
    final endpoints = <String>{
      "${ApiService.baseUrl}/properties/$propertyId",
      "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId",
      "${ApiService.baseUrl}/place-properties/$placeId",
      "${ApiService.baseUrl}/places/$placeId",
    }.toList();

    bool success = false;

    for (final endpoint in endpoints) {
      final updated = await sendPriceRequest(
        endpoint: endpoint,
        token: token,
        priceBody: priceBody,
      );

      if (updated) {
        success = true;
      }
    }

    return success;
  }

  List<Map<String, dynamic>> _parseObjectList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map<Map<String, dynamic>>((e) {
        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }

        return {"feature": e.toString()};
      }).toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return _parseObjectList(decoded);
        }
      } catch (_) {}

      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map<Map<String, dynamic>>((e) {
            return {"feature": e};
          })
          .toList();
    }

    return [];
  }

  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) {
            if (e is Map) {
              return e['feature']?.toString() ??
                  e['name']?.toString() ??
                  e['title']?.toString() ??
                  "";
            }

            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (value is String) {
      if (value.trim().isEmpty) return [];

      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return _parseStringList(decoded);
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

  List<Map<String, dynamic>> _parsePolicyList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map<Map<String, dynamic>>((e) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(e);

          final title = map['title']?.toString() ?? "";
          final description = map['description']?.toString() ?? "";
          final desc = map['desc']?.toString() ?? "";
          final policy = map['policy']?.toString() ?? "";

          if (title.isEmpty && policy.isNotEmpty) {
            map['title'] = "Aturan";
          }

          if (description.isEmpty && desc.isEmpty && policy.isNotEmpty) {
            map['description'] = policy;
          }

          return map;
        }

        return {"title": "Aturan", "description": e.toString()};
      }).toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return _parsePolicyList(decoded);
        }
      } catch (_) {}

      return [
        {"title": "Aturan", "description": value},
      ];
    }

    return [];
  }

  Map<String, dynamic> _emptyPolicyControllerMap() {
    return {
      "id": null,
      "titleC": TextEditingController(),
      "descC": TextEditingController(),
    };
  }

  Map<String, dynamic> _policyToControllerMap(Map<String, dynamic> item) {
    return {
      "id": item['id'],
      "titleC": TextEditingController(text: item['title']?.toString() ?? ''),
      "descC": TextEditingController(
        text:
            item['description']?.toString() ??
            item['desc']?.toString() ??
            item['policy']?.toString() ??
            '',
      ),
    };
  }

  List<Map<String, String>> buildPolicyPayload(
    List<Map<String, dynamic>> source,
  ) {
    return source
        .map((item) {
          final titleC = item["titleC"] as TextEditingController;
          final descC = item["descC"] as TextEditingController;

          return {
            "title": titleC.text.trim(),
            "description": descC.text.trim(),
            "policy": buildPolicyText(titleC.text.trim(), descC.text.trim()),
          };
        })
        .where((item) {
          return item["title"]!.isNotEmpty || item["description"]!.isNotEmpty;
        })
        .toList();
  }

  String buildPolicyText(String title, String description) {
    if (title.isNotEmpty && description.isNotEmpty) {
      return "$title - $description";
    }

    if (title.isNotEmpty) return title;

    return description;
  }

  String selectedListToDatabaseString(List<String> values) {
    return values
        .map((item) {
          return item
              .toLowerCase()
              .replaceAll(" ", "_")
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        })
        .where((item) => item.isNotEmpty)
        .join(',');
  }

  String normalizeFeature(String value) {
    return value.trim().toLowerCase().replaceAll("_", " ");
  }

  String? findFeatureId(List<Map<String, dynamic>> source, String featureName) {
    final target = normalizeFeature(featureName);

    for (final item in source) {
      final name =
          item['feature']?.toString() ??
          item['name']?.toString() ??
          item['title']?.toString() ??
          "";

      if (normalizeFeature(name) == target) {
        final id =
            item['id'] ??
            item['feature_id'] ??
            item['kost_feature_id'] ??
            item['place_feature_id'];

        if (id != null) return id.toString();
      }
    }

    return null;
  }

  String getPlaceId() {
    final k = widget.kost;

    final possible =
        k['place_id'] ??
        k['place_property_id'] ??
        k['place_properties_id'] ??
        k['placePropertyId'] ??
        k['placePropertiesId'];

    if (possible != null) {
      return possible.toString();
    }

    final nestedKeys = [
      'place_property',
      'placeProperty',
      'place_properties',
      'placeProperties',
      'places',
      'place',
      'room',
      'rooms',
    ];

    for (final key in nestedKeys) {
      final value = k[key];

      if (value is Map && value['id'] != null) {
        return value['id'].toString();
      }

      if (value is List && value.isNotEmpty) {
        final first = value.first;

        if (first is Map && first['id'] != null) {
          return first['id'].toString();
        }
      }
    }

    return widget.kost['id'].toString();
  }

  String cleanTextValue(dynamic value) {
    if (value == null) return "";
    if (value is Map || value is List) return "";
    if (value.toString() == "null") return "";
    return value.toString().trim();
  }

  String normalizeDistanceValue(dynamic value) {
    String text = cleanTextValue(value);

    if (text.isEmpty) return "";

    text = text.replaceAll(',', '.');
    text = text.replaceAll(RegExp(r'[^0-9.]'), '');

    return text;
  }

  List<Map<String, dynamic>> parseNearbyPlaceList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map<Map<String, dynamic>>((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }

        return {"name": item.toString()};
      }).toList();
    }

    if (value is Map) {
      if (value['data'] is List) {
        return parseNearbyPlaceList(value['data']);
      }

      if (value['data'] is Map && value['data']['data'] is List) {
        return parseNearbyPlaceList(value['data']['data']);
      }

      if (value['nearby_places'] is List) {
        return parseNearbyPlaceList(value['nearby_places']);
      }

      if (value['nearbyPlaces'] is List) {
        return parseNearbyPlaceList(value['nearbyPlaces']);
      }

      if (value['places'] is List) {
        return parseNearbyPlaceList(value['places']);
      }

      if (value['items'] is List) {
        return parseNearbyPlaceList(value['items']);
      }

      return [Map<String, dynamic>.from(value)];
    }

    if (value is String && value.trim().isNotEmpty && value != "null") {
      try {
        final decoded = jsonDecode(value);
        return parseNearbyPlaceList(decoded);
      } catch (_) {}
    }

    return [];
  }

  Map<String, dynamic> nearbyToSelectedMap(dynamic item) {
    if (item is! Map) {
      return {
        "id": "",
        "name": cleanTextValue(item),
        "type": "",
        "distance": "",
      };
    }

    final map = Map<String, dynamic>.from(item);

    final place =
        map['place'] ??
        map['places'] ??
        map['nearby_place'] ??
        map['nearbyPlace'];

    Map<String, dynamic>? placeMap;

    if (place is Map) {
      placeMap = Map<String, dynamic>.from(place);
    }

    final pivot = map['pivot'];

    Map<String, dynamic>? pivotMap;

    if (pivot is Map) {
      pivotMap = Map<String, dynamic>.from(pivot);
    }

    final id = cleanTextValue(
      placeMap?['id'] ??
          map['nearby_place_id'] ??
          map['nearby_places_id'] ??
          map['place_id'] ??
          map['id'],
    );

    final name = cleanTextValue(
      placeMap?['name'] ??
          placeMap?['title'] ??
          placeMap?['place_name'] ??
          placeMap?['nama'] ??
          map['name'] ??
          map['title'] ??
          map['place_name'] ??
          map['nama'] ??
          map['location_name'],
    );

    final type = cleanTextValue(
      placeMap?['type'] ??
          placeMap?['category'] ??
          placeMap?['place_type'] ??
          placeMap?['kategori'] ??
          map['type'] ??
          map['category'] ??
          map['place_type'] ??
          map['kategori'],
    );

    final distance = normalizeDistanceValue(
      pivotMap?['distance'] ??
          pivotMap?['distance_km'] ??
          pivotMap?['jarak'] ??
          map['distance'] ??
          map['distance_km'] ??
          map['jarak'] ??
          map['range'],
    );

    return {
      "id": id,
      "name": name.isEmpty ? "Lokasi Terdekat" : name,
      "type": type,
      "distance": distance,
    };
  }

  List<Map<String, dynamic>> removeDuplicateNearbyPlaces(
    List<Map<String, dynamic>> source,
  ) {
    final List<Map<String, dynamic>> result = [];
    final Set<String> ids = {};

    for (final item in source) {
      final id = cleanTextValue(item['id']);

      if (id.isEmpty) continue;

      if (ids.contains(id)) continue;

      ids.add(id);
      result.add(item);
    }

    return result;
  }

  Future<void> fetchNearbyPlaceOptions() async {
    try {
      setState(() {
        isNearbyLoading = true;
      });

      final token = await ApiService().getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/nearby-places"),
        headers: {
          "Accept": "application/json",
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
      );

      print("GET ALL NEARBY PLACES STATUS:");
      print(response.statusCode);

      print("GET ALL NEARBY PLACES BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final parsed = parseNearbyPlaceList(decoded)
            .map(nearbyToSelectedMap)
            .where((item) => cleanTextValue(item['id']).isNotEmpty)
            .toList();

        if (!mounted) return;

        setState(() {
          allNearbyPlaces = removeDuplicateNearbyPlaces(parsed);
        });
      }
    } catch (e) {
      print("GET ALL NEARBY PLACES ERROR:");
      print(e);
    }

    if (mounted) {
      setState(() {
        isNearbyLoading = false;
      });
    }
  }

  Future<void> fetchCurrentNearbyPlaces() async {
    try {
      final token = await ApiService().getToken();

      final propertyId = widget.kost['id']?.toString() ?? "";

      if (propertyId.isEmpty) return;

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/nearby-places"),
        headers: {
          "Accept": "application/json",
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
      );

      print("GET CURRENT NEARBY PLACES STATUS:");
      print(response.statusCode);

      print("GET CURRENT NEARBY PLACES BODY:");
      print(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final parsedRaw = parseNearbyPlaceList(decoded);

        final parsed = parsedRaw
            .map(nearbyToSelectedMap)
            .where((item) => cleanTextValue(item['id']).isNotEmpty)
            .toList();

        if (!mounted) return;

        setState(() {
          originalNearbyPlaceObjects = parsedRaw;
          selectedNearbyPlaces = removeDuplicateNearbyPlaces(parsed);
          syncNearbyDropdownFromSelectedList(force: true);
        });
      }
    } catch (e) {
      print("GET CURRENT NEARBY PLACES ERROR:");
      print(e);
    }
  }

  bool isNearbySelected(dynamic id) {
    final cleanId = cleanTextValue(id);

    if (cleanId.isEmpty) return false;

    return selectedNearbyPlaces.any((item) {
      return cleanTextValue(item['id']) == cleanId;
    });
  }

  void toggleNearbyPlace(
    Map<String, dynamic> place,
    StateSetter modalSetState,
  ) {
    final id = cleanTextValue(place['id']);

    if (id.isEmpty) return;

    setState(() {
      if (isNearbySelected(id)) {
        selectedNearbyPlaces.removeWhere((item) {
          return cleanTextValue(item['id']) == id;
        });
      } else {
        selectedNearbyPlaces.add({
          "id": id,
          "name": cleanTextValue(place['name']),
          "type": cleanTextValue(place['type']),
          "distance": "",
        });
      }
    });

    modalSetState(() {});
  }

  void updateNearbyDistance(String id, String value) {
    final cleanId = cleanTextValue(id);

    final index = selectedNearbyPlaces.indexWhere((item) {
      return cleanTextValue(item['id']) == cleanId;
    });

    if (index == -1) return;

    setState(() {
      selectedNearbyPlaces[index]['distance'] = normalizeDistanceValue(value);
    });
  }

  void removeSelectedNearbyPlace(String id, StateSetter modalSetState) {
    final cleanId = cleanTextValue(id);

    setState(() {
      selectedNearbyPlaces.removeWhere((item) {
        return cleanTextValue(item['id']) == cleanId;
      });
    });

    modalSetState(() {});
  }

  List<Map<String, String>> buildNearbyPlacesPayload() {
    return selectedNearbyPlaces
        .map((item) {
          return {
            "nearby_place_id": cleanTextValue(item['id']),
            "nearby_places_id": cleanTextValue(item['id']),
            "place_id": cleanTextValue(item['id']),
            "distance": normalizeDistanceValue(item['distance']),
            "distance_km": normalizeDistanceValue(item['distance']),
            "jarak": normalizeDistanceValue(item['distance']),
          };
        })
        .where((item) {
          return item["nearby_place_id"]!.isNotEmpty;
        })
        .toList();
  }

  Map<String, String> nearbyRequestBody(Map<String, dynamic> item) {
    final id = cleanTextValue(item['id']);
    final distance = normalizeDistanceValue(item['distance']);

    return {
      "nearby_place_id": id,
      "nearby_places_id": id,
      "place_id": id,
      "distance": distance,
      "distance_km": distance,
      "jarak": distance,
    };
  }

  Map<String, dynamic>? findOriginalNearbyById(String id) {
    final originals = originalNearbyPlaceObjects
        .map(nearbyToSelectedMap)
        .where((item) => cleanTextValue(item['id']).isNotEmpty)
        .toList();

    for (final item in originals) {
      if (cleanTextValue(item['id']) == id) {
        return item;
      }
    }

    return null;
  }

  Future<bool> addNearbyPlace({
    required String propertyId,
    required String token,
    required Map<String, dynamic> item,
  }) async {
    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/properties/$propertyId/nearby-places"),
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
      body: nearbyRequestBody(item),
    );

    print("ADD NEARBY PLACE:");
    print(nearbyRequestBody(item));
    print(response.statusCode);
    print(response.body);

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> updateNearbyPlace({
    required String propertyId,
    required String token,
    required Map<String, dynamic> item,
  }) async {
    final id = cleanTextValue(item['id']);

    if (id.isEmpty) return false;

    final response = await http.put(
      Uri.parse(
        "${ApiService.baseUrl}/properties/$propertyId/nearby-places/$id",
      ),
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
      body: nearbyRequestBody(item),
    );

    print("UPDATE NEARBY PLACE:");
    print(nearbyRequestBody(item));
    print(response.statusCode);
    print(response.body);

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> deleteNearbyPlace({
    required String propertyId,
    required String token,
    required String nearbyPlaceId,
  }) async {
    if (nearbyPlaceId.isEmpty) return false;

    final response = await http.delete(
      Uri.parse(
        "${ApiService.baseUrl}/properties/$propertyId/nearby-places/$nearbyPlaceId",
      ),
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );

    print("DELETE NEARBY PLACE:");
    print(nearbyPlaceId);
    print(response.statusCode);
    print(response.body);

    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<void> syncNearbyPlaces({
    required String propertyId,
    required String token,
  }) async {
    try {
      final List<Map<String, dynamic>> places = [];

      if (selectedNearbyPlace != null) {
        final placeId = selectedNearbyPlace!['id'];
        final distanceText = nearbyDistanceController.text.trim();

        if (placeId != null && distanceText.isNotEmpty) {
          places.add({
            "place_id": placeId,
            "distance": distanceText.replaceAll(',', '.'),
          });
        }
      }

      final body = {"places": places};

      final response = await http.put(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/nearby-places"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      debugPrint("EDIT NEARBY BODY: $body");
      debugPrint("EDIT NEARBY STATUS: ${response.statusCode}");
      debugPrint("EDIT NEARBY RESPONSE: ${response.body}");
    } catch (e) {
      debugPrint("EDIT NEARBY ERROR: $e");
    }
  }

  Future<void> syncKostFeatures({
    required String propertyId,
    required String token,
  }) async {
    final current = kostFeatures.map(normalizeFeature).toList();
    final original = originalKostFeatures.map(normalizeFeature).toList();

    final added = kostFeatures.where((item) {
      return !original.contains(normalizeFeature(item));
    }).toList();

    final removed = originalKostFeatures.where((item) {
      return !current.contains(normalizeFeature(item));
    }).toList();

    for (final feature in added) {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId/features"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        body: {"feature": feature},
      );

      print("ADD KOST FEATURE:");
      print(feature);
      print(response.statusCode);
      print(response.body);
    }

    for (final feature in removed) {
      final featureId = findFeatureId(originalKostFeatureObjects, feature);

      if (featureId == null) continue;

      final response = await http.delete(
        Uri.parse(
          "${ApiService.baseUrl}/properties/$propertyId/features/$featureId",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print("DELETE KOST FEATURE:");
      print(feature);
      print(response.statusCode);
      print(response.body);
    }
  }

  Future<void> syncRoomFeatures({
    required String propertyId,
    required String token,
  }) async {
    final placeId = getPlaceId();

    final current = roomFeatures.map(normalizeFeature).toList();
    final original = originalRoomFeatures.map(normalizeFeature).toList();

    final added = roomFeatures.where((item) {
      return !original.contains(normalizeFeature(item));
    }).toList();

    final removed = originalRoomFeatures.where((item) {
      return !current.contains(normalizeFeature(item));
    }).toList();

    for (final feature in added) {
      final response = await http.post(
        Uri.parse(
          "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/features",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        body: {"feature": feature},
      );

      print("ADD ROOM FEATURE:");
      print(feature);
      print(response.statusCode);
      print(response.body);
    }

    for (final feature in removed) {
      final featureId = findFeatureId(originalRoomFeatureObjects, feature);

      if (featureId == null) continue;

      final response = await http.delete(
        Uri.parse(
          "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/features/$featureId",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print("DELETE ROOM FEATURE:");
      print(feature);
      print(response.statusCode);
      print(response.body);
    }
  }

  Future<void> syncKostPolicies({
    required String propertyId,
    required String token,
  }) async {
    final currentIds = kostPolicies
        .map((item) => item['id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .toList();

    for (final original in originalKostPolicyObjects) {
      final id = original['id'];

      if (id != null && !currentIds.contains(id.toString())) {
        final response = await http.delete(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/policies/$id",
          ),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        );

        print("DELETE KOST POLICY:");
        print(response.statusCode);
        print(response.body);
      }
    }

    for (final item in kostPolicies) {
      final id = item['id'];
      final titleC = item['titleC'] as TextEditingController;
      final descC = item['descC'] as TextEditingController;

      final title = titleC.text.trim();
      final description = descC.text.trim();

      if (title.isEmpty && description.isEmpty) continue;

      final body = {
        "title": title,
        "description": description,
        "policy": buildPolicyText(title, description),
      };

      if (id == null) {
        final response = await http.post(
          Uri.parse("${ApiService.baseUrl}/properties/$propertyId/policies"),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: body,
        );

        print("ADD KOST POLICY:");
        print(response.statusCode);
        print(response.body);
      } else {
        final response = await http.put(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/policies/$id",
          ),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: body,
        );

        print("UPDATE KOST POLICY:");
        print(response.statusCode);
        print(response.body);
      }
    }
  }

  Future<void> syncRoomPolicies({
    required String propertyId,
    required String token,
  }) async {
    final placeId = getPlaceId();

    final currentIds = roomPolicies
        .map((item) => item['id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .toList();

    for (final original in originalRoomPolicyObjects) {
      final id = original['id'];

      if (id != null && !currentIds.contains(id.toString())) {
        final response = await http.delete(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/policies/$id",
          ),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        );

        print("DELETE ROOM POLICY:");
        print(response.statusCode);
        print(response.body);
      }
    }

    for (final item in roomPolicies) {
      final id = item['id'];
      final titleC = item['titleC'] as TextEditingController;
      final descC = item['descC'] as TextEditingController;

      final title = titleC.text.trim();
      final description = descC.text.trim();

      if (title.isEmpty && description.isEmpty) continue;

      final body = {
        "title": title,
        "description": description,
        "policy": buildPolicyText(title, description),
      };

      if (id == null) {
        final response = await http.post(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/policies",
          ),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: body,
        );

        print("ADD ROOM POLICY:");
        print(response.statusCode);
        print(response.body);
      } else {
        final response = await http.put(
          Uri.parse(
            "${ApiService.baseUrl}/properties/$propertyId/place-properties/$placeId/policies/$id",
          ),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: body,
        );

        print("UPDATE ROOM POLICY:");
        print(response.statusCode);
        print(response.body);
      }
    }
  }

  Future<void> update() async {
    setState(() {
      isLoading = true;
    });

    try {
      final token = await ApiService().getToken();

      if (token == null || token.isEmpty) {
        showMessage("Token tidak ditemukan, silakan login ulang");

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      final propertyId = widget.kost['id'].toString();
      final placeId = getPlaceId();

      final kostRulesJson = jsonEncode(buildPolicyPayload(kostPolicies));

      final roomRulesJson = jsonEncode(buildPolicyPayload(roomPolicies));

      final priceBody = buildPricePayload();

      syncSingleNearbySelection();

      final body = {
        "title": titleC.text.trim(),
        "description": descC.text.trim(),
        "address": addressC.text.trim(),
        "max_people": maxPeopleC.text.trim(),
        if (selectedCityId != null) "city_id": selectedCityId.toString(),

        "deleted_image_ids": removedImageIds(),
        "delete_image_ids": removedImageIds(),
        "removed_image_ids": removedImageIds(),

        "place_id": placeId,
        "place_property_id": placeId,
        "place_properties_id": placeId,

        ...priceBody,

        "kost_facilities": selectedListToDatabaseString(kostFeatures),
        "room_facilities": selectedListToDatabaseString(roomFeatures),
        "kost_rules": kostRulesJson,
        "room_rules": roomRulesJson,

        "property_features": selectedListToDatabaseString(kostFeatures),
        "place_features": selectedListToDatabaseString(roomFeatures),
        "property_policies": buildPolicyPayload(kostPolicies),
        "place_policies": buildPolicyPayload(roomPolicies),

        "nearby_places": buildNearbyPlacesPayload(),
        "nearbyPlaces": buildNearbyPlacesPayload(),
        "property_nearby_places": buildNearbyPlacesPayload(),
      };

      print("UPDATE BODY UTAMA:");
      print(body);

      http.Response res = await http.put(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      print("UPDATE STATUS UTAMA JSON:");
      print(res.statusCode);

      print("UPDATE RESPONSE UTAMA JSON:");
      print(res.body);

      if (!isSuccessStatus(res.statusCode)) {
        res = await http.post(
          Uri.parse("${ApiService.baseUrl}/properties/$propertyId"),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: {
            "_method": "PUT",
            "title": titleC.text.trim(),
            "description": descC.text.trim(),
            "address": addressC.text.trim(),
            "max_people": maxPeopleC.text.trim(),
            if (selectedCityId != null) "city_id": selectedCityId.toString(),
            "deleted_image_ids": jsonEncode(removedImageIds()),
            "delete_image_ids": jsonEncode(removedImageIds()),
            "removed_image_ids": jsonEncode(removedImageIds()),
            "place_id": placeId,
            "place_property_id": placeId,
            "place_properties_id": placeId,
            ...priceBody,
          },
        );

        print("UPDATE STATUS UTAMA FORM METHOD PUT:");
        print(res.statusCode);

        print("UPDATE RESPONSE UTAMA FORM METHOD PUT:");
        print(res.body);
      }

      if (!isSuccessStatus(res.statusCode)) {
        showMessage("Gagal memperbarui data utama kost");

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      final priceUpdated = await updatePriceWithoutChangingBackend(
        propertyId: propertyId,
        placeId: placeId,
        token: token,
        priceBody: priceBody,
      );

      print("HASIL UPDATE HARGA:");
      print(
        priceUpdated
            ? "HARGA BERHASIL TERKIRIM"
            : "HARGA BELUM DITERIMA ENDPOINT",
      );

      await syncKostFeatures(propertyId: propertyId, token: token);

      await syncRoomFeatures(propertyId: propertyId, token: token);

      await syncKostPolicies(propertyId: propertyId, token: token);

      await syncRoomPolicies(propertyId: propertyId, token: token);

      await syncNearbyPlaces(propertyId: propertyId, token: token);

      final imageDeleteUpdated = await deleteRemovedExistingImages(
        propertyId: propertyId,
        token: token,
      );

      final imageUploadUpdated = await uploadNewImages(
        propertyId: propertyId,
        token: token,
      );

      if (imageDeleteUpdated && imageUploadUpdated) {
        removedExistingImages.clear();
        newImages.clear();
      }

      if (!mounted) return;

      if (priceUpdated && imageDeleteUpdated && imageUploadUpdated) {
        showMessage("Kost dan harga berhasil diperbarui", success: true);
      } else {
        showMessage(
          "Kost berhasil diperbarui, tapi beberapa data tambahan mungkin belum diterima endpoint backend",
          success: true,
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      print("UPDATE ERROR:");
      print(e);

      if (mounted) {
        showMessage("Error: $e");
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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

  Widget input(
    String label,
    TextEditingController controller, {
    IconData icon = Icons.edit_outlined,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: maxLines == 1
                  ? Icon(icon, color: primaryColor)
                  : null,
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget priceInput(
    String label,
    TextEditingController controller, {
    IconData icon = Icons.payments_outlined,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Isi 0 jika tidak ingin ditampilkan",
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              prefixText: "Rp ",
              prefixStyle: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
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
    return Container(
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
    );
  }

  Widget buildImagePicker() {
    final totalImages = existingImages.length + newImages.length;

    return GestureDetector(
      onTap: pickImage,
      child: Container(
        width: double.infinity,
        height: totalImages == 0 ? 230 : 300,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: totalImages == 0
              ? LinearGradient(
                  colors: [primaryColor, const Color(0xFF18227A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: totalImages == 0 ? null : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: totalImages == 0
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Tambah Foto Kost",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Upload maksimal 15 gambar",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(12),
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
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$totalImages Foto Kost",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "Ketuk area ini untuk tambah foto lagi",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            "Edit",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalImages,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemBuilder: (context, index) {
                          if (index < existingImages.length) {
                            final image = existingImages[index];
                            final imageUrl = getImageUrlFromDynamic(
                              image['url'],
                            );

                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey.shade500,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  left: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      "Lama",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      removeExistingImage(index);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final newImageIndex = index - existingImages.length;

                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  newImages[newImageIndex],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.88),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    "Baru",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    removeNewImage(newImageIndex);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget cityDropdown() {
    final selectedCity = selectedCityId == null
        ? null
        : cities
              .where((item) {
                return parseNullableInt(item['id']) == selectedCityId;
              })
              .cast<Map<String, dynamic>?>()
              .firstWhere((item) => item != null, orElse: () => null);

    return DropdownSearch<Map<String, dynamic>>(
      items: cities,
      selectedItem: selectedCity,
      itemAsString: (item) {
        return item['name']?.toString() ?? "-";
      },
      compareFn: (item1, item2) {
        return item1['id'] == item2['id'];
      },
      popupProps: const PopupProps.modalBottomSheet(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(hintText: "Cari kota..."),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          hintText: isCityLoading
              ? "Memuat kota..."
              : cities.isEmpty
              ? "Data kota belum tersedia"
              : "Pilih Kota",
          prefixIcon: Icon(Icons.location_city_outlined, color: primaryColor),
          filled: true,
          fillColor: const Color(0xFFF4F6FA),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onChanged: (value) {
        final int? cityId = parseNullableInt(value?['id']);

        setState(() {
          selectedCityId = cityId;
          places = [];
          selectedNearbyPlace = null;
          nearbyDistanceController.clear();
          selectedNearbyPlaces = [];
        });

        print("EDIT SELECTED CITY ID:");
        print(selectedCityId);

        if (cityId != null) {
          loadPlacesByCity(cityId);
        }
      },
    );
  }

  Widget buildHeader() {
    final title = titleC.text.trim().isEmpty ? "Edit Kost" : titleC.text.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFF18227A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "Form Edit",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Perbarui informasi, fasilitas, aturan, dan lokasi terdekat kost.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget featureChip({
    required String feature,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      selected: selected,
      label: Text(
        feature,
        style: TextStyle(
          color: selected ? Colors.white : primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: selected
          ? const Icon(Icons.check_circle, color: Colors.white, size: 18)
          : null,
      backgroundColor: const Color(0xFFF4F6FA),
      selectedColor: primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? primaryColor : Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      onSelected: onSelected,
    );
  }

  Widget customChip({required String feature, required VoidCallback onDelete}) {
    return InputChip(
      label: Text(feature, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: softGreen,
      deleteIconColor: Colors.red,
      onDeleted: onDelete,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  void addFeatureDialog(bool isKost) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 5,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isKost ? "Tambah Fasilitas Kost" : "Tambah Fasilitas Kamar",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Contoh: Balkon, Dispenser, Air panas...",
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    prefixIcon: Icon(
                      Icons.add_home_work_outlined,
                      color: primaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      final value = controller.text.trim();

                      if (value.isEmpty) return;

                      setState(() {
                        if (isKost) {
                          if (!kostFeatures.contains(value)) {
                            kostFeatures.add(value);
                          }

                          if (!kostFeatureOptions.contains(value) &&
                              !customKostFeatures.contains(value)) {
                            customKostFeatures.add(value);
                          }
                        } else {
                          if (!roomFeatures.contains(value)) {
                            roomFeatures.add(value);
                          }

                          if (!roomFeatureOptions.contains(value) &&
                              !customRoomFeatures.contains(value)) {
                            customRoomFeatures.add(value);
                          }
                        }
                      });

                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Tambah Fasilitas",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildFeatureSection({
    required String title,
    required IconData icon,
    required bool isKost,
    required List<String> options,
    required List<String> selected,
    required List<String> custom,
  }) {
    return sectionCard(
      title: title,
      icon: icon,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((item) {
            return featureChip(
              feature: item,
              selected: selected.contains(item),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    if (!selected.contains(item)) {
                      selected.add(item);
                    }
                  } else {
                    selected.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (custom.isNotEmpty) const SizedBox(height: 12),
        if (custom.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: custom.map((item) {
              return customChip(
                feature: item,
                onDelete: () {
                  setState(() {
                    custom.remove(item);
                    selected.remove(item);
                  });
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              addFeatureDialog(isKost);
            },
            icon: const Icon(Icons.add),
            label: Text(
              isKost ? "Tambah Fasilitas Kost" : "Tambah Fasilitas Kamar",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
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
        text.contains("plaza") ||
        text.contains("pusat belanja")) {
      return Icons.local_mall_rounded;
    }

    if (text.contains("pasar")) {
      return Icons.storefront_rounded;
    }

    if (text.contains("halte")) {
      return Icons.directions_bus_filled_rounded;
    }

    return Icons.near_me_rounded;
  }

  Widget selectedNearbyCard(
    Map<String, dynamic> item,
    StateSetter? modalSetState,
  ) {
    final id = cleanTextValue(item['id']);
    final name = cleanTextValue(item['name']);
    final type = cleanTextValue(item['type']);
    final distance = cleanTextValue(item['distance']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: softGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getNearbyIcon(type, name),
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? "Lokasi Terdekat" : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.isEmpty ? "Kategori tidak tersedia" : type,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (distance.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "$distance KM dari kost",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (modalSetState == null) {
                    setState(() {
                      selectedNearbyPlaces.removeWhere((value) {
                        return cleanTextValue(value['id']) == id;
                      });
                    });
                  } else {
                    removeSelectedNearbyPlace(id, modalSetState);
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey("nearby-distance-$id-$distance"),
            initialValue: distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: "Jarak dari kost, contoh: 2.5",
              suffixText: "KM",
              prefixIcon: Icon(Icons.route_rounded, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 1.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              updateNearbyDistance(id, value);
            },
          ),
        ],
      ),
    );
  }

  Widget nearbyOptionTile(
    Map<String, dynamic> place,
    StateSetter modalSetState,
  ) {
    final id = cleanTextValue(place['id']);
    final name = cleanTextValue(place['name']);
    final type = cleanTextValue(place['type']);
    final selected = isNearbySelected(id);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        toggleNearbyPlace(place, modalSetState);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? primaryColor : const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.16) : softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                getNearbyIcon(type, name),
                color: selected ? Colors.white : primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? "Lokasi Terdekat" : name,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    type.isEmpty ? "Kategori tidak tersedia" : type,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withOpacity(0.75)
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.add_circle_outline,
              color: selected ? Colors.white : primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void showNearbyPlaceSheet() {
    String keyword = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final filteredPlaces = allNearbyPlaces.where((item) {
              final name = cleanTextValue(item['name']).toLowerCase();
              final type = cleanTextValue(item['type']).toLowerCase();
              final query = keyword.toLowerCase();

              return name.contains(query) || type.contains(query);
            }).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                margin: const EdgeInsets.all(14),
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: softGreen,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.near_me_outlined,
                            color: primaryColor,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Ganti Lokasi Terdekat",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) {
                        modalSetState(() {
                          keyword = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Cari lokasi terdekat...",
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        filled: true,
                        fillColor: const Color(0xFFF4F6FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: isNearbyLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            )
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                if (selectedNearbyPlaces.isNotEmpty) ...[
                                  Text(
                                    "Lokasi Dipilih",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...selectedNearbyPlaces.map((item) {
                                    return selectedNearbyCard(
                                      item,
                                      modalSetState,
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  "Daftar Lokasi dari Database",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (filteredPlaces.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FA),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      "Lokasi tidak ditemukan",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
                                  ...filteredPlaces.map((place) {
                                    return nearbyOptionTile(
                                      place,
                                      modalSetState,
                                    );
                                  }),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
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
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text(
                          "Simpan Pilihan Lokasi",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildNearbyPlacesSection() {
    return sectionCard(
      title: "Lokasi Terdekat",
      icon: Icons.near_me_outlined,
      children: [nearbyPlaceInputLikeAddKost()],
    );
  }

  Widget nearbyPlaceInputLikeAddKost() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.near_me_outlined,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Jarak Dengan Transportasi",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedCityId == null
                          ? "Pilih kota terlebih dahulu"
                          : isLoadingPlaces
                          ? "Mengambil data tempat..."
                          : "Pilih tempat dari database",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedNearbyPlace != null ||
                  nearbyDistanceController.text.trim().isNotEmpty)
                IconButton(
                  tooltip: "Kosongkan",
                  onPressed: () {
                    setState(() {
                      selectedNearbyPlace = null;
                      nearbyDistanceController.clear();
                      selectedNearbyPlaces = [];
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownSearch<Map<String, dynamic>>(
            enabled: selectedCityId != null && !isLoadingPlaces,
            items: places,
            selectedItem: selectedNearbyPlace,
            compareFn: (item1, item2) {
              return cleanTextValue(item1['id']) == cleanTextValue(item2['id']);
            },
            itemAsString: (item) {
              final type = getPlaceType(item);
              final name = getPlaceName(item);

              if (type.isEmpty) {
                return name;
              }

              return "$type - $name";
            },
            popupProps: const PopupProps.modalBottomSheet(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(hintText: "Cari tempat..."),
              ),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                hintText: selectedCityId == null
                    ? "Pilih kota dulu"
                    : isLoadingPlaces
                    ? "Mengambil tempat..."
                    : places.isEmpty
                    ? "Tempat belum tersedia"
                    : "Pilih tempat terdekat",
                prefixIcon: isLoadingPlaces
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      )
                    : Icon(Icons.place_outlined, color: primaryColor, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.4),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {
                selectedNearbyPlace = value;
                nearbyDistanceController.clear();
                syncSingleNearbySelection();
              });

              print("EDIT SELECTED PLACE:");
              print(selectedNearbyPlace);
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectedNearbyPlace == null
                ? const SizedBox.shrink()
                : Column(
                    key: ValueKey(selectedNearbyPlace?['id']),
                    children: [
                      const SizedBox(height: 14),
                      nearbySmallTextField(
                        label:
                            "Jarak dari ${getPlaceName(selectedNearbyPlace!)}",
                        hint: "Contoh: 2.5",
                        controller: nearbyDistanceController,
                        icon: Icons.social_distance_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        suffixText: "KM",
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                        onChanged: (_) {
                          setState(() {
                            syncSingleNearbySelection();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Contoh: ${getPlaceName(selectedNearbyPlace!)} berjarak 3 KM dari kost",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
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

  Widget nearbySmallTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffixText,
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 1.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget policyCard(List<Map<String, dynamic>> list, int index) {
    final titleController = list[index]["titleC"] as TextEditingController;
    final descController = list[index]["descC"] as TextEditingController;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Aturan ${index + 1}",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (list.length > 1)
                IconButton(
                  onPressed: () {
                    setState(() {
                      titleController.dispose();
                      descController.dispose();
                      list.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          input(
            "Judul Aturan",
            titleController,
            icon: Icons.rule_folder_outlined,
            hint: "Contoh: Tamu wajib lapor",
          ),
          input(
            "Deskripsi Aturan",
            descController,
            maxLines: 3,
            hint: "Tulis detail aturan di sini...",
          ),
        ],
      ),
    );
  }

  Widget buildPolicySection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> policies,
  }) {
    return sectionCard(
      title: title,
      icon: icon,
      children: [
        ...List.generate(policies.length, (index) {
          return policyCard(policies, index);
        }),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              setState(() {
                policies.add(_emptyPolicyControllerMap());
              });
            },
            icon: const Icon(Icons.add),
            label: Text(
              title == "Aturan Kost"
                  ? "Tambah Aturan Kost"
                  : "Tambah Aturan Kamar",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Edit Kost",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          child: Column(
            children: [
              buildHeader(),
              buildImagePicker(),
              sectionCard(
                title: "Informasi Utama",
                icon: Icons.home_work_outlined,
                children: [
                  input(
                    "Nama Kost",
                    titleC,
                    icon: Icons.apartment_outlined,
                    hint: "Masukkan nama kost",
                  ),
                  input(
                    "Deskripsi",
                    descC,
                    maxLines: 4,
                    hint: "Masukkan deskripsi kost",
                  ),
                  input(
                    "Alamat",
                    addressC,
                    maxLines: 3,
                    hint: "Masukkan alamat kost",
                  ),
                  Text(
                    "Pilih Kota",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  cityDropdown(),
                  const SizedBox(height: 16),
                  input(
                    "Max Orang",
                    maxPeopleC,
                    icon: Icons.people_alt_outlined,
                    type: TextInputType.number,
                    hint: "Contoh: 2",
                  ),
                ],
              ),
              sectionCard(
                title: "Harga Sewa",
                icon: Icons.payments_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: priceInput(
                          "Harga Malam",
                          nightC,
                          icon: Icons.nightlight_round,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: priceInput(
                          "Harga Minggu",
                          weekC,
                          icon: Icons.calendar_view_week_outlined,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: priceInput(
                          "Harga Bulan",
                          monthC,
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: priceInput(
                          "Harga Tahun",
                          yearC,
                          icon: Icons.date_range_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              buildNearbyPlacesSection(),
              buildFeatureSection(
                title: "Fasilitas Kost",
                icon: Icons.maps_home_work_outlined,
                isKost: true,
                options: kostFeatureOptions,
                selected: kostFeatures,
                custom: customKostFeatures,
              ),
              buildFeatureSection(
                title: "Fasilitas Kamar",
                icon: Icons.bed_outlined,
                isKost: false,
                options: roomFeatureOptions,
                selected: roomFeatures,
                custom: customRoomFeatures,
              ),
              buildPolicySection(
                title: "Aturan Kost",
                icon: Icons.rule_outlined,
                policies: kostPolicies,
              ),
              buildPolicySection(
                title: "Aturan Kamar",
                icon: Icons.meeting_room_outlined,
                policies: roomPolicies,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : update,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: Colors.grey,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_alt_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          "Update Kost",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String formatted = _formatNumber(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(String value) {
    final buffer = StringBuffer();

    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      buffer.write(value[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}
