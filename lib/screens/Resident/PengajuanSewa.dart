import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Resident/Payment.dart';
import 'package:koskaki/service/api_service.dart';

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

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<dynamic> parseDynamicList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value;
    }

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

  int parseIntValue(dynamic value) {
    if (value == null) return 0;

    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return 0;

    return int.tryParse(cleaned) ?? 0;
  }

  String cleanLower(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
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

      propertyId = int.tryParse(
        args['place_properties_id']?.toString() ??
            args['place_property_id']?.toString() ??
            args['property_id']?.toString() ??
            args['id']?.toString() ??
            "",
      );

      title = args['title']?.toString() ?? args['name']?.toString() ?? "";
      address = args['address']?.toString() ?? "";

      final owner = args['owner'];

      if (owner is Map) {
        ownerId = int.tryParse(owner['id']?.toString() ?? "");
        ownerName = owner['name']?.toString() ?? "Pemilik Kos";
      }

      ownerId ??= int.tryParse(args['owner_id']?.toString() ?? "");
      ownerName = args['owner_name']?.toString() ?? ownerName;
    }

    if (widget.kos != null) {
      routeData = Map<String, dynamic>.from(widget.kos!);
    }

    propertyId ??= widget.propertyId;

    if (routeData.isNotEmpty) {
      kos = routeData;

      propertyId ??= int.tryParse(
        routeData['id']?.toString() ??
            routeData['place_properties_id']?.toString() ??
            routeData['place_property_id']?.toString() ??
            routeData['property_id']?.toString() ??
            "",
      );

      title = title.trim().isNotEmpty
          ? title
          : routeData['title']?.toString() ??
                routeData['name']?.toString() ??
                "Kos";

      address = address.trim().isNotEmpty
          ? address
          : routeData['address']?.toString() ?? "";

      final owner = routeData['owner'];

      if (owner is Map) {
        ownerId ??= int.tryParse(owner['id']?.toString() ?? "");
        ownerName = owner['name']?.toString() ?? "Pemilik Kos";
      }

      ownerId ??= int.tryParse(routeData['owner_id']?.toString() ?? "");
      ownerName = routeData['owner_name']?.toString() ?? ownerName;
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
          type: "daily",
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

    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

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

    final number = value.toString().replaceAll(RegExp(r'[^0-9]'), '');

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
      return ["daily", "per_day", "day", "night", "per_night", "harian"];
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
      final body = {
        'booking_id': bookingId.toString(),

        'place_properties_id': propertyId.toString(),
        'property_id': propertyId.toString(),
        'place_property_id': propertyId.toString(),

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
      data['id'] ??
          data['rental_booking_id'] ??
          data['rentalBookingId'] ??
          data['rental_id'],
    );

    if (directId > 0) return directId;

    final rentalBooking =
        toMap(data['rental_booking']) ??
        toMap(data['rentalBooking']) ??
        toMap(data['rental']) ??
        toMap(data['booking']);

    if (rentalBooking != null) {
      final nestedId = parseIntValue(
        rentalBooking['id'] ??
            rentalBooking['rental_booking_id'] ??
            rentalBooking['rentalBookingId'] ??
            rentalBooking['booking_id'],
      );

      if (nestedId > 0) return nestedId;
    }

    final nestedData = toMap(data['data']);

    if (nestedData != null) {
      final nestedDirectId = parseIntValue(
        nestedData['id'] ??
            nestedData['rental_booking_id'] ??
            nestedData['rentalBookingId'] ??
            nestedData['rental_id'],
      );

      if (nestedDirectId > 0) return nestedDirectId;

      final nestedRentalBooking =
          toMap(nestedData['rental_booking']) ??
          toMap(nestedData['rentalBooking']) ??
          toMap(nestedData['rental']) ??
          toMap(nestedData['booking']);

      if (nestedRentalBooking != null) {
        final nestedRentalId = parseIntValue(
          nestedRentalBooking['id'] ??
              nestedRentalBooking['rental_booking_id'] ??
              nestedRentalBooking['rentalBookingId'] ??
              nestedRentalBooking['booking_id'],
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

      final rentalBookingId = getRentalBookingId(rentalBookingData);

      if (rentalBookingId <= 0) {
        throw Exception(
          "Pengajuan sewa berhasil dibuat, tapi ID rental booking tidak ditemukan",
        );
      }

      if (!mounted) return;

      showMessage("Pengajuan sewa berhasil dibuat", success: true);

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

              'title': title,
              'address': address,
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

  Widget rentalOptionCard(_RentalOption option) {
    final isSelected = selectedOption?.type == option.type;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          selectedOption = option;
          duration = 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: 1.4,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              option.icon,
              color: isSelected ? Colors.white : primaryColor,
              size: 26,
            ),
            const Spacer(),
            Text(
              option.title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Rp ${formatRupiah(option.price)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.priceLabel,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withOpacity(0.72)
                    : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget rentalTypeSection() {
    return sectionCard(
      title: "Pilih Jenis Sewa",
      icon: Icons.sell_outlined,
      children: [
        if (rentalOptions.isEmpty)
          emptyState(
            icon: Icons.money_off_outlined,
            text: "Harga sewa belum tersedia",
          )
        else
          GridView.builder(
            itemCount: rentalOptions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.22,
            ),
            itemBuilder: (context, index) {
              return rentalOptionCard(rentalOptions[index]);
            },
          ),
      ],
    );
  }

  Widget dateButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: pickStartDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tanggal Mulai Sewa",
                    style: TextStyle(
                      color: Colors.grey.shade600,
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
            Icon(
              Icons.keyboard_arrow_right_rounded,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget durationSelector() {
    final unit = selectedOption?.unitLabel ?? "durasi";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: softGreen, shape: BoxShape.circle),
            child: Icon(Icons.timelapse_rounded, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Durasi Sewa",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$duration $unit",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              smallCircleButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (duration <= 1) return;

                  setState(() {
                    duration--;
                  });
                },
              ),
              const SizedBox(width: 8),
              smallCircleButton(
                icon: Icons.add_rounded,
                onTap: () {
                  setState(() {
                    duration++;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget smallCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget scheduleSection() {
    return sectionCard(
      title: "Jadwal & Durasi",
      icon: Icons.event_available_rounded,
      children: [dateButton(), const SizedBox(height: 12), durationSelector()],
    );
  }

  Widget summaryItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget totalBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Pembayaran",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rp ${formatRupiah(totalPrice)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget summarySection() {
    final option = selectedOption;

    return sectionCard(
      title: "Ringkasan Sewa",
      icon: Icons.fact_check_outlined,
      children: [
        summaryItem(icon: Icons.home_work_outlined, title: "Kos", value: title),
        summaryItem(
          icon: Icons.sell_outlined,
          title: "Jenis Sewa",
          value: option == null
              ? "Belum dipilih"
              : "${option.title} • Rp ${formatRupiah(option.price)} ${option.priceLabel}",
        ),
        summaryItem(
          icon: Icons.timelapse_rounded,
          title: "Durasi",
          value: option == null
              ? "$duration durasi"
              : "$duration ${option.unitLabel}",
        ),
        summaryItem(
          icon: Icons.calendar_today_rounded,
          title: "Tanggal Mulai",
          value: formatReadableDate(startDate),
        ),
        summaryItem(
          icon: Icons.event_available_rounded,
          title: "Estimasi Selesai",
          value: formatReadableDate(endDate),
        ),
        const SizedBox(height: 6),
        totalBox(),
      ],
    );
  }

  Widget emptyState({required IconData icon, required String text}) {
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
    required this.priceLabel,
    required this.price,
    required this.icon,
  });
}
