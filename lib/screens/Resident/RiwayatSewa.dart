import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryColor = Color(0xFF2D2F8F);
const Color secondaryColor = Color(0xFF5B5FEF);
const Color softBlue = Color(0xFFEFF2FF);
const Color darkText = Color(0xFF161A33);

class RiwayatSewa extends StatefulWidget {
  const RiwayatSewa({super.key});

  @override
  State<RiwayatSewa> createState() => _RiwayatSewaState();
}

class RiwayatSewaPage extends RiwayatSewa {
  const RiwayatSewaPage({super.key});
}

class _RiwayatSewaState extends State<RiwayatSewa> {
  bool loading = true;
  bool uploadingInvoicePayment = false;

  String? errorMessage;

  List<Map<String, dynamic>> histories = [];

  Map<int, Map<String, dynamic>> familyCodesByRentalId = {};
  Set<int> generatingFamilyCodeRentalIds = {};

  final ImagePicker imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadRiwayatSewa();
  }

  void goToHomePage() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  String cleanToken(String? token) {
    if (token == null) return "";

    String cleaned = token.trim();

    if (cleaned.toLowerCase().startsWith("bearer ")) {
      cleaned = cleaned.substring(7).trim();
    }

    cleaned = cleaned.replaceAll('"', '').replaceAll("'", "").trim();

    return cleaned;
  }

  Map<String, String> authHeaders(String token) {
    final cleanedToken = cleanToken(token);

    return {
      "Accept": "application/json",
      "Authorization": "Bearer $cleanedToken",
      "X-Requested-With": "XMLHttpRequest",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
    };
  }

  Future<Map<String, dynamic>?> readCachedPropertyInfo(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
  
      if (raw == null || raw.trim().isEmpty) return null;
  
      final decoded = jsonDecode(raw);
  
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
  
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
  
      return null;
    } catch (e) {
      debugPrint("READ CACHED PROPERTY INFO ERROR:");
      debugPrint(e.toString());
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> getCachedPropertyInfo({
    required int rentalId,
    int? bookingId,
    int? propertyId,
  }) async {
    final keys = <String>[];
  
    if (rentalId > 0) {
      keys.add("rental_property_info_$rentalId");
    }
  
    if (propertyId != null && propertyId > 0) {
      keys.add("property_info_$propertyId");
    }
  
    for (final key in keys) {
      final cached = await readCachedPropertyInfo(key);
  
      if (cached == null) continue;
  
      final cachedName = getKosNameOnly(cached);
      final cachedAddress = getKosAddressOnly(cached);
  
      if (isValidKosText(cachedName) || isValidKosText(cachedAddress)) {
        debugPrint("CACHE PROPERTY DITEMUKAN DARI KEY: $key");
        debugPrint(cached.toString());
        return cached;
      }
    }
  
    return null;
  }
  
  void applyPropertyInfoToBooking({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> source,
  }) {
    final name = getKosNameOnly(source);
    final address = getKosAddressOnly(source);
  
    if (isValidKosText(name)) {
      booking["_history_property_name"] = name;
      booking["_safe_property_name"] = name;
  
      booking["property_name"] = name;
      booking["place_property_name"] = name;
      booking["nama_kos"] = name;
      booking["nama_kost"] = name;
      booking["kos_name"] = name;
      booking["kost_name"] = name;
      booking["property_title"] = name;
      booking["title"] = name;
    }
  
    if (isValidKosText(address)) {
      booking["_history_property_address"] = address;
      booking["_safe_property_address"] = address;
  
      booking["property_address"] = address;
      booking["place_property_address"] = address;
      booking["address"] = address;
      booking["alamat"] = address;
      booking["location"] = address;
      booking["lokasi"] = address;
    }
  }
  
  Future<void> loadRiwayatSewa() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
          errorMessage = null;
        });
      }

      final token = cleanToken(await ApiService().getToken());

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = "Token tidak ditemukan. Silakan login ulang.";
        });

        return;
      }

      final cacheBuster = DateTime.now().millisecondsSinceEpoch;

      final responses = await Future.wait([
        http.get(
          Uri.parse("${ApiService.baseUrl}/rental-bookings?_=$cacheBuster"),
          headers: authHeaders(token),
        ),
        http.get(
          Uri.parse(
            "${ApiService.baseUrl}/rental-bookings/history?_=$cacheBuster",
          ),
          headers: authHeaders(token),
        ),
      ]);

      final response = responses[0];
      final historyResponse = responses[1];

      debugPrint("RIWAYAT SEWA STATUS: ${response.statusCode}");
      debugPrint("RIWAYAT SEWA BODY: ${response.body}");
      debugPrint("RIWAYAT HISTORY STATUS: ${historyResponse.statusCode}");
      debugPrint("RIWAYAT HISTORY BODY: ${historyResponse.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final bookings = parseDataList(decoded);

        final Map<String, Map<String, dynamic>> historyMap = {};

        if (historyResponse.statusCode == 200) {
          final historyDecoded = jsonDecode(historyResponse.body);
          final historyData = parseDataList(historyDecoded);

          for (final historyItem in historyData) {
            final rentalId = getRentalBookingId(historyItem);

            final bookingId = toInt(
              historyItem["booking_id"] ??
                  historyItem["bookingId"] ??
                  historyItem["survey_booking_id"],
            );

            final propertyId = findFirstIntDeep(historyItem, [
              "place_property_id",
              "place_properties_id",
              "property_id",
              "placePropertyId",
              "propertyId",
            ]);

            final kosName = getKosNameOnly(historyItem);
            final kosAddress = getKosAddressOnly(historyItem);

            final mapped = {"name": kosName, "address": kosAddress};

            if (rentalId > 0) {
              historyMap["rental:$rentalId"] = mapped;
              historyMap["id:$rentalId"] = mapped;
            }

            if (bookingId != null && bookingId > 0) {
              historyMap["booking:$bookingId"] = mapped;
            }

            if (propertyId != null && propertyId > 0) {
              historyMap["property:$propertyId"] = mapped;
            }
          }
        }

        final List<Map<String, dynamic>> result = [];

        for (final item in bookings) {
          final booking = Map<String, dynamic>.from(item);

          final rentalId = getRentalBookingId(booking);

          final bookingId = toInt(
            booking["booking_id"] ??
                booking["bookingId"] ??
                booking["survey_booking_id"],
          );

          final propertyId = findFirstIntDeep(booking, [
            "place_property_id",
            "place_properties_id",
            "property_id",
            "placePropertyId",
            "propertyId",
          ]);

          final historyData =
              historyMap["rental:$rentalId"] ??
              historyMap["id:$rentalId"] ??
              historyMap["booking:$bookingId"] ??
              historyMap["property:$propertyId"];
          
          if (historyData != null) {
            final name = historyData["name"]?.toString().trim() ?? "";
            final address = historyData["address"]?.toString().trim() ?? "";
          
            if (isValidKosText(name)) {
              booking["_history_property_name"] = name;
            }
          
            if (isValidKosText(address)) {
              booking["_history_property_address"] = address;
            }
          }
          
          final cachedPropertyInfo = await getCachedPropertyInfo(
            rentalId: rentalId,
            bookingId: bookingId,
            propertyId: propertyId,
          );
          
          if (cachedPropertyInfo != null) {
            applyPropertyInfoToBooking(
              booking: booking,
              source: cachedPropertyInfo,
            );
          }

          final safeName = getKosNameOnly(booking);
          final safeAddress = getKosAddressOnly(booking);

          if (isValidKosText(safeName)) {
            booking["_safe_property_name"] = safeName;
          }

          if (isValidKosText(safeAddress)) {
            booking["_safe_property_address"] = safeAddress;
          }

          debugPrint("FINAL NAMA KOS RIWAYAT:");
          debugPrint(getPropertyName(booking));

          if (rentalId > 0) {
            final invoices = await fetchInvoicesForBooking(
              rentalBookingId: rentalId,
              token: token,
            );

            if (invoices.isNotEmpty) {
              booking["invoices"] = invoices;
              booking["latest_invoice"] = invoices.first;
            }
          }

          if (hasAnyPaymentProof(booking)) {
            result.add(booking);
          } else {
            debugPrint("SKIP RIWAYAT TANPA BUKTI PEMBAYARAN:");
            debugPrint(
              {
                "rental_booking_id": rentalId,
                "booking_id": bookingId,
                "property_id": propertyId,
                "property_name": getPropertyName(booking),
              }.toString(),
            );
          }
        }

        if (!mounted) return;

        setState(() {
          histories = result;
          loading = false;
        });

        await generateFamilyCodesForPaidHistories(items: result, token: token);

        return;
      }

      if (response.statusCode == 401) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = "Sesi login kamu sudah habis. Silakan login ulang.";
        });

        return;
      }

      final message = parseResponseMessage(
        response.body,
        "Gagal memuat riwayat sewa",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = message;
      });
    } catch (e) {
      debugPrint("ERROR RIWAYAT SEWA:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = "Terjadi kesalahan saat memuat riwayat sewa.";
      });
    }
  }

  bool isHistoryPaidForFamilyCode(Map<String, dynamic> item) {
    final latestInvoice = getLatestInvoice(item);
    final latestPayment = getLatestPayment(item);

    final displayStatus = getDisplayStatusForHistory(
      item: item,
      latestInvoice: latestInvoice,
      latestPayment: latestPayment,
    );

    final latestPaymentStatus = latestPayment?["status"];
    final latestInvoiceStatus = latestInvoice?["status"];

    return isPaidInvoiceStatus(displayStatus) ||
        isPaidInvoiceStatus(item["payment_status"]) ||
        isPaidInvoiceStatus(item["status"]) ||
        isPaidInvoiceStatus(latestInvoiceStatus) ||
        isPaidInvoiceStatus(latestPaymentStatus);
  }

  Future<void> generateFamilyCodesForPaidHistories({
    required List<Map<String, dynamic>> items,
    required String token,
  }) async {
    for (final item in items) {
      if (!isHistoryPaidForFamilyCode(item)) continue;

      await generateFamilyCodeForItem(
        item,
        tokenOverride: token,
        showUserMessage: false,
      );
    }
  }

  Future<void> generateFamilyCodeForItem(
    Map<String, dynamic> item, {
    String? tokenOverride,
    bool showUserMessage = true,
  }) async {
    final rentalBookingId = getRentalBookingId(item);

    if (rentalBookingId <= 0) {
      if (showUserMessage) {
        showMessage("Rental booking ID tidak ditemukan.");
      }
      return;
    }

    if (familyCodesByRentalId.containsKey(rentalBookingId)) return;
    if (generatingFamilyCodeRentalIds.contains(rentalBookingId)) return;

    final token = tokenOverride ?? cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      if (showUserMessage) {
        showMessage("Token tidak ditemukan. Silakan login ulang.");
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      generatingFamilyCodeRentalIds.add(rentalBookingId);
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/family/generate/$rentalBookingId"),
        headers: authHeaders(token),
      );

      debugPrint("GENERATE FAMILY CODE RIWAYAT STATUS: ${response.statusCode}");
      debugPrint("GENERATE FAMILY CODE RIWAYAT BODY: ${response.body}");

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map) {
          final data = asMap(decoded["data"]);

          if (data != null && data["code"] != null) {
            if (!mounted) return;

            setState(() {
              familyCodesByRentalId[rentalBookingId] = data;
            });

            if (showUserMessage) {
              showMessage("Kode family berhasil dibuat.");
            }
          }
        }

        return;
      }

      if (showUserMessage) {
        showMessage(
          parseResponseMessage(response.body, "Gagal membuat kode family."),
        );
      }
    } catch (e) {
      debugPrint("GENERATE FAMILY CODE RIWAYAT ERROR:");
      debugPrint(e.toString());

      if (showUserMessage) {
        showMessage("Terjadi kesalahan saat membuat kode family.");
      }
    } finally {
      if (!mounted) return;

      setState(() {
        generatingFamilyCodeRentalIds.remove(rentalBookingId);
      });
    }
  }

  bool isValidKosText(String? value) {
    final text = value?.trim() ?? "";

    if (text.isEmpty) return false;
    if (text == "null") return false;
    if (text.startsWith("{")) return false;
    if (text.startsWith("[")) return false;

    return true;
  }

  bool isBlockedObjectKey(String key) {
    final lower = key.toLowerCase();

    return lower == "user" ||
        lower == "owner" ||
        lower == "tenant" ||
        lower == "resident" ||
        lower == "customer" ||
        lower == "payments" ||
        lower == "payment" ||
        lower == "rental_payments" ||
        lower == "rentalpayments" ||
        lower == "invoice" ||
        lower == "invoices" ||
        lower == "latest_invoice" ||
        lower == "current_invoice" ||
        lower == "initial_invoice" ||
        lower == "reviews" ||
        lower == "review";
  }

  bool isPropertyObjectKey(String key) {
    final lower = key.toLowerCase();

    return lower == "property" ||
        lower == "place_property" ||
        lower == "placeproperty" ||
        lower == "place_properties" ||
        lower == "placeproperties" ||
        lower == "place_property_data" ||
        lower == "property_data" ||
        lower == "place" ||
        lower == "kos" ||
        lower == "kost";
  }

  String pickTextFromMap(Map source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (isValidKosText(text)) {
        return text;
      }
    }

    return "";
  }

  String getKosNameOnly(dynamic source, {bool propertyContext = false}) {
    if (source == null) return "";

    if (source is Map) {
      final safeTopKeys = [
        "_history_property_name",
        "_safe_property_name",
        "place_property_name",
        "property_name",
        "nama_kos",
        "nama_kost",
        "kos_name",
        "kost_name",
        "place_name",
        "property_title",
        "title",
      ];

      final propertyKeys = [
        "_history_property_name",
        "_safe_property_name",
        "place_property_name",
        "property_name",
        "nama_kos",
        "nama_kost",
        "kos_name",
        "kost_name",
        "place_name",
        "property_title",
        "title",
        "name",
        "nama",
      ];

      final direct = pickTextFromMap(
        source,
        propertyContext ? propertyKeys : safeTopKeys,
      );

      if (isValidKosText(direct)) {
        return direct;
      }

      final rentalBooking = source["rental_booking"] ?? source["rentalBooking"];

      if (rentalBooking is Map) {
        final result = getKosNameOnly(rentalBooking);

        if (isValidKosText(result)) return result;
      }

      for (final entry in source.entries) {
        final key = entry.key.toString();

        if (isBlockedObjectKey(key)) continue;

        final childPropertyContext = isPropertyObjectKey(key);

        final result = getKosNameOnly(
          entry.value,
          propertyContext: childPropertyContext,
        );

        if (isValidKosText(result)) {
          return result;
        }
      }
    }

    if (source is List) {
      for (final item in source) {
        final result = getKosNameOnly(item);

        if (isValidKosText(result)) {
          return result;
        }
      }
    }

    return "";
  }

  String getKosAddressOnly(dynamic source, {bool propertyContext = false}) {
    if (source == null) return "";

    if (source is Map) {
      final addressKeys = [
        "_history_property_address",
        "_safe_property_address",
        "property_address",
        "place_property_address",
        "address",
        "alamat",
        "location",
        "lokasi",
        "full_address",
        "alamat_lengkap",
      ];

      final direct = pickTextFromMap(source, addressKeys);

      if (isValidKosText(direct)) {
        return direct;
      }

      final rentalBooking = source["rental_booking"] ?? source["rentalBooking"];

      if (rentalBooking is Map) {
        final result = getKosAddressOnly(rentalBooking);

        if (isValidKosText(result)) return result;
      }

      for (final entry in source.entries) {
        final key = entry.key.toString();

        if (isBlockedObjectKey(key)) continue;

        final childPropertyContext = isPropertyObjectKey(key);

        final result = getKosAddressOnly(
          entry.value,
          propertyContext: childPropertyContext,
        );

        if (isValidKosText(result)) {
          return result;
        }
      }
    }

    if (source is List) {
      for (final item in source) {
        final result = getKosAddressOnly(item);

        if (isValidKosText(result)) {
          return result;
        }
      }
    }

    return "";
  }

  int? findFirstIntDeep(dynamic source, List<String> keys) {
    if (source == null) return null;

    if (source is Map) {
      for (final key in keys) {
        final value = toInt(source[key]);

        if (value != null && value > 0) {
          return value;
        }
      }

      for (final entry in source.entries) {
        final key = entry.key.toString();

        if (isBlockedObjectKey(key)) continue;

        final result = findFirstIntDeep(entry.value, keys);

        if (result != null && result > 0) {
          return result;
        }
      }
    }

    if (source is List) {
      for (final item in source) {
        final result = findFirstIntDeep(item, keys);

        if (result != null && result > 0) {
          return result;
        }
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesForBooking({
    required int rentalBookingId,
    required String token,
  }) async {
    final urls = [
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/invoices",
      "${ApiService.baseUrl}/rental-booking/$rentalBookingId/invoices",
      "${ApiService.baseUrl}/invoices/rental-booking/$rentalBookingId",
      "${ApiService.baseUrl}/invoices/$rentalBookingId",
    ];

    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: authHeaders(token),
        );

        debugPrint("GET INVOICES URL: $url");
        debugPrint("GET INVOICES STATUS: ${response.statusCode}");
        debugPrint("GET INVOICES BODY: ${response.body}");

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final invoices = parseDataList(decoded);

          final validInvoices = invoices.where((invoice) {
            final id = toInt(invoice["rental_booking_id"]);

            if (id == null || id <= 0) return true;

            return id == rentalBookingId;
          }).toList();

          validInvoices.sort((a, b) {
            final dateA = parseDateTime(
              a["period_start"] ?? a["created_at"] ?? a["updated_at"],
            );
            final dateB = parseDateTime(
              b["period_start"] ?? b["created_at"] ?? b["updated_at"],
            );

            return dateB.compareTo(dateA);
          });

          return validInvoices;
        }

        if (response.statusCode != 404 && response.statusCode != 405) {
          return [];
        }
      } catch (e) {
        debugPrint("FETCH INVOICE ERROR:");
        debugPrint(e.toString());
      }
    }

    return [];
  }

  List<Map<String, dynamic>> parseDataList(dynamic decoded) {
    dynamic rawData;

    if (decoded is Map<String, dynamic>) {
      rawData = decoded["data"];

      if (rawData is Map<String, dynamic> && rawData["data"] != null) {
        rawData = rawData["data"];
      }

      if (rawData == null && decoded["invoices"] != null) {
        rawData = decoded["invoices"];
      }

      if (rawData == null && decoded["rental_bookings"] != null) {
        rawData = decoded["rental_bookings"];
      }

      if (rawData == null && decoded["history"] != null) {
        rawData = decoded["history"];
      }
    } else {
      rawData = decoded;
    }

    if (rawData is List) {
      return rawData
          .where((item) => item is Map)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    if (rawData is Map) {
      return [Map<String, dynamic>.from(rawData)];
    }

    return [];
  }

  String parseResponseMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        String message = decoded["message"]?.toString() ?? fallback;

        final errors = decoded["errors"];

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

  int? toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is double) return value.round();

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return null;

    text = text.replaceAll("Rp", "").trim();

    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text)?.round();
    }

    if (RegExp(r'^\d+,\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text.replaceAll(",", "."))?.round();
    }

    if (RegExp(r',\d{1,2}$').hasMatch(text)) {
      text = text.split(',').first;
    }

    if (RegExp(r'\.\d{1,2}$').hasMatch(text)) {
      text = text.split('.').first;
    }

    final normalNumber = double.tryParse(text);

    if (normalNumber != null) {
      return normalNumber.round();
    }

    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) return null;

    return int.tryParse(cleanText);
  }

  int getRentalBookingId(Map<String, dynamic> item) {
    return toInt(
          item["rental_booking_id"] ??
              item["rentalBookingId"] ??
              item["rental_id"] ??
              item["id"],
        ) ??
        0;
  }

  DateTime parseDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? "");

    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? parseNullableDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return null;

    return DateTime.tryParse(text);
  }

  DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String formatRupiah(dynamic value) {
    final number = toInt(value) ?? 0;

    final result = number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp$result";
  }

  String formatDate(dynamic value) {
    if (value == null) return "-";

    final text = value.toString();

    if (text.isEmpty || text == "null") return "-";

    final date = DateTime.tryParse(text);

    if (date == null) return text;

    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String getDisplayRentalPeriod(Map<String, dynamic> item) {
    final latestInvoice = getLatestInvoice(item);

    final start =
        latestInvoice?["period_start"] ??
        latestInvoice?["periodStart"] ??
        item["period_start"] ??
        item["periodStart"] ??
        item["start_date"];

    final end =
        latestInvoice?["period_end"] ??
        latestInvoice?["periodEnd"] ??
        item["period_end"] ??
        item["periodEnd"] ??
        item["end_date"];

    return "${formatDate(start)} - ${formatDate(end)}";
  }

  String getPropertyName(Map<String, dynamic> item) {
    final historyName = item["_history_property_name"]?.toString().trim() ?? "";
    final safeName = item["_safe_property_name"]?.toString().trim() ?? "";

    if (isValidKosText(historyName)) return historyName;
    if (isValidKosText(safeName)) return safeName;

    final fixedName = getKosNameOnly(item);

    if (isValidKosText(fixedName)) return fixedName;

    return "Nama kos tidak tersedia";
  }

  String getPropertyAddress(Map<String, dynamic> item) {
    final historyAddress =
        item["_history_property_address"]?.toString().trim() ?? "";
    final safeAddress = item["_safe_property_address"]?.toString().trim() ?? "";

    if (isValidKosText(historyAddress)) return historyAddress;
    if (isValidKosText(safeAddress)) return safeAddress;

    final fixedAddress = getKosAddressOnly(item);

    if (isValidKosText(fixedAddress)) return fixedAddress;

    return "Alamat belum tersedia";
  }

  String getStatusText(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    if (status == "pending") return "Menunggu";
    if (status == "pending_payment") return "Menunggu Pembayaran";
    if (status == "approved") return "Disetujui";
    if (status == "active") return "Aktif";
    if (status == "grace") return "Grace";
    if (status == "rejected") return "Ditolak";
    if (status == "cancelled" || status == "canceled") return "Dibatalkan";
    if (status == "completed" || status == "finish") return "Selesai";

    if (status.isEmpty || status == "null") return "Tidak diketahui";

    return status;
  }

  String getPaymentStatusText(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    if (status == "pending") return "Menunggu Konfirmasi";
    if (status == "waiting") return "Menunggu Konfirmasi";
    if (status == "waiting_confirmation") return "Menunggu Konfirmasi";
    if (status == "waiting_verification") return "Menunggu Konfirmasi";
    if (status == "pending_payment") return "Menunggu Pembayaran";
    if (status == "unpaid") return "Belum Dibayar";
    if (status == "partial") return "Sebagian";
    if (status == "paid") return "Lunas";
    if (status == "lunas") return "Lunas";
    if (status == "approved") return "Disetujui";
    if (status == "active") return "Aktif";
    if (status == "grace") return "Grace";
    if (status == "overdue") return "Overdue";
    if (status == "rejected") return "Ditolak";

    if (status.isEmpty || status == "null") return "Belum diketahui";

    return status;
  }

  Color getStatusColor(dynamic value) {
    final status = value?.toString().toLowerCase() ?? "";

    if (status == "approved" ||
        status == "active" ||
        status == "paid" ||
        status == "lunas" ||
        status == "completed" ||
        status == "finish") {
      return Colors.green;
    }

    if (status == "pending" ||
        status == "waiting" ||
        status == "waiting_confirmation" ||
        status == "waiting_verification" ||
        status == "pending_payment" ||
        status == "partial" ||
        status == "grace") {
      return Colors.orange;
    }

    if (status == "rejected" ||
        status == "cancelled" ||
        status == "canceled" ||
        status == "overdue" ||
        status == "unpaid") {
      return Colors.red;
    }

    return primaryColor;
  }

  Map<String, dynamic>? getLatestInvoice(Map<String, dynamic> item) {
    final latestInvoice = item["latest_invoice"];

    if (latestInvoice is Map) {
      return Map<String, dynamic>.from(latestInvoice);
    }

    final invoices = item["invoices"];

    if (invoices is List && invoices.isNotEmpty && invoices.first is Map) {
      return Map<String, dynamic>.from(invoices.first as Map);
    }

    return null;
  }

  List<Map<String, dynamic>> getInvoices(Map<String, dynamic> item) {
    final invoices = item["invoices"];

    if (invoices is List) {
      return invoices
          .where((invoice) => invoice is Map)
          .map((invoice) => Map<String, dynamic>.from(invoice as Map))
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> getPayments(Map<String, dynamic> item) {
    final List<Map<String, dynamic>> payments = [];

    void addPayment(dynamic value, {Map<String, dynamic>? invoice}) {
      if (value is Map) {
        final paymentMap = Map<String, dynamic>.from(value);

        if (invoice != null) {
          paymentMap["invoice"] = invoice;
        }

        payments.add(paymentMap);
      }
    }

    final directPayments = item["payments"];

    if (directPayments is List) {
      for (final payment in directPayments) {
        addPayment(payment);
      }
    }

    final rentalPayments = item["rental_payments"] ?? item["rentalPayments"];

    if (rentalPayments is List) {
      for (final payment in rentalPayments) {
        addPayment(payment);
      }
    }

    for (final invoice in getInvoices(item)) {
      final invoicePayments =
          invoice["payments"] ??
          invoice["rental_payments"] ??
          invoice["rentalPayments"];

      if (invoicePayments is List) {
        for (final payment in invoicePayments) {
          addPayment(payment, invoice: invoice);
        }
      }
    }

    payments.sort((a, b) {
      final dateA = parseDateTime(a["created_at"] ?? a["updated_at"]);
      final dateB = parseDateTime(b["created_at"] ?? b["updated_at"]);

      return dateB.compareTo(dateA);
    });

    return payments;
  }

  String getPaymentProofUrlFromMap(
    Map<String, dynamic> source, {
    bool allowGenericImage = false,
  }) {
    final proofValue =
        source["payment_proof"] ??
        source["paymentProof"] ??
        source["payment_proof_url"] ??
        source["paymentProofUrl"] ??
        source["proof_url"] ??
        source["proofUrl"] ??
        source["proof"] ??
        source["proof_image"] ??
        source["proofImage"] ??
        source["bukti_pembayaran"] ??
        source["buktiPembayaran"] ??
        source["bukti_transfer"] ??
        source["buktiTransfer"];

    final proofUrl = getImageUrlFromValue(proofValue);

    if (proofUrl.isNotEmpty) {
      return proofUrl;
    }

    if (allowGenericImage) {
      return getImageUrlFromValue(
        source["image"] ??
            source["photo"] ??
            source["file"] ??
            source["path"] ??
            source["url"],
      );
    }

    return "";
  }

  bool hasPaymentProof(Map<String, dynamic> payment) {
    return getPaymentProofUrlFromMap(
      payment,
      allowGenericImage: true,
    ).isNotEmpty;
  }

  List<Map<String, dynamic>> getPaymentsWithProof(Map<String, dynamic> item) {
    return getPayments(item).where(hasPaymentProof).toList();
  }

  bool hasAnyPaymentProof(Map<String, dynamic> item) {
    if (getPaymentProofUrlFromMap(item).isNotEmpty) {
      return true;
    }

    final latestInvoice = getLatestInvoice(item);

    if (latestInvoice != null &&
        getPaymentProofUrlFromMap(latestInvoice).isNotEmpty) {
      return true;
    }

    for (final invoice in getInvoices(item)) {
      if (getPaymentProofUrlFromMap(invoice).isNotEmpty) {
        return true;
      }
    }

    return getPaymentsWithProof(item).isNotEmpty;
  }

  Map<String, dynamic>? getLatestPayment(Map<String, dynamic> item) {
    final payments = getPayments(item);

    if (payments.isEmpty) return null;

    return payments.first;
  }

  int getInvoiceId(Map<String, dynamic> invoice) {
    return toInt(
          invoice["id"] ?? invoice["invoice_id"] ?? invoice["invoiceId"],
        ) ??
        0;
  }

  int getInvoicePayableAmount(Map<String, dynamic> invoice) {
    final remainingAmount = toInt(invoice["remaining_amount"]);

    if (remainingAmount != null && remainingAmount > 0) {
      return remainingAmount;
    }

    final totalAmount =
        toInt(
          invoice["total_amount"] ??
              invoice["amount"] ??
              invoice["grand_total"],
        ) ??
        0;

    final paidAmount = toInt(invoice["paid_amount"]) ?? 0;

    final result = totalAmount - paidAmount;

    return result > 0 ? result : 0;
  }

  bool isPendingPaymentStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    return status == "pending" ||
        status == "waiting" ||
        status == "waiting_confirmation" ||
        status == "waiting_verification" ||
        status == "unverified" ||
        status == "menunggu";
  }

  bool isRejectedPaymentStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    return status == "rejected" || status == "declined" || status == "ditolak";
  }

  bool isPaidInvoiceStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    return status == "paid" || status == "lunas";
  }

  DateTime? getInvoiceDueDate(Map<String, dynamic> invoice) {
    return parseNullableDate(
      invoice["due_date"] ??
          invoice["dueDate"] ??
          invoice["payment_due_date"] ??
          invoice["paymentDueDate"] ??
          invoice["deadline"] ??
          invoice["period_end"] ??
          invoice["periodEnd"],
    );
  }

  DateTime? getGraceUntil(Map<String, dynamic> item) {
    final rentalBooking =
        asMap(item["rental_booking"]) ?? asMap(item["rentalBooking"]);

    return parseNullableDate(
      item["grace_until"] ??
          item["graceUntil"] ??
          rentalBooking?["grace_until"] ??
          rentalBooking?["graceUntil"],
    );
  }

  bool isGraceActive(Map<String, dynamic> item) {
    final paymentStatus =
        item["payment_status"]?.toString().toLowerCase().trim() ?? "";

    final graceUntil = getGraceUntil(item);

    if (paymentStatus != "grace") return false;

    if (graceUntil == null) return true;

    return DateTime.now().isBefore(endOfDay(graceUntil));
  }

  bool hasPendingPaymentForInvoice(Map<String, dynamic> invoice) {
    final payments =
        invoice["payments"] ??
        invoice["rental_payments"] ??
        invoice["rentalPayments"];

    if (payments is List) {
      for (final item in payments) {
        if (item is Map) {
          final payment = Map<String, dynamic>.from(item);

          if (isPendingPaymentStatus(payment["status"])) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool isInvoiceOverdue(
    Map<String, dynamic> invoice, {
    Map<String, dynamic>? item,
  }) {
    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";
    final amount = getInvoicePayableAmount(invoice);

    if (isPaidInvoiceStatus(status)) return false;
    if (amount <= 0) return false;

    if (status == "overdue" || status == "terlambat") return true;

    if (item != null && isGraceActive(item)) return false;

    final dueDate = getInvoiceDueDate(invoice);

    if (dueDate == null) return false;

    return DateTime.now().isAfter(endOfDay(dueDate));
  }

  bool isInvoicePayable(
    Map<String, dynamic> invoice, {
    Map<String, dynamic>? item,
  }) {
    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";
    final amount = getInvoicePayableAmount(invoice);

    if (isPaidInvoiceStatus(status)) return false;
    if (amount <= 0) return false;

    if (item != null && isGraceActive(item)) return false;

    final payments =
        invoice["payments"] ??
        invoice["rental_payments"] ??
        invoice["rentalPayments"];

    if (payments is List) {
      for (final paymentItem in payments) {
        if (paymentItem is Map) {
          final payment = Map<String, dynamic>.from(paymentItem);
          final paymentStatus = payment["status"];

          if (isPendingPaymentStatus(paymentStatus)) {
            return false;
          }
        }
      }
    }

    return true;
  }

  Map<String, dynamic>? getPayableInvoice(Map<String, dynamic> item) {
    final itemStatus = item["status"];
    final paymentStatus = item["payment_status"];
    final latestPayment = getLatestPayment(item);

    if (isPendingPaymentStatus(itemStatus) ||
        isPendingPaymentStatus(paymentStatus) ||
        isPendingPaymentStatus(latestPayment?["status"])) {
      return null;
    }

    if (isGraceActive(item)) return null;

    final invoices = getInvoices(item);

    if (invoices.isEmpty) {
      final latestInvoice = getLatestInvoice(item);

      if (latestInvoice == null) return null;

      final latestIsOverdue = isInvoiceOverdue(latestInvoice, item: item);

      if (latestPayment != null &&
          isRejectedPaymentStatus(latestPayment["status"]) &&
          !latestIsOverdue) {
        return null;
      }

      if (isInvoicePayable(latestInvoice, item: item)) {
        return latestInvoice;
      }

      return null;
    }

    invoices.sort((a, b) {
      final dateA = parseDateTime(a["period_start"] ?? a["created_at"]);
      final dateB = parseDateTime(b["period_start"] ?? b["created_at"]);

      return dateA.compareTo(dateB);
    });

    for (final invoice in invoices) {
      final invoiceIsOverdue = isInvoiceOverdue(invoice, item: item);

      if (latestPayment != null &&
          isRejectedPaymentStatus(latestPayment["status"]) &&
          !invoiceIsOverdue) {
        continue;
      }

      if (isInvoicePayable(invoice, item: item)) {
        return invoice;
      }
    }

    return null;
  }

  String getInvoiceEffectiveStatus(
    Map<String, dynamic> invoice, {
    Map<String, dynamic>? item,
  }) {
    if (isInvoiceOverdue(invoice, item: item)) {
      return "overdue";
    }

    return invoice["status"]?.toString() ?? "";
  }

  dynamic getDisplayStatusForHistory({
    required Map<String, dynamic> item,
    required Map<String, dynamic>? latestInvoice,
    required Map<String, dynamic>? latestPayment,
  }) {
    if (latestPayment != null &&
        isPendingPaymentStatus(latestPayment["status"])) {
      return latestPayment["status"];
    }
  
    if (isGraceActive(item)) return "grace";
  
    if (latestInvoice != null && isInvoiceOverdue(latestInvoice, item: item)) {
      return "overdue";
    }
  
    if (latestPayment != null &&
        isRejectedPaymentStatus(latestPayment["status"])) {
      return latestPayment["status"];
    }
  
    return latestInvoice?["status"] ?? item["payment_status"] ?? item["status"];
  }

  String cleanAmountForBackend(dynamic value) {
    final raw = value?.toString() ?? "";

    return raw
        .replaceAll("Rp", "")
        .replaceAll(".", "")
        .replaceAll(",", "")
        .replaceAll(RegExp(r"[^0-9]"), "")
        .trim();
  }

  Future<bool> uploadInvoicePayment({
    required Map<String, dynamic> invoice,
    required String claimedAmount,
    required String senderName,
    required String notes,
    required File proofFile,
  }) async {
    final token = cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      showMessage("Token tidak ditemukan. Silakan login ulang.");
      return false;
    }

    final invoiceId = getInvoiceId(invoice);

    if (invoiceId <= 0) {
      showMessage("Invoice ID tidak ditemukan.");
      return false;
    }

    final cleanedAmount = cleanAmountForBackend(claimedAmount);

    if (cleanedAmount.isEmpty || (int.tryParse(cleanedAmount) ?? 0) <= 0) {
      showMessage("Nominal pembayaran tidak valid.");
      return false;
    }

    if (!mounted) return false;

    setState(() {
      uploadingInvoicePayment = true;
    });

    final urls = [
      "${ApiService.baseUrl}/invoice-payments",
      "${ApiService.baseUrl}/invoices/payments",
      "${ApiService.baseUrl}/invoices/payment",
      "${ApiService.baseUrl}/invoices/create-payment",
      "${ApiService.baseUrl}/invoices/pay",
    ];

    http.Response? lastResponse;

    try {
      for (final url in urls) {
        final request = http.MultipartRequest("POST", Uri.parse(url));

        request.headers.addAll(authHeaders(token));

        request.fields.addAll({
          "invoice_id": invoiceId.toString(),
          "claimed_amount": cleanedAmount,
          "payment_method": "transfer",
          "sender_name": senderName.trim(),
          "notes": notes.trim(),
        });

        request.files.add(
          await http.MultipartFile.fromPath("payment_proof", proofFile.path),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        lastResponse = response;

        debugPrint("UPLOAD INVOICE PAYMENT URL: $url");
        debugPrint("UPLOAD INVOICE PAYMENT STATUS: ${response.statusCode}");
        debugPrint("UPLOAD INVOICE PAYMENT BODY: ${response.body}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          showMessage("Bukti pembayaran invoice berhasil dikirim.");
          await loadRiwayatSewa();
          return true;
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        showMessage(
          parseResponseMessage(
            response.body,
            "Gagal mengupload bukti pembayaran invoice.",
          ),
        );

        return false;
      }

      showMessage(
        parseResponseMessage(
          lastResponse?.body ?? "",
          "Route upload invoice payment belum cocok.",
        ),
      );

      return false;
    } catch (e) {
      debugPrint("UPLOAD INVOICE PAYMENT ERROR:");
      debugPrint(e.toString());

      showMessage("Terjadi kesalahan saat upload pembayaran invoice.");
      return false;
    } finally {
      if (!mounted) return false;

      setState(() {
        uploadingInvoicePayment = false;
      });
    }
  }

  String getImageUrlFromValue(dynamic value) {
    if (value == null) return "";

    final baseUrlWithoutApi = ApiService.baseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty || text == "null") return "";

      if (text.startsWith("http")) return text;

      if (text.startsWith("/storage")) {
        return "$baseUrlWithoutApi$text";
      }

      if (text.startsWith("storage")) {
        return "$baseUrlWithoutApi/$text";
      }

      return "$baseUrlWithoutApi/storage/$text";
    }

    if (value is Map) {
      final possibleImage =
          value["full_image_url"] ??
          value["image_url"] ??
          value["url"] ??
          value["image"] ??
          value["path"] ??
          value["image_path"] ??
          value["file"] ??
          value["photo"] ??
          value["thumbnail"] ??
          value["main_image"] ??
          value["payment_proof"];

      return getImageUrlFromValue(possibleImage);
    }

    return "";
  }

  String getPaymentProofUrl(Map<String, dynamic> payment) {
    return getPaymentProofUrlFromMap(payment, allowGenericImage: true);
  }

  Future<void> showProofImage(Map<String, dynamic> payment) async {
    final proofUrl = getPaymentProofUrl(payment);

    if (proofUrl.isEmpty) {
      showMessage("Bukti pembayaran tidak tersedia");
      return;
    }

    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: Colors.white,
              child: InteractiveViewer(
                child: Image.network(
                  proofUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Gagal memuat bukti pembayaran",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: darkText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> showInvoicePaymentSheet({
    required Map<String, dynamic> item,
    required Map<String, dynamic> invoice,
  }) async {
    final amountController = TextEditingController(
      text: getInvoicePayableAmount(invoice).toString(),
    );

    final senderNameController = TextEditingController();
    final notesController = TextEditingController();

    File? selectedProof;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickProof() async {
              final result = await imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70,
                maxWidth: 1280,
                maxHeight: 1280,
              );

              if (result == null) return;

              setSheetState(() {
                selectedProof = File(result.path);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const Text(
                        "Bayar Invoice",
                        style: TextStyle(
                          color: darkText,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        getPropertyName(item),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      buildDetailInfo(
                        icon: Icons.receipt_long_rounded,
                        title: "Invoice",
                        value:
                            "${formatDate(invoice["period_start"])} - ${formatDate(invoice["period_end"])}",
                      ),
                      buildDetailInfo(
                        icon: Icons.payments_rounded,
                        title: "Sisa Tagihan",
                        value: formatRupiah(getInvoicePayableAmount(invoice)),
                      ),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Nominal Pembayaran",
                          prefixText: "Rp ",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: senderNameController,
                        decoration: InputDecoration(
                          labelText: "Nama Pengirim",
                          hintText: "Contoh: Rahes",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "Catatan",
                          hintText: "Contoh: Pembayaran invoice bulan ini",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: pickProof,
                        child: Container(
                          width: double.infinity,
                          height: selectedProof == null ? 130 : 210,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selectedProof == null
                                  ? Colors.black12
                                  : primaryColor.withOpacity(0.35),
                            ),
                          ),
                          child: selectedProof == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.upload_file_rounded,
                                      color: primaryColor,
                                      size: 38,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Pilih Bukti Pembayaran",
                                      style: TextStyle(
                                        color: darkText,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Tap untuk ambil dari galeri",
                                      style: TextStyle(
                                        color: Colors.black45,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.file(
                                    selectedProof!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: uploadingInvoicePayment
                              ? null
                              : () async {
                                  if (selectedProof == null) {
                                    showMessage("Pilih bukti pembayaran dulu.");
                                    return;
                                  }

                                  Navigator.pop(context);

                                  await uploadInvoicePayment(
                                    invoice: invoice,
                                    claimedAmount: amountController.text,
                                    senderName: senderNameController.text,
                                    notes: notesController.text,
                                    proofFile: selectedProof!,
                                  );
                                },
                          icon: uploadingInvoicePayment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            uploadingInvoicePayment
                                ? "Mengirim..."
                                : "Kirim Pembayaran",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
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

    amountController.dispose();
    senderNameController.dispose();
    notesController.dispose();
  }

  Future<void> showDetailSheet(Map<String, dynamic> item) async {
    final latestInvoice = getLatestInvoice(item);
    final latestPayment = getLatestPayment(item);
    final payableInvoice = getPayableInvoice(item);
    final payments = getPaymentsWithProof(item);

    final invoiceStatusText = latestInvoice == null
        ? "-"
        : getPaymentStatusText(
            getInvoiceEffectiveStatus(latestInvoice, item: item),
          );

    final paymentStatusText = getPaymentStatusText(
      getDisplayStatusForHistory(
        item: item,
        latestInvoice: latestInvoice,
        latestPayment: latestPayment,
      ),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F8FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 54,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      getPropertyName(item),
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      getPropertyAddress(item),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildDetailInfo(
                      icon: Icons.calendar_month_rounded,
                      title: "Tanggal Sewa",
                      value: getDisplayRentalPeriod(item),
                    ),
                    buildDetailInfo(
                      icon: Icons.payments_rounded,
                      title: "Total Harga",
                      value: formatRupiah(item["total_price"]),
                    ),
                    buildDetailInfo(
                      icon: Icons.verified_rounded,
                      title: "Status Booking",
                      value: getStatusText(item["status"]),
                    ),
                    buildDetailInfo(
                      icon: Icons.account_balance_wallet_rounded,
                      title: "Status Pembayaran",
                      value: paymentStatusText,
                    ),
                    buildFamilyCodeBox(item),
                    if (latestInvoice != null) ...[
                      const SizedBox(height: 12),
                      buildDetailInfo(
                        icon: Icons.receipt_long_rounded,
                        title: "Invoice Terakhir",
                        value:
                            "${formatRupiah(latestInvoice["remaining_amount"] ?? latestInvoice["total_amount"])} • $invoiceStatusText",
                      ),
                      buildDetailInfo(
                        icon: Icons.event_available_rounded,
                        title: "Periode Invoice",
                        value:
                            "${formatDate(latestInvoice["period_start"])} - ${formatDate(latestInvoice["period_end"])}",
                      ),
                    ],
                    if (payableInvoice != null)
                      buildInvoicePaymentButton(
                        item: item,
                        invoice: payableInvoice,
                      )
                    else if (latestInvoice != null &&
                        hasPendingPaymentForInvoice(latestInvoice))
                      buildPendingInvoicePaymentBox(),
                    const SizedBox(height: 10),
                    const Text(
                      "Riwayat Pembayaran",
                      style: TextStyle(
                        color: darkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (payments.isEmpty)
                      buildNoPaymentBox()
                    else
                      ...payments.map(buildPaymentHistoryItem).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildFamilyCodeBox(Map<String, dynamic> item) {
    final rentalBookingId = getRentalBookingId(item);

    if (rentalBookingId <= 0) {
      return const SizedBox.shrink();
    }

    final isPaid = isHistoryPaidForFamilyCode(item);

    if (!isPaid) {
      return const SizedBox.shrink();
    }

    final isGenerating = generatingFamilyCodeRentalIds.contains(
      rentalBookingId,
    );

    final familyCodeData = familyCodesByRentalId[rentalBookingId];

    if (isGenerating && familyCodeData == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Sedang membuat kode family...",
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (familyCodeData == null) {
      return GestureDetector(
        onTap: () {
          generateFamilyCodeForItem(item, showUserMessage: true);
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Status sudah lunas. Tap untuk buat kode family.",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.refresh_rounded, color: Colors.orange, size: 18),
            ],
          ),
        ),
      );
    }

    final code = familyCodeData["code"]?.toString() ?? "-";
    final expiredAt = familyCodeData["expired_at"];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: Colors.green,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Kode Family",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                if (expiredAt != null)
                  Text(
                    "Expired: ${formatDate(expiredAt)}",
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));

              showMessage("Kode family berhasil disalin.");
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget buildInvoicePaymentButton({
    required Map<String, dynamic> item,
    required Map<String, dynamic> invoice,
  }) {
    final latestPayment = getLatestPayment(item);
    final isOverdue = isInvoiceOverdue(invoice, item: item);
    final isRejected =
        latestPayment != null &&
        isRejectedPaymentStatus(latestPayment["status"]);

    final title = isOverdue
        ? "Invoice Overdue"
        : isRejected
        ? "Bukti Ditolak"
        : "Invoice yang harus dibayar";

    final buttonText = isOverdue || isRejected
        ? "Kirim Bukti Pembayaran Baru"
        : "Bayar Invoice Ini";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.25) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isOverdue ? Colors.red : darkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${formatDate(invoice["period_start"])} - ${formatDate(invoice["period_end"])}",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isOverdue ? Colors.red.withOpacity(0.08) : softBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              formatRupiah(getInvoicePayableAmount(invoice)),
              style: TextStyle(
                color: isOverdue ? Colors.red : primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: uploadingInvoicePayment
                  ? null
                  : () {
                      showInvoicePaymentSheet(item: item, invoice: invoice);
                    },
              icon: const Icon(Icons.payment_rounded),
              label: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOverdue ? Colors.red : primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPendingInvoicePaymentBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Pembayaran invoice sedang menunggu konfirmasi owner.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNoPaymentBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Belum ada bukti pembayaran yang dikirim.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPaymentHistoryItem(Map<String, dynamic> payment) {
    final status = payment["status"];
    final statusColor = getStatusColor(status);
    final invoice = payment["invoice"];

    return GestureDetector(
      onTap: () => showProofImage(payment),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.upload_file_rounded, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bukti pembayaran dikirim",
                    style: TextStyle(
                      color: darkText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${formatRupiah(payment["claimed_amount"] ?? payment["amount"])} • ${formatDate(payment["created_at"])}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (payment["sender_name"] != null &&
                      payment["sender_name"].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Pengirim: ${payment["sender_name"]}",
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (payment["notes"] != null &&
                      payment["notes"].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Catatan: ${payment["notes"]}",
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (invoice is Map) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Invoice: ${formatDate(invoice["period_start"])} - ${formatDate(invoice["period_end"])}",
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          getPaymentStatusText(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Tap lihat bukti",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDetailInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: softBlue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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

  Widget buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) {
        return Container(
          height: 150,
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget buildEmpty() {
    return RefreshIndicator(
      onRefresh: loadRiwayatSewa,
      color: primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.08),
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
                    color: softBlue,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: primaryColor,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Belum ada riwayat sewa",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Setelah kamu melakukan pemesanan kos, riwayat sewanya akan muncul di halaman ini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildError() {
    return RefreshIndicator(
      onRefresh: loadRiwayatSewa,
      color: primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.08),
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
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Gagal memuat data",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage ?? "Terjadi kesalahan.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: loadRiwayatSewa,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Coba Lagi",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHistoryCard(Map<String, dynamic> item, int index) {
    final latestInvoice = getLatestInvoice(item);
    final latestPayment = getLatestPayment(item);
    final payableInvoice = getPayableInvoice(item);

    final displayStatus = getDisplayStatusForHistory(
      item: item,
      latestInvoice: latestInvoice,
      latestPayment: latestPayment,
    );

    final statusColor = getStatusColor(displayStatus);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 80)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => showDetailSheet(item),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: softBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      getPropertyName(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      getPaymentStatusText(displayStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      getDisplayRentalPeriod(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      getPropertyAddress(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatRupiah(item["total_price"]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: primaryColor,
                      size: 14,
                    ),
                  ],
                ),
              ),
              buildFamilyCodeBox(item),
              if (payableInvoice != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isInvoiceOverdue(payableInvoice, item: item)
                          ? Icons.warning_amber_rounded
                          : Icons.payment_rounded,
                      size: 15,
                      color: isInvoiceOverdue(payableInvoice, item: item)
                          ? Colors.red
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isInvoiceOverdue(payableInvoice, item: item)
                            ? "Invoice overdue • Kirim bukti pembayaran baru"
                            : "Ada invoice yang perlu dibayar • Tap detail",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isInvoiceOverdue(payableInvoice, item: item)
                              ? Colors.red
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (latestPayment != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      size: 15,
                      color: getStatusColor(latestPayment["status"]),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Bukti terkirim • ${getPaymentStatusText(latestPayment["status"])}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: getStatusColor(latestPayment["status"]),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (latestInvoice != null) ...[
                const SizedBox(height: 10),
                Text(
                  "Invoice: ${getPaymentStatusText(getInvoiceEffectiveStatus(latestInvoice, item: item))}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isInvoiceOverdue(latestInvoice, item: item)
                        ? Colors.red
                        : Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildContent() {
    if (loading) return buildLoading();

    if (errorMessage != null) return buildError();

    if (histories.isEmpty) return buildEmpty();

    return RefreshIndicator(
      onRefresh: loadRiwayatSewa,
      color: primaryColor,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: histories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return buildHistoryCard(histories[index], index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        goToHomePage();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FF),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.20),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: goToHomePage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Riwayat Sewa",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Lihat riwayat sewa dan pembayaran kamu",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: loadRiwayatSewa,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: buildContent()),
            ],
          ),
        ),
      ),
    );
  }
}