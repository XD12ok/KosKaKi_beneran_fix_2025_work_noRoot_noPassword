import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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

    titleC = TextEditingController(text: k['title']?.toString() ?? '');

    descC = TextEditingController(text: k['description']?.toString() ?? '');

    addressC = TextEditingController(text: k['address']?.toString() ?? '');

    maxPeopleC = TextEditingController(text: k['max_people']?.toString() ?? '');

    nightC = TextEditingController(
      text: formatNumber(k['price_perNight'] ?? k['price_per_night']),
    );

    weekC = TextEditingController(
      text: formatNumber(k['price_perWeek'] ?? k['price_per_week']),
    );

    monthC = TextEditingController(
      text: formatNumber(k['price_perMonth'] ?? k['price_per_month']),
    );

    yearC = TextEditingController(
      text: formatNumber(k['price_perYear'] ?? k['price_per_year']),
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

    fetchNearbyPlaceOptions();
    fetchCurrentNearbyPlaces();
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

  String formatNumber(dynamic value) {
    if (value == null) return "";

    String number = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

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

  String cleanPrice(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
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
        k['place_id'] ?? k['place_property_id'] ?? k['place_properties_id'];

    if (possible != null) {
      return possible.toString();
    }

    if (k['place_properties'] is List &&
        (k['place_properties'] as List).isNotEmpty) {
      final first = (k['place_properties'] as List).first;

      if (first is Map && first['id'] != null) {
        return first['id'].toString();
      }
    }

    if (k['places'] is List && (k['places'] as List).isNotEmpty) {
      final first = (k['places'] as List).first;

      if (first is Map && first['id'] != null) {
        return first['id'].toString();
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
    final originalSelected = originalNearbyPlaceObjects
        .map(nearbyToSelectedMap)
        .where((item) => cleanTextValue(item['id']).isNotEmpty)
        .toList();

    final currentIds = selectedNearbyPlaces
        .map((item) => cleanTextValue(item['id']))
        .where((id) => id.isNotEmpty)
        .toList();

    for (final original in originalSelected) {
      final originalId = cleanTextValue(original['id']);

      if (originalId.isEmpty) continue;

      if (!currentIds.contains(originalId)) {
        await deleteNearbyPlace(
          propertyId: propertyId,
          token: token,
          nearbyPlaceId: originalId,
        );
      }
    }

    for (final selected in selectedNearbyPlaces) {
      final id = cleanTextValue(selected['id']);

      if (id.isEmpty) continue;

      final original = findOriginalNearbyById(id);

      if (original == null) {
        await addNearbyPlace(
          propertyId: propertyId,
          token: token,
          item: selected,
        );

        continue;
      }

      final oldDistance = normalizeDistanceValue(original['distance']);
      final newDistance = normalizeDistanceValue(selected['distance']);

      if (oldDistance == newDistance) continue;

      final updated = await updateNearbyPlace(
        propertyId: propertyId,
        token: token,
        item: selected,
      );

      if (!updated) {
        await deleteNearbyPlace(
          propertyId: propertyId,
          token: token,
          nearbyPlaceId: id,
        );

        await addNearbyPlace(
          propertyId: propertyId,
          token: token,
          item: selected,
        );
      }
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

      final kostRulesJson = jsonEncode(buildPolicyPayload(kostPolicies));

      final roomRulesJson = jsonEncode(buildPolicyPayload(roomPolicies));

      final body = {
        "title": titleC.text,
        "description": descC.text,
        "address": addressC.text,
        "max_people": maxPeopleC.text,

        "price_perNight": cleanPrice(nightC.text),
        "price_perWeek": cleanPrice(weekC.text),
        "price_perMonth": cleanPrice(monthC.text),
        "price_perYear": cleanPrice(yearC.text),

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

      print("UPDATE BODY:");
      print(body);

      final res = await http.put(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      print("UPDATE STATUS:");
      print(res.statusCode);

      print("UPDATE RESPONSE:");
      print(res.body);

      if (res.statusCode != 200 && res.statusCode != 201) {
        showMessage("Gagal memperbarui data utama kost");

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      await syncKostFeatures(propertyId: propertyId, token: token);

      await syncRoomFeatures(propertyId: propertyId, token: token);

      await syncKostPolicies(propertyId: propertyId, token: token);

      await syncRoomPolicies(propertyId: propertyId, token: token);

      await syncNearbyPlaces(propertyId: propertyId, token: token);

      if (!mounted) return;

      showMessage("Kost berhasil diperbarui", success: true);

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
              hintText: "0",
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
      children: [
        if (selectedNearbyPlaces.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.location_off_outlined, color: Colors.grey.shade500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Lokasi terdekat belum dipilih",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...selectedNearbyPlaces.map((item) {
            return selectedNearbyCard(item, null);
          }),
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
            onPressed: showNearbyPlaceSheet,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: Text(
              selectedNearbyPlaces.isEmpty
                  ? "Pilih Lokasi Terdekat"
                  : "Ganti Lokasi Terdekat",
              style: const TextStyle(fontWeight: FontWeight.bold),
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
