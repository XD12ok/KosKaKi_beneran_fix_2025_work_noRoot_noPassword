import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Resident/Payment.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PengajuanSewa extends StatefulWidget {
  final Map<String, dynamic>? kos;
  final int? propertyId;

  const PengajuanSewa({super.key, this.kos, this.propertyId});

  @override
  State<PengajuanSewa> createState() => _PengajuanSewaState();
}

class _PengajuanSewaState extends State<PengajuanSewa> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  bool hasReadArguments = false;
  bool isLoading = false;

  final TextEditingController senderNameController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  Map<String, dynamic> kos = {};

  int? propertyId;
  int? ownerId;

  String title = "Kos";
  String address = "";
  String ownerName = "Pemilik Kos";

  DateTime? startDate;

  int duration = 1;

  _RentalOption? selectedOption;

  List<_RentalOption> rentalOptions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (hasReadArguments) return;

    hasReadArguments = true;

    readArguments();
    prepareRentalOptions();
  }

  @override
  void dispose() {
    senderNameController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String safeString(dynamic value) {
    final text = value?.toString().trim() ?? "";

    if (text.isEmpty) return "";
    if (text == "null") return "";
    if (text.startsWith("{")) return "";
    if (text.startsWith("[")) return "";

    return text;
  }

  String pickSafeTextFromMap(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return "";

    for (final key in keys) {
      final text = safeString(source[key]);

      if (text.isNotEmpty) {
        return text;
      }
    }

    return "";
  }

  int parseIntValue(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return 0;

    text = text.replaceAll("Rp", "").trim();

    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text)?.round() ?? 0;
    }

    if (RegExp(r'^\d+,\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text.replaceAll(",", "."))?.round() ?? 0;
    }

    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return 0;

    return int.tryParse(cleaned) ?? 0;
  }

  String cleanLower(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
  }

  List<dynamic> parseDynamicList(dynamic value) {
    if (value == null) return [];

    if (value is List) return value;

    if (value is Map) {
      if (value['data'] is List) {
        return value['data'];
      }

      if (value['data'] is Map && value['data']['data'] is List) {
        return value['data']['data'];
      }

      if (value['bookings'] is List) {
        return value['bookings'];
      }

      if (value['items'] is List) {
        return value['items'];
      }

      if (value['results'] is List) {
        return value['results'];
      }

      if (value['rental_bookings'] is List) {
        return value['rental_bookings'];
      }
    }

    return [];
  }

  String getKosNameForBackend() {
    final property = toMap(kos["property"]);
    final placeProperty = toMap(kos["place_property"]);
    final placePropertyCamel = toMap(kos["placeProperty"]);
    final placeProperties = toMap(kos["place_properties"]);
    final placePropertiesCamel = toMap(kos["placeProperties"]);
    final kosMap = toMap(kos["kos"]);
    final kostMap = toMap(kos["kost"]);
    final place = toMap(kos["place"]);

    final topKeys = [
      "title",
      "property_name",
      "place_property_name",
      "nama_kos",
      "nama_kost",
      "kos_name",
      "kost_name",
      "place_name",
      "property_title",
    ];

    final propertyKeys = [
      "title",
      "property_name",
      "place_property_name",
      "nama_kos",
      "nama_kost",
      "kos_name",
      "kost_name",
      "place_name",
      "property_title",
      "name",
      "nama",
    ];

    final fromKos = pickSafeTextFromMap(kos, topKeys);
    if (fromKos.isNotEmpty) return fromKos;

    final fromProperty = pickSafeTextFromMap(property, propertyKeys);
    if (fromProperty.isNotEmpty) return fromProperty;

    final fromPlaceProperty = pickSafeTextFromMap(placeProperty, propertyKeys);
    if (fromPlaceProperty.isNotEmpty) return fromPlaceProperty;

    final fromPlacePropertyCamel = pickSafeTextFromMap(
      placePropertyCamel,
      propertyKeys,
    );
    if (fromPlacePropertyCamel.isNotEmpty) return fromPlacePropertyCamel;

    final fromPlaceProperties = pickSafeTextFromMap(
      placeProperties,
      propertyKeys,
    );
    if (fromPlaceProperties.isNotEmpty) return fromPlaceProperties;

    final fromPlacePropertiesCamel = pickSafeTextFromMap(
      placePropertiesCamel,
      propertyKeys,
    );
    if (fromPlacePropertiesCamel.isNotEmpty) return fromPlacePropertiesCamel;

    final fromKosMap = pickSafeTextFromMap(kosMap, propertyKeys);
    if (fromKosMap.isNotEmpty) return fromKosMap;

    final fromKostMap = pickSafeTextFromMap(kostMap, propertyKeys);
    if (fromKostMap.isNotEmpty) return fromKostMap;

    final fromPlace = pickSafeTextFromMap(place, propertyKeys);
    if (fromPlace.isNotEmpty) return fromPlace;

    final titleText = safeString(title);

    if (titleText.isNotEmpty && titleText != "Kos") {
      return titleText;
    }

    return "Nama kos tidak tersedia";
  }

  String getKosAddressForBackend() {
    final property = toMap(kos["property"]);
    final placeProperty = toMap(kos["place_property"]);
    final placePropertyCamel = toMap(kos["placeProperty"]);
    final placeProperties = toMap(kos["place_properties"]);
    final placePropertiesCamel = toMap(kos["placeProperties"]);
    final kosMap = toMap(kos["kos"]);
    final kostMap = toMap(kos["kost"]);
    final place = toMap(kos["place"]);

    final addressKeys = [
      "address",
      "alamat",
      "location",
      "lokasi",
      "full_address",
      "alamat_lengkap",
      "property_address",
      "place_property_address",
    ];

    final fromKos = pickSafeTextFromMap(kos, addressKeys);
    if (fromKos.isNotEmpty) return fromKos;

    final fromProperty = pickSafeTextFromMap(property, addressKeys);
    if (fromProperty.isNotEmpty) return fromProperty;

    final fromPlaceProperty = pickSafeTextFromMap(placeProperty, addressKeys);
    if (fromPlaceProperty.isNotEmpty) return fromPlaceProperty;

    final fromPlacePropertyCamel = pickSafeTextFromMap(
      placePropertyCamel,
      addressKeys,
    );
    if (fromPlacePropertyCamel.isNotEmpty) return fromPlacePropertyCamel;

    final fromPlaceProperties = pickSafeTextFromMap(
      placeProperties,
      addressKeys,
    );
    if (fromPlaceProperties.isNotEmpty) return fromPlaceProperties;

    final fromPlacePropertiesCamel = pickSafeTextFromMap(
      placePropertiesCamel,
      addressKeys,
    );
    if (fromPlacePropertiesCamel.isNotEmpty) return fromPlacePropertiesCamel;

    final fromKosMap = pickSafeTextFromMap(kosMap, addressKeys);
    if (fromKosMap.isNotEmpty) return fromKosMap;

    final fromKostMap = pickSafeTextFromMap(kostMap, addressKeys);
    if (fromKostMap.isNotEmpty) return fromKostMap;

    final fromPlace = pickSafeTextFromMap(place, addressKeys);
    if (fromPlace.isNotEmpty) return fromPlace;

    final addressText = safeString(address);

    if (addressText.isNotEmpty) {
      return addressText;
    }

    return "Alamat belum tersedia";
  }

  Future<void> saveRentalPropertyCache({
    required int rentalBookingId,
    required int bookingId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final propertyName = getKosNameForBackend();
      final propertyAddress = getKosAddressForBackend();
      final propertyIdValue = propertyId ?? 0;

      final payload = {
        "rental_booking_id": rentalBookingId,
        "booking_id": bookingId,
        "property_id": propertyIdValue,
        "place_property_id": propertyIdValue,
        "place_properties_id": propertyIdValue,
        "property_name": propertyName,
        "place_property_name": propertyName,
        "nama_kos": propertyName,
        "nama_kost": propertyName,
        "kos_name": propertyName,
        "kost_name": propertyName,
        "property_title": propertyName,
        "title": propertyName,
        "property_address": propertyAddress,
        "place_property_address": propertyAddress,
        "address": propertyAddress,
        "alamat": propertyAddress,
        "location": propertyAddress,
        "lokasi": propertyAddress,
        "saved_at": DateTime.now().toIso8601String(),
      };

      await prefs.setString(
        "rental_property_info_$rentalBookingId",
        jsonEncode(payload),
      );

      if (propertyIdValue > 0) {
        await prefs.setString(
          "property_info_$propertyIdValue",
          jsonEncode(payload),
        );
      }

      final cachedRentalIds =
          prefs.getStringList("cached_rental_property_ids") ?? [];

      if (!cachedRentalIds.contains(rentalBookingId.toString())) {
        cachedRentalIds.add(rentalBookingId.toString());

        await prefs.setStringList(
          "cached_rental_property_ids",
          cachedRentalIds,
        );
      }

      debugPrint("SAVE RENTAL PROPERTY CACHE:");
      debugPrint(payload.toString());
    } catch (e) {
      debugPrint("SAVE RENTAL PROPERTY CACHE ERROR:");
      debugPrint(e.toString());
    }
  }

  int getPropertyIdFromBooking(Map<String, dynamic> map) {
    final property = toMap(map['property']);
    final placeProperty = toMap(map['place_property']);
    final placePropertyCamel = toMap(map['placeProperty']);
    final placeProperties = toMap(map['place_properties']);
    final placePropertiesCamel = toMap(map['placeProperties']);
    final kosMap = toMap(map['kos']);
    final kostMap = toMap(map['kost']);

    int id = parseIntValue(
      map['place_properties_id'] ??
          map['place_property_id'] ??
          map['property_id'] ??
          map['placePropertyId'] ??
          map['propertyId'] ??
          property?['id'] ??
          placeProperty?['id'] ??
          placePropertyCamel?['id'] ??
          placeProperties?['id'] ??
          placePropertiesCamel?['id'] ??
          kosMap?['id'] ??
          kostMap?['id'],
    );

    if (id > 0) return id;

    final placePropertiesList = map['place_properties'];

    if (placePropertiesList is List && placePropertiesList.isNotEmpty) {
      final first = toMap(placePropertiesList.first);

      id = parseIntValue(first?['id']);

      if (id > 0) return id;
    }

    final placesList = map['places'];

    if (placesList is List && placesList.isNotEmpty) {
      final first = toMap(placesList.first);

      id = parseIntValue(first?['id']);

      if (id > 0) return id;
    }

    return 0;
  }

  bool isSurveyBooking(Map<String, dynamic> map) {
    final bookingType = cleanLower(
      map['booking_type'] ??
          map['type'] ??
          map['category'] ??
          map['booking_category'],
    );

    final hasVisitDate =
        map['visit_date'] != null ||
        map['visit_time'] != null ||
        map['survey_date'] != null ||
        map['survey_time'] != null;

    final isRental =
        bookingType.contains("rental") ||
        bookingType.contains("rent") ||
        bookingType.contains("sewa");

    if (bookingType.contains("survey")) return true;

    if (hasVisitDate && !isRental) return true;

    return false;
  }

  bool isBookingAccepted(Map<String, dynamic> map) {
    final status = cleanLower(
      map['status'] ??
          map['booking_status'] ??
          map['approval_status'] ??
          map['state'],
    );

    return status == "accepted" ||
        status == "accept" ||
        status == "approve" ||
        status == "approved" ||
        status == "confirmed" ||
        status == "confirm" ||
        status == "success" ||
        status == "active" ||
        status == "diterima";
  }

  DateTime? getBookingDate(Map<String, dynamic> map) {
    final raw =
        map['updated_at']?.toString() ??
        map['created_at']?.toString() ??
        map['visit_date']?.toString() ??
        map['survey_date']?.toString() ??
        "";

    if (raw.trim().isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  bool isAcceptedSurveyBooking(dynamic item) {
    final map = toMap(item);

    if (map == null) return false;

    final bookingId = parseIntValue(map['id'] ?? map['booking_id']);

    final status = cleanLower(
      map['status'] ??
          map['booking_status'] ??
          map['approval_status'] ??
          map['state'],
    );

    final bookingType = cleanLower(
      map['booking_type'] ??
          map['type'] ??
          map['category'] ??
          map['booking_category'],
    );

    final itemPropertyId = getPropertyIdFromBooking(map);
    final currentPropertyId = parseIntValue(propertyId);

    debugPrint("CHECK BOOKING ITEM:");
    debugPrint(
      {
        "booking_id": bookingId,
        "type": bookingType,
        "status": status,
        "item_property_id": itemPropertyId,
        "current_property_id": currentPropertyId,
        "is_survey": isSurveyBooking(map),
        "is_accepted": isBookingAccepted(map),
      }.toString(),
    );

    final sameProperty = itemPropertyId == currentPropertyId;

    return isSurveyBooking(map) && isBookingAccepted(map) && sameProperty;
  }

  Future<Map<String, dynamic>?> getAcceptedSurveyBooking() async {
    final token = await ApiService().getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan, silakan login ulang");
    }

    final response = await http.get(
      Uri.parse("${ApiService.baseUrl}/bookings"),
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );

    debugPrint("GET BOOKINGS FOR RENTAL STATUS:");
    debugPrint(response.statusCode.toString());

    debugPrint("GET BOOKINGS FOR RENTAL RESPONSE:");
    debugPrint(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        parseResponseMessage(response.body, "Gagal mengecek status survey"),
      );
    }

    final decoded = jsonDecode(response.body);
    final bookings = parseDynamicList(decoded);

    final acceptedSurveyBookings = bookings
        .where(isAcceptedSurveyBooking)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    acceptedSurveyBookings.sort((a, b) {
      final dateA = getBookingDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = getBookingDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);

      return dateB.compareTo(dateA);
    });

    if (acceptedSurveyBookings.isNotEmpty) {
      return acceptedSurveyBookings.first;
    }

    debugPrint("NO ACCEPTED SURVEY FOUND. ALL BOOKING SUMMARY:");

    for (final item in bookings) {
      final map = toMap(item);

      if (map == null) continue;

      debugPrint(
        {
          "id": map['id'],
          "booking_id": map['booking_id'],
          "type": map['booking_type'] ?? map['type'] ?? map['category'],
          "status": map['status'] ?? map['booking_status'],
          "property_id": getPropertyIdFromBooking(map),
          "visit_date": map['visit_date'],
          "visit_time": map['visit_time'],
        }.toString(),
      );
    }

    return null;
  }

  int getAcceptedSurveyBookingId(Map<String, dynamic> data) {
    final booking = data['booking'];

    if (booking is Map) {
      final id = parseIntValue(booking['id'] ?? booking['booking_id']);

      if (id > 0) return id;
    }

    return parseIntValue(data['id'] ?? data['booking_id']);
  }

  void readArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;

    Map<String, dynamic> routeData = {};

    if (args is Map) {
      final argKos = args['kos'];

      if (argKos is Map<String, dynamic>) {
        routeData = Map<String, dynamic>.from(argKos);
      } else if (argKos is Map) {
        routeData = Map<String, dynamic>.from(argKos);
      }

      propertyId = parseIntValue(
        args['place_properties_id'] ??
            args['place_property_id'] ??
            args['property_id'] ??
            args['id'],
      );

      title = safeString(args['title'] ?? args['name']);
      address = safeString(args['address'] ?? args['alamat']);

      final owner = args['owner'];

      if (owner is Map) {
        ownerId = parseIntValue(owner['id']);
        ownerName = safeString(owner['name']).isNotEmpty
            ? safeString(owner['name'])
            : "Pemilik Kos";
      }

      if (ownerId == null || ownerId! <= 0) {
        ownerId = parseIntValue(args['owner_id']);
      }

      final argsOwnerName = safeString(args['owner_name']);

      if (argsOwnerName.isNotEmpty) {
        ownerName = argsOwnerName;
      }
    }

    if (widget.kos != null) {
      routeData = Map<String, dynamic>.from(widget.kos!);
    }

    propertyId ??= widget.propertyId;

    if (routeData.isNotEmpty) {
      kos = routeData;

      if (propertyId == null || propertyId! <= 0) {
        propertyId = parseIntValue(
          routeData['id'] ??
              routeData['place_properties_id'] ??
              routeData['place_property_id'] ??
              routeData['property_id'] ??
              routeData['propertyId'],
        );
      }

      final safeTitle = safeString(
        routeData['title'] ??
            routeData['property_name'] ??
            routeData['nama_kos'] ??
            routeData['nama_kost'] ??
            routeData['kos_name'] ??
            routeData['kost_name'] ??
            routeData['place_name'] ??
            routeData['name'],
      );

      if (title.trim().isEmpty && safeTitle.isNotEmpty) {
        title = safeTitle;
      }

      final safeAddress = safeString(
        routeData['address'] ??
            routeData['alamat'] ??
            routeData['location'] ??
            routeData['lokasi'],
      );

      if (address.trim().isEmpty && safeAddress.isNotEmpty) {
        address = safeAddress;
      }

      final owner = routeData['owner'];

      if (owner is Map) {
        if (ownerId == null || ownerId! <= 0) {
          ownerId = parseIntValue(owner['id']);
        }

        final safeOwnerName = safeString(owner['name']);

        if (safeOwnerName.isNotEmpty) {
          ownerName = safeOwnerName;
        }
      }

      if (ownerId == null || ownerId! <= 0) {
        ownerId = parseIntValue(routeData['owner_id']);
      }

      final safeOwnerName = safeString(routeData['owner_name']);

      if (safeOwnerName.isNotEmpty) {
        ownerName = safeOwnerName;
      }
    }

    final fixedName = getKosNameForBackend();

    if (fixedName.isNotEmpty && fixedName != "Nama kos tidak tersedia") {
      title = fixedName;
    }

    final fixedAddress = getKosAddressForBackend();

    if (fixedAddress.isNotEmpty && fixedAddress != "Alamat belum tersedia") {
      address = fixedAddress;
    }

    if (title.trim().isEmpty) {
      title = "Kos";
    }
  }

  void prepareRentalOptions() {
    final night = getPriceValue(
      kos['price_perNight'] ?? kos['price_per_night'] ?? kos['pricePerNight'],
    );

    final week = getPriceValue(
      kos['price_perWeek'] ?? kos['price_per_week'] ?? kos['pricePerWeek'],
    );

    final month = getPriceValue(
      kos['price_perMonth'] ?? kos['price_per_month'] ?? kos['pricePerMonth'],
    );

    final year = getPriceValue(
      kos['price_perYear'] ?? kos['price_per_year'] ?? kos['pricePerYear'],
    );

    final List<_RentalOption> options = [];

    if (night > 0) {
      options.add(
        _RentalOption(
          type: "night",
          title: "Harian",
          unitLabel: "malam",
          priceLabel: "per malam",
          price: night,
          icon: Icons.night_shelter_rounded,
        ),
      );
    }

    if (week > 0) {
      options.add(
        _RentalOption(
          type: "week",
          title: "Mingguan",
          unitLabel: "minggu",
          priceLabel: "per minggu",
          price: week,
          icon: Icons.date_range_rounded,
        ),
      );
    }

    if (month > 0) {
      options.add(
        _RentalOption(
          type: "month",
          title: "Bulanan",
          unitLabel: "bulan",
          priceLabel: "per bulan",
          price: month,
          icon: Icons.calendar_month_rounded,
        ),
      );
    }

    if (year > 0) {
      options.add(
        _RentalOption(
          type: "year",
          title: "Tahunan",
          unitLabel: "tahun",
          priceLabel: "per tahun",
          price: year,
          icon: Icons.event_available_rounded,
        ),
      );
    }

    rentalOptions = options;

    if (rentalOptions.isNotEmpty) {
      selectedOption = rentalOptions.first;
    }
  }

  int getPriceValue(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return 0;

    text = text.replaceAll("Rp", "").trim();

    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text)?.round() ?? 0;
    }

    if (RegExp(r'^\d+,\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text.replaceAll(",", "."))?.round() ?? 0;
    }

    if (RegExp(r',\d{1,2}$').hasMatch(text)) {
      text = text.split(',').first;
    }

    if (RegExp(r'\.\d{1,2}$').hasMatch(text)) {
      text = text.split('.').first;
    }

    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return 0;

    return int.tryParse(cleaned) ?? 0;
  }

  int get totalPrice {
    if (selectedOption == null) return 0;

    return selectedOption!.price * duration;
  }

  DateTime? get endDate {
    if (startDate == null || selectedOption == null) return null;

    if (selectedOption!.type == "daily" ||
        selectedOption!.type == "day" ||
        selectedOption!.type == "night" ||
        selectedOption!.type == "per_day" ||
        selectedOption!.type == "per_night" ||
        selectedOption!.type == "harian") {
      return startDate!.add(Duration(days: duration));
    }

    if (selectedOption!.type == "week") {
      return startDate!.add(Duration(days: duration * 7));
    }

    if (selectedOption!.type == "month") {
      return DateTime(
        startDate!.year,
        startDate!.month + duration,
        startDate!.day,
      );
    }

    if (selectedOption!.type == "year") {
      return DateTime(
        startDate!.year + duration,
        startDate!.month,
        startDate!.day,
      );
    }

    return startDate;
  }

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String formatDate(DateTime date) {
    return "${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}";
  }

  String formatReadableDate(DateTime? date) {
    if (date == null) return "Belum dipilih";

    final months = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String formatRupiah(dynamic value) {
    if (value == null) return "0";

    String raw = value.toString().trim();

    if (raw.isEmpty || raw == "null") return "0";

    raw = raw.replaceAll("Rp", "").trim();

    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(raw)) {
      raw = (double.tryParse(raw)?.round() ?? 0).toString();
    } else if (RegExp(r'^\d+,\d{1,2}$').hasMatch(raw)) {
      raw = (double.tryParse(raw.replaceAll(",", "."))?.round() ?? 0)
          .toString();
    } else {
      if (RegExp(r',\d{1,2}$').hasMatch(raw)) {
        raw = raw.split(',').first;
      }

      if (RegExp(r'\.\d{1,2}$').hasMatch(raw)) {
        raw = raw.split('.').first;
      }
    }

    final number = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (number.isEmpty) return "0";

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

  String getImageUrl() {
    final mainImage = kos['main_image'];

    if (mainImage != null && mainImage.toString() != "null") {
      final fixed = fixUrl(mainImage);

      if (fixed.isNotEmpty) return fixed;
    }

    final images = kos['images'];

    if (images is List && images.isNotEmpty) {
      final fixed = fixUrl(images.first);

      if (fixed.isNotEmpty) return fixed;
    }

    return "";
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

  Future<void> pickStartDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      initialDate: startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: "Pilih Tanggal Mulai Sewa",
      cancelText: "Batal",
      confirmText: "Pilih",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null) return;

    setState(() {
      startDate = result;
    });
  }

  bool validateForm() {
    if (propertyId == null || propertyId! <= 0) {
      showMessage("ID kos tidak ditemukan");
      return false;
    }

    if (selectedOption == null) {
      showMessage("Pilih jenis sewa terlebih dahulu");
      return false;
    }

    if (startDate == null) {
      showMessage("Pilih tanggal mulai sewa terlebih dahulu");
      return false;
    }

    if (duration <= 0) {
      showMessage("Durasi sewa tidak valid");
      return false;
    }

    if (totalPrice <= 0) {
      showMessage("Total pembayaran tidak valid");
      return false;
    }

    if (senderNameController.text.trim().isEmpty) {
      showMessage("Nama pengirim wajib diisi");
      return false;
    }

    return true;
  }

  Map<String, dynamic> parseResponseData(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];

        if (data is Map<String, dynamic>) {
          return data;
        }

        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }

        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {};
    } catch (_) {
      return {};
    }
  }

  String parseResponseMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        String message = decoded['message']?.toString() ?? fallback;

        final errors = decoded['errors'];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          } else {
            message = firstError.toString();
          }
        }

        return message;
      }

      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  bool isDailyRentalType(String type) {
    final clean = type.toLowerCase().trim();

    return clean == "daily" ||
        clean == "day" ||
        clean == "night" ||
        clean == "per_day" ||
        clean == "per_night" ||
        clean == "harian";
  }

  List<String> getDurationTypeCandidates(String type) {
    if (isDailyRentalType(type)) {
      return ["night"];
    }

    return [type];
  }

  bool isDurationTypeInvalidResponse(String body) {
    final lower = body.toLowerCase();

    return lower.contains("duration_type") && lower.contains("invalid");
  }

  Future<Map<String, dynamic>> createRentalBooking({
    required int bookingId,
  }) async {
    final token = await ApiService().getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan, silakan login ulang");
    }

    final option = selectedOption!;
    final start = formatDate(startDate!);
    final end = endDate == null ? start : formatDate(endDate!);

    final durationTypeCandidates = getDurationTypeCandidates(option.type);

    String lastErrorMessage = "Gagal mengajukan sewa";

    for (final durationType in durationTypeCandidates) {
      final propertyNameForBackend = getKosNameForBackend();
      final propertyAddressForBackend = getKosAddressForBackend();

      final body = {
        'booking_id': bookingId.toString(),

        'place_properties_id': propertyId.toString(),
        'property_id': propertyId.toString(),
        'place_property_id': propertyId.toString(),

        'property_name': propertyNameForBackend,
        'place_property_name': propertyNameForBackend,
        'nama_kos': propertyNameForBackend,
        'nama_kost': propertyNameForBackend,
        'kos_name': propertyNameForBackend,
        'kost_name': propertyNameForBackend,
        'property_title': propertyNameForBackend,
        'title': propertyNameForBackend,

        'property_address': propertyAddressForBackend,
        'place_property_address': propertyAddressForBackend,
        'address': propertyAddressForBackend,
        'alamat': propertyAddressForBackend,
        'location': propertyAddressForBackend,
        'lokasi': propertyAddressForBackend,

        'rental_type': durationType,
        'rent_type': durationType,
        'type': durationType,
        'period_type': durationType,
        'rental_period': durationType,
        'duration_type': durationType,

        'duration': duration.toString(),
        'rental_duration': duration.toString(),
        'total_duration': duration.toString(),

        'start_date': start,
        'end_date': end,
        'check_in': start,
        'check_out': end,

        'price': option.price.toString(),
        'unit_price': option.price.toString(),
        'total_price': totalPrice.toString(),
        'amount': totalPrice.toString(),
        'grand_total': totalPrice.toString(),

        'status': 'pending',
        'payment_status': 'pending',
      };

      if (ownerId != null && ownerId! > 0) {
        body['owner_id'] = ownerId.toString();
      }

      debugPrint("CREATE RENTAL BOOKING BODY:");
      debugPrint(body.toString());

      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/rental-bookings"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: body,
      );

      debugPrint("CREATE RENTAL BOOKING STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("CREATE RENTAL BOOKING RESPONSE:");
      debugPrint(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return parseResponseData(response.body);
      }

      lastErrorMessage = parseResponseMessage(
        response.body,
        "Gagal mengajukan sewa",
      );

      if (isDailyRentalType(option.type) &&
          response.statusCode == 422 &&
          isDurationTypeInvalidResponse(response.body)) {
        debugPrint("DURATION TYPE '$durationType' DITOLAK, COBA VALUE LAIN...");
        continue;
      }

      throw Exception(lastErrorMessage);
    }

    throw Exception(lastErrorMessage);
  }

  int getRentalBookingId(Map<String, dynamic> data) {
    final directId = parseIntValue(
      data['rental_booking_id'] ??
          data['rentalBookingId'] ??
          data['rental_id'] ??
          data['id'],
    );

    if (directId > 0) return directId;

    final rentalBooking =
        toMap(data['rental_booking']) ??
        toMap(data['rentalBooking']) ??
        toMap(data['rental']);

    if (rentalBooking != null) {
      final nestedId = parseIntValue(
        rentalBooking['rental_booking_id'] ??
            rentalBooking['rentalBookingId'] ??
            rentalBooking['rental_id'] ??
            rentalBooking['id'],
      );

      if (nestedId > 0) return nestedId;
    }

    final nestedData = toMap(data['data']);

    if (nestedData != null) {
      final nestedDirectId = parseIntValue(
        nestedData['rental_booking_id'] ??
            nestedData['rentalBookingId'] ??
            nestedData['rental_id'] ??
            nestedData['id'],
      );

      if (nestedDirectId > 0) return nestedDirectId;

      final nestedRentalBooking =
          toMap(nestedData['rental_booking']) ??
          toMap(nestedData['rentalBooking']) ??
          toMap(nestedData['rental']);

      if (nestedRentalBooking != null) {
        final nestedRentalId = parseIntValue(
          nestedRentalBooking['rental_booking_id'] ??
              nestedRentalBooking['rentalBookingId'] ??
              nestedRentalBooking['rental_id'] ??
              nestedRentalBooking['id'],
        );

        if (nestedRentalId > 0) return nestedRentalId;
      }
    }

    return 0;
  }

  Future<void> submitRentalBooking() async {
    if (!validateForm()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final acceptedSurveyBooking = await getAcceptedSurveyBooking();

      if (acceptedSurveyBooking == null) {
        throw Exception(
          "Survey untuk kos ini belum diterima owner. Pastikan owner sudah menekan Accept pada pengajuan survey terlebih dahulu.",
        );
      }

      final bookingId = getAcceptedSurveyBookingId(acceptedSurveyBooking);

      if (bookingId <= 0) {
        throw Exception(
          "Survey sudah diterima, tapi ID booking survey tidak ditemukan.",
        );
      }

      final rentalBookingData = await createRentalBooking(bookingId: bookingId);

      debugPrint("PARSED RENTAL BOOKING DATA:");
      debugPrint(rentalBookingData.toString());

      final rentalBookingId = getRentalBookingId(rentalBookingData);

      debugPrint("FINAL RENTAL BOOKING ID:");
      debugPrint(rentalBookingId.toString());

      debugPrint("SURVEY BOOKING ID:");
      debugPrint(bookingId.toString());

      if (rentalBookingId <= 0) {
        throw Exception(
          "Pengajuan sewa berhasil dibuat, tapi ID rental booking tidak ditemukan",
        );
      }

      if (rentalBookingId == bookingId) {
        throw Exception(
          "ID rental booking terbaca sama dengan ID survey. Response backend belum mengirim ID rental booking yang benar.",
        );
      }

      await saveRentalPropertyCache(
        rentalBookingId: rentalBookingId,
        bookingId: bookingId,
      );

      if (!mounted) return;

      showMessage("Pengajuan sewa berhasil dibuat", success: true);

      final propertyNameForBackend = getKosNameForBackend();
      final propertyAddressForBackend = getKosAddressForBackend();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: RouteSettings(
            arguments: {
              'booking': acceptedSurveyBooking,
              'booking_id': bookingId,

              'rental_booking': rentalBookingData,
              'rental_booking_id': rentalBookingId,

              'kos': kos,
              'property_id': propertyId,
              'place_property_id': propertyId,
              'place_properties_id': propertyId,

              'property_name': propertyNameForBackend,
              'place_property_name': propertyNameForBackend,
              'nama_kos': propertyNameForBackend,
              'nama_kost': propertyNameForBackend,
              'kos_name': propertyNameForBackend,
              'kost_name': propertyNameForBackend,
              'property_title': propertyNameForBackend,

              'property_address': propertyAddressForBackend,
              'place_property_address': propertyAddressForBackend,
              'alamat': propertyAddressForBackend,
              'location': propertyAddressForBackend,
              'lokasi': propertyAddressForBackend,

              'title': propertyNameForBackend,
              'address': propertyAddressForBackend,
              'owner_id': ownerId,
              'owner_name': ownerName,

              'rental_type': selectedOption?.type,
              'rental_title': selectedOption?.title,
              'duration': duration,
              'duration_label': selectedOption?.unitLabel,

              'start_date': formatDate(startDate!),
              'end_date': endDate == null ? null : formatDate(endDate!),

              'unit_price': selectedOption?.price,
              'total_price': totalPrice,
              'amount': totalPrice,

              'sender_name': senderNameController.text.trim(),
              'notes': notesController.text.trim(),
            },
          ),
          builder: (_) => const Payment(),
        ),
      );
    } catch (e) {
      debugPrint("SUBMIT RENTAL BOOKING ERROR:");
      debugPrint(e.toString());

      String message = e.toString();

      if (message.startsWith("Exception: ")) {
        message = message.replaceFirst("Exception: ", "");
      }

      showMessage(message);
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildHeader() {
    final imageUrl = getImageUrl();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: imageUrl.isEmpty
                  ? const Icon(
                      Icons.home_work_outlined,
                      color: Colors.white,
                      size: 38,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.home_work_outlined,
                          color: Colors.white,
                          size: 38,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "Pengajuan Sewa",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address.trim().isEmpty ? "Alamat belum ditambahkan" : address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
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
                    fontWeight: FontWeight.w900,
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

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, color: primaryColor, size: 22),
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ),
    );
  }

  Widget rentalTypeSection() {
    if (rentalOptions.isEmpty) {
      return sectionCard(
        title: "Jenis Sewa",
        icon: Icons.home_work_rounded,
        children: const [
          Text(
            "Harga sewa belum tersedia untuk kos ini.",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return sectionCard(
      title: "Jenis Sewa",
      icon: Icons.home_work_rounded,
      children: [
        ...rentalOptions.map((option) {
          final selected = selectedOption?.type == option.type;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedOption = option;
                duration = 1;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? softGreen : const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade200,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      option.icon,
                      color: selected ? Colors.white : primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Rp ${formatRupiah(option.price)} ${option.priceLabel}",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? primaryColor : Colors.grey,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget scheduleSection() {
    return sectionCard(
      title: "Jadwal Sewa",
      icon: Icons.calendar_month_rounded,
      children: [
        GestureDetector(
          onTap: pickStartDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tanggal Mulai",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatReadableDate(startDate),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.timelapse_rounded, color: primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Durasi: $duration ${selectedOption?.unitLabel ?? ''}",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: duration <= 1
                    ? null
                    : () {
                        setState(() {
                          duration--;
                        });
                      },
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: primaryColor,
              ),
              Text(
                "$duration",
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    duration++;
                  });
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Selesai: ${formatReadableDate(endDate)}",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget paymentInfoSection() {
    return sectionCard(
      title: "Data Pembayaran",
      icon: Icons.account_balance_wallet_rounded,
      children: [
        inputField(
          controller: senderNameController,
          label: "Nama Pengirim *",
          hint: "Wajib diisi, contoh: Rahes",
          icon: Icons.person_rounded,
        ),
        inputField(
          controller: notesController,
          label: "Catatan",
          hint: "Opsional, contoh: pembayaran sewa kos",
          icon: Icons.notes_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget summarySection() {
    return sectionCard(
      title: "Ringkasan",
      icon: Icons.receipt_long_rounded,
      children: [
        summaryRow("Nama Kos", getKosNameForBackend()),
        summaryRow("Owner", ownerName),
        summaryRow("Jenis Sewa", selectedOption?.title ?? "-"),
        summaryRow("Durasi", "$duration ${selectedOption?.unitLabel ?? ''}"),
        summaryRow("Mulai", formatReadableDate(startDate)),
        summaryRow("Selesai", formatReadableDate(endDate)),
        const Divider(height: 24),
        summaryRow("Harga Satuan", "Rp ${formatRupiah(selectedOption?.price)}"),
        summaryRow("Total", "Rp ${formatRupiah(totalPrice)}"),
      ],
    );
  }

  Widget submitButton() {
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
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: isLoading ? null : submitRentalBooking,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              isLoading ? "Memproses..." : "Ajukan Sewa & Lanjut Payment",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      bottomNavigationBar: submitButton(),
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Pengajuan Sewa",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 115),
          child: Column(
            children: [
              buildHeader(),
              rentalTypeSection(),
              scheduleSection(),
              paymentInfoSection(),
              summarySection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RentalOption {
  final String type;
  final String title;
  final String unitLabel;
  final String priceLabel;
  final int price;
  final IconData icon;

  const _RentalOption({
    required this.type,
    required this.title,
    required this.unitLabel,
    required this.price,
    required this.priceLabel,
    required this.icon,
  });
}
