import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:koskaki/screens/Resident/HomePage.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryColor = Color(0xFF2D2F8F);
const Color secondaryColor = Color(0xFF5B5FEF);
const Color softBlue = Color(0xFFEFF2FF);
const Color darkText = Color(0xFF161A33);

class Tunggakan extends StatefulWidget {
  const Tunggakan({super.key});

  @override
  State<Tunggakan> createState() => _TunggakanState();
}

class _TunggakanState extends State<Tunggakan> {
  bool loading = true;
  bool uploading = false;

  String? errorMessage;

  final ImagePicker imagePicker = ImagePicker();

  List<Map<String, dynamic>> arrears = [];

  @override
  void initState() {
    super.initState();
    loadTunggakan();
  }

  void goToHomePage() {
    if (!mounted) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
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

  bool isValidKosText(dynamic value) {
    final text = value?.toString().trim() ?? "";

    if (text.isEmpty) return false;
    if (text == "null") return false;
    if (text.startsWith("{")) return false;
    if (text.startsWith("[")) return false;

    return true;
  }

  String pickTextFromMap(Map source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];

      if (isValidKosText(value)) {
        return value.toString().trim();
      }
    }

    return "";
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
      debugPrint("READ TUNGGAKAN CACHE ERROR:");
      debugPrint(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCachedPropertyInfo({
    required int rentalBookingId,
    required int propertyId,
  }) async {
    final keys = <String>[];

    if (rentalBookingId > 0) {
      keys.add("rental_property_info_$rentalBookingId");
    }

    if (propertyId > 0) {
      keys.add("property_info_$propertyId");
    }

    for (final key in keys) {
      final cached = await readCachedPropertyInfo(key);

      if (cached == null) continue;

      final cachedName = pickTextFromMap(cached, [
        "property_name",
        "place_property_name",
        "nama_kos",
        "nama_kost",
        "kos_name",
        "kost_name",
        "property_title",
        "title",
        "name",
        "nama",
      ]);

      final cachedAddress = pickTextFromMap(cached, [
        "property_address",
        "place_property_address",
        "address",
        "alamat",
        "location",
        "lokasi",
        "full_address",
        "alamat_lengkap",
      ]);

      if (isValidKosText(cachedName) || isValidKosText(cachedAddress)) {
        debugPrint("CACHE TUNGGAKAN PROPERTY DITEMUKAN:");
        debugPrint(key);
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
    final name = pickTextFromMap(source, [
      "property_name",
      "place_property_name",
      "nama_kos",
      "nama_kost",
      "kos_name",
      "kost_name",
      "property_title",
      "title",
      "name",
      "nama",
    ]);

    final address = pickTextFromMap(source, [
      "property_address",
      "place_property_address",
      "address",
      "alamat",
      "location",
      "lokasi",
      "full_address",
      "alamat_lengkap",
    ]);

    if (isValidKosText(name)) {
      booking["property_name"] = name;
      booking["place_property_name"] = name;
      booking["nama_kos"] = name;
      booking["nama_kost"] = name;
      booking["kos_name"] = name;
      booking["kost_name"] = name;
      booking["property_title"] = name;
      booking["title"] = name;
      booking["name"] = name;
    }

    if (isValidKosText(address)) {
      booking["property_address"] = address;
      booking["place_property_address"] = address;
      booking["address"] = address;
      booking["alamat"] = address;
      booking["location"] = address;
      booking["lokasi"] = address;
      booking["full_address"] = address;
      booking["alamat_lengkap"] = address;
    }
  }

  Future<void> loadTunggakan() async {
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

      final bookingResponse = await http.get(
        Uri.parse("${ApiService.baseUrl}/rental-bookings?_=$cacheBuster"),
        headers: authHeaders(token),
      );

      debugPrint("TUNGGAKAN BOOKING STATUS:");
      debugPrint(bookingResponse.statusCode.toString());
      debugPrint("TUNGGAKAN BOOKING BODY:");
      debugPrint(bookingResponse.body);

      if (bookingResponse.statusCode == 401) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = "Sesi login kamu sudah habis. Silakan login ulang.";
        });

        return;
      }

      if (bookingResponse.statusCode != 200) {
        final message = parseResponseMessage(
          bookingResponse.body,
          "Gagal memuat data tunggakan.",
        );

        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = message;
        });

        return;
      }

      final decoded = jsonDecode(bookingResponse.body);
      final bookings = parseDataList(decoded);

      final List<Map<String, dynamic>> result = [];

      for (final rawBooking in bookings) {
        final booking = Map<String, dynamic>.from(rawBooking);
        final rentalBookingId = getRentalBookingId(booking);

        if (rentalBookingId <= 0) continue;

        final propertyId = getPropertyIdFromBooking(booking);

        final cachedPropertyInfo = await getCachedPropertyInfo(
          rentalBookingId: rentalBookingId,
          propertyId: propertyId,
        );

        if (cachedPropertyInfo != null) {
          applyPropertyInfoToBooking(
            booking: booking,
            source: cachedPropertyInfo,
          );
        }

        debugPrint("TUNGGAKAN NAMA KOS FINAL:");
        debugPrint(getPropertyName(booking));

        debugPrint("TUNGGAKAN ALAMAT FINAL:");
        debugPrint(getPropertyAddress(booking));

        final invoices = await fetchInvoicesForBooking(
          rentalBookingId: rentalBookingId,
          token: token,
        );

        for (final rawInvoice in invoices) {
          final invoice = Map<String, dynamic>.from(rawInvoice);

          final amount = getInvoicePayableAmount(invoice);
          final hasPending = hasPendingPaymentForInvoice(invoice);

          final isGrace = isGraceActive(booking);
          final isOverdue = isInvoiceOverdue(invoice);

          final shouldShow = amount > 0 && (isGrace || isOverdue);

          if (!shouldShow) {
            debugPrint("SKIP INVOICE BUKAN OVERDUE / GRACE:");
            debugPrint(
              {
                "booking_id": rentalBookingId,
                "invoice_id": invoice["id"],
                "booking_status": booking["status"],
                "payment_status": booking["payment_status"],
                "invoice_status": invoice["status"],
                "remaining_amount": invoice["remaining_amount"],
                "payable_amount": amount,
                "is_grace": isGrace,
                "is_overdue": isOverdue,
              }.toString(),
            );

            continue;
          }

          result.add({
            "booking": booking,
            "invoice": invoice,
            "has_pending_payment": hasPending,
            "display_status": isGrace ? "grace" : "overdue",
          });
        }
      }

      result.sort((a, b) {
        final invoiceA = Map<String, dynamic>.from(a["invoice"] as Map);
        final invoiceB = Map<String, dynamic>.from(b["invoice"] as Map);

        final dateA = parseDateTime(
          invoiceA["due_date"] ??
              invoiceA["dueDate"] ??
              invoiceA["period_end"] ??
              invoiceA["periodEnd"],
        );

        final dateB = parseDateTime(
          invoiceB["due_date"] ??
              invoiceB["dueDate"] ??
              invoiceB["period_end"] ??
              invoiceB["periodEnd"],
        );

        return dateA.compareTo(dateB);
      });

      if (!mounted) return;

      setState(() {
        arrears = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("ERROR LOAD TUNGGAKAN:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = "Terjadi kesalahan saat memuat tunggakan.";
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesForBooking({
    required int rentalBookingId,
    required String token,
  }) async {
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final urls = [
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/invoices?_=$cacheBuster",
      "${ApiService.baseUrl}/rental-booking/$rentalBookingId/invoices?_=$cacheBuster",
      "${ApiService.baseUrl}/invoices/rental-booking/$rentalBookingId?_=$cacheBuster",
      "${ApiService.baseUrl}/invoices/$rentalBookingId?_=$cacheBuster",
    ];

    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: authHeaders(token),
        );

        debugPrint("GET TUNGGAKAN INVOICES URL:");
        debugPrint(url);
        debugPrint("GET TUNGGAKAN INVOICES STATUS:");
        debugPrint(response.statusCode.toString());
        debugPrint("GET TUNGGAKAN INVOICES BODY:");
        debugPrint(response.body);

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
        debugPrint("FETCH TUNGGAKAN INVOICE ERROR:");
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

  int getInvoiceId(Map<String, dynamic> invoice) {
    return toInt(
          invoice["id"] ?? invoice["invoice_id"] ?? invoice["invoiceId"],
        ) ??
        0;
  }

  int getInvoicePayableAmount(Map<String, dynamic> invoice) {
    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";

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

    final calculated = totalAmount - paidAmount;

    if (calculated > 0) {
      return calculated;
    }

    if ((status == "unpaid" ||
            status == "belum_bayar" ||
            status == "overdue" ||
            status == "terlambat") &&
        totalAmount > 0 &&
        paidAmount <= 0) {
      return totalAmount;
    }

    return 0;
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

  String formatRupiah(dynamic value) {
    final number = toInt(value) ?? 0;

    final result = number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp $result";
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

  Map<String, dynamic> getProperty(Map<String, dynamic> item) {
    final property =
        item["property"] ??
        item["place_property"] ??
        item["placeProperty"] ??
        item["place_properties"] ??
        item["placeProperties"] ??
        item["place_property_data"] ??
        item["property_data"] ??
        item["place"] ??
        item["kos"] ??
        item["kost"];

    if (property is Map) {
      return Map<String, dynamic>.from(property);
    }

    final rentalBooking = item["rental_booking"] ?? item["rentalBooking"];

    if (rentalBooking is Map) {
      final nestedProperty =
          rentalBooking["property"] ??
          rentalBooking["place_property"] ??
          rentalBooking["placeProperty"] ??
          rentalBooking["place_properties"] ??
          rentalBooking["placeProperties"] ??
          rentalBooking["place_property_data"] ??
          rentalBooking["property_data"] ??
          rentalBooking["kos"] ??
          rentalBooking["kost"];

      if (nestedProperty is Map) {
        return Map<String, dynamic>.from(nestedProperty);
      }
    }

    return {};
  }

  int getPropertyIdFromBooking(Map<String, dynamic> item) {
    final property = getProperty(item);

    return toInt(
          item["place_properties_id"] ??
              item["place_property_id"] ??
              item["property_id"] ??
              item["placePropertyId"] ??
              item["propertyId"] ??
              property["id"] ??
              property["place_properties_id"] ??
              property["place_property_id"] ??
              property["property_id"],
        ) ??
        0;
  }

  String getPropertyName(Map<String, dynamic> item) {
    final property = getProperty(item);

    final name =
        property["title"] ??
        property["property_name"] ??
        property["place_property_name"] ??
        property["nama_kos"] ??
        property["nama_kost"] ??
        property["kos_name"] ??
        property["kost_name"] ??
        property["place_name"] ??
        property["property_title"] ??
        property["name"] ??
        property["nama"] ??
        item["place_property_name"] ??
        item["property_name"] ??
        item["nama_kos"] ??
        item["nama_kost"] ??
        item["kos_name"] ??
        item["kost_name"] ??
        item["place_name"] ??
        item["property_title"] ??
        item["title"] ??
        item["name"] ??
        item["nama"];

    final text = name?.toString().trim() ?? "";

    if (!isValidKosText(text)) {
      return "Nama kos tidak tersedia";
    }

    return text;
  }

  String getPropertyAddress(Map<String, dynamic> item) {
    final property = getProperty(item);

    final address =
        property["property_address"] ??
        property["place_property_address"] ??
        property["address"] ??
        property["alamat"] ??
        property["location"] ??
        property["lokasi"] ??
        property["full_address"] ??
        property["alamat_lengkap"] ??
        item["property_address"] ??
        item["place_property_address"] ??
        item["address"] ??
        item["alamat"] ??
        item["location"] ??
        item["lokasi"] ??
        item["full_address"] ??
        item["alamat_lengkap"];

    final text = address?.toString().trim() ?? "";

    if (!isValidKosText(text)) {
      return "Alamat belum tersedia";
    }

    return text;
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

  bool isGraceActive(Map<String, dynamic> booking) {
    final status = booking["status"]?.toString().toLowerCase().trim() ?? "";

    final paymentStatus =
        booking["payment_status"]?.toString().toLowerCase().trim() ?? "";

    final rentalBooking = booking["rental_booking"] ?? booking["rentalBooking"];

    String nestedStatus = "";
    String nestedPaymentStatus = "";

    if (rentalBooking is Map) {
      nestedStatus =
          rentalBooking["status"]?.toString().toLowerCase().trim() ?? "";

      nestedPaymentStatus =
          rentalBooking["payment_status"]?.toString().toLowerCase().trim() ??
          "";
    }

    final isGrace =
        status == "grace" ||
        paymentStatus == "grace" ||
        nestedStatus == "grace" ||
        nestedPaymentStatus == "grace";

    if (!isGrace) return false;

    final graceUntil = parseNullableDate(
      booking["grace_until"] ??
          booking["graceUntil"] ??
          (rentalBooking is Map ? rentalBooking["grace_until"] : null) ??
          (rentalBooking is Map ? rentalBooking["graceUntil"] : null),
    );

    if (graceUntil == null) return true;

    return DateTime.now().isBefore(endOfDay(graceUntil));
  }

  bool isInvoiceOverdue(Map<String, dynamic> invoice) {
    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";
    final amount = getInvoicePayableAmount(invoice);

    if (amount <= 0) return false;

    if (status == "overdue" || status == "terlambat") {
      return true;
    }

    if (status != "unpaid" && status != "belum_bayar") {
      return false;
    }

    final dueDate = parseNullableDate(
      invoice["due_date"] ??
          invoice["dueDate"] ??
          invoice["payment_due_date"] ??
          invoice["paymentDueDate"] ??
          invoice["deadline"],
    );

    if (dueDate == null) return false;

    return DateTime.now().isAfter(endOfDay(dueDate));
  }

  bool isUnpaidOrOverdueInvoice(
    Map<String, dynamic> invoice, {
    required Map<String, dynamic> booking,
  }) {
    final amount = getInvoicePayableAmount(invoice);

    if (amount <= 0) return false;

    return isGraceActive(booking) || isInvoiceOverdue(invoice);
  }

  String getInvoiceStatusText({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> booking,
  }) {
    if (isGraceActive(booking)) {
      return "Grace";
    }

    if (isInvoiceOverdue(invoice)) {
      return "Overdue";
    }

    return "Tunggakan";
  }

  Color getInvoiceStatusColor({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> booking,
  }) {
    if (isGraceActive(booking)) {
      return Colors.orange;
    }

    if (isInvoiceOverdue(invoice)) {
      return Colors.red;
    }

    return primaryColor;
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
    required Map<String, dynamic> booking,
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

    final propertyName = getPropertyName(booking);
    final propertyAddress = getPropertyAddress(booking);
    final propertyId = getPropertyIdFromBooking(booking);
    final rentalBookingId = getRentalBookingId(booking);

    if (mounted) {
      setState(() {
        uploading = true;
      });
    }

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

          "rental_booking_id": rentalBookingId.toString(),

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
        });

        if (propertyId > 0) {
          request.fields["property_id"] = propertyId.toString();
          request.fields["place_property_id"] = propertyId.toString();
          request.fields["place_properties_id"] = propertyId.toString();
        }

        request.files.add(
          await http.MultipartFile.fromPath("payment_proof", proofFile.path),
        );

        debugPrint("UPLOAD TUNGGAKAN URL:");
        debugPrint(url);

        debugPrint("UPLOAD TUNGGAKAN FIELDS:");
        debugPrint(request.fields.toString());

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        lastResponse = response;

        debugPrint("UPLOAD TUNGGAKAN STATUS:");
        debugPrint(response.statusCode.toString());

        debugPrint("UPLOAD TUNGGAKAN BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          showMessage("Bukti pembayaran tunggakan berhasil dikirim.");
          await loadTunggakan();
          return true;
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        showMessage(
          parseResponseMessage(
            response.body,
            "Gagal mengupload bukti pembayaran tunggakan.",
          ),
        );

        return false;
      }

      showMessage(
        parseResponseMessage(
          lastResponse?.body ?? "",
          "Route upload invoice payment belum cocok. Cek route api.php.",
        ),
      );

      return false;
    } catch (e) {
      debugPrint("UPLOAD TUNGGAKAN ERROR:");
      debugPrint(e.toString());

      showMessage("Terjadi kesalahan saat upload bukti pembayaran.");
      return false;
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  Future<void> showPaymentSheet({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> invoice,
  }) async {
    final amountController = TextEditingController(
      text: getInvoicePayableAmount(invoice).toString(),
    );

    final senderNameController = TextEditingController();
    final notesController = TextEditingController();

    File? selectedProof;
    String? sheetError;

    try {
      final payload = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (modalContext, setSheetState) {
              Future<void> pickProof() async {
                final result = await imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                  maxWidth: 1280,
                  maxHeight: 1280,
                );

                if (result == null) return;
                if (!modalContext.mounted) return;

                setSheetState(() {
                  selectedProof = File(result.path);
                  sheetError = null;
                });
              }

              void submitPayment() {
                final proof = selectedProof;

                if (proof == null) {
                  setSheetState(() {
                    sheetError = "Pilih bukti pembayaran dulu.";
                  });
                  return;
                }

                final result = <String, dynamic>{
                  "amount": amountController.text,
                  "sender": senderNameController.text,
                  "notes": notesController.text,
                  "proof": proof,
                };

                Navigator.of(modalContext).pop(result);
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
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
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),

                        const Text(
                          "Kirim Bukti Pembayaran",
                          style: TextStyle(
                            color: darkText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          getPropertyName(booking),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          getPropertyAddress(booking),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 18),

                        buildDetailInfo(
                          icon: Icons.receipt_long_rounded,
                          title: "Periode Invoice",
                          value:
                              "${formatDate(invoice["period_start"])} - ${formatDate(invoice["period_end"])}",
                        ),

                        buildDetailInfo(
                          icon: Icons.event_busy_rounded,
                          title: "Jatuh Tempo",
                          value: formatDate(invoice["due_date"]),
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
                            hintText: "Contoh: Pembayaran tunggakan",
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

                        if (sheetError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            sheetError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: uploading ? null : submitPayment,
                            icon: uploading
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
                              uploading ? "Mengirim..." : "Kirim Bukti",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
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

      if (payload == null) return;
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      await uploadInvoicePayment(
        booking: booking,
        invoice: invoice,
        claimedAmount: payload["amount"].toString(),
        senderName: payload["sender"].toString(),
        notes: payload["notes"].toString(),
        proofFile: payload["proof"] as File,
      );
    } finally {
      amountController.dispose();
      senderNameController.dispose();
      notesController.dispose();
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);

      if (messenger == null) return;

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    });
  }

  Widget buildTunggakanCard(Map<String, dynamic> item, int index) {
    final booking = Map<String, dynamic>.from(item["booking"] as Map);
    final invoice = Map<String, dynamic>.from(item["invoice"] as Map);
    final hasPending = item["has_pending_payment"] == true;

    final isGrace = isGraceActive(booking);
    final isOverdue = isInvoiceOverdue(invoice);
    final effectiveIsOverdue = isOverdue && !isGrace;

    final statusColor = getInvoiceStatusColor(
      invoice: invoice,
      booking: booking,
    );

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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: statusColor.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.08),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    effectiveIsOverdue
                        ? Icons.warning_amber_rounded
                        : isGrace
                        ? Icons.schedule_rounded
                        : Icons.receipt_long_rounded,
                    color: statusColor,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    getPropertyName(booking),
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
                    getInvoiceStatusText(invoice: invoice, booking: booking),
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
                  Icons.location_on_rounded,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    getPropertyAddress(booking),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

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
                    "${formatDate(invoice["period_start"])} - ${formatDate(invoice["period_end"])}",
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
                Icon(
                  effectiveIsOverdue
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    "Jatuh tempo: ${formatDate(invoice["due_date"])}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Sisa tagihan ${formatRupiah(getInvoicePayableAmount(invoice))}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Invoice #${getInvoiceId(invoice)}",
                    style: TextStyle(
                      color: statusColor.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            if (isGrace) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.withOpacity(0.20)),
                ),
                child: Text(
                  "Owner memberi masa tenggang sampai ${formatDate(booking["grace_until"] ?? booking["graceUntil"])}. Kamu tetap bisa mengirim bukti pembayaran dari halaman ini.",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (hasPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.withOpacity(0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Bukti pembayaran sedang menunggu konfirmasi owner.",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: uploading
                      ? null
                      : () {
                          showPaymentSheet(booking: booking, invoice: invoice);
                        },
                  icon: uploading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(
                    effectiveIsOverdue
                        ? "Kirim Bukti Pembayaran Baru"
                        : isGrace
                        ? "Kirim Bukti Pembayaran Grace"
                        : "Kirim Bukti Pembayaran",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveIsOverdue
                        ? Colors.red
                        : isGrace
                        ? Colors.orange
                        : primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
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
          height: 170,
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
      onRefresh: loadTunggakan,
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
                    Icons.check_circle_rounded,
                    color: primaryColor,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Tidak ada tunggakan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tidak ada invoice yang overdue atau sedang masa grace.",
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
      onRefresh: loadTunggakan,
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
                  onTap: loadTunggakan,
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

  Widget buildContent() {
    if (loading) return buildLoading();

    if (errorMessage != null) return buildError();

    if (arrears.isEmpty) return buildEmpty();

    return RefreshIndicator(
      onRefresh: loadTunggakan,
      color: primaryColor,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: arrears.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return buildTunggakanCard(arrears[index], index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
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
                            "Tunggakan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Hanya menampilkan invoice overdue dan grace",
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
                      onTap: loadTunggakan,
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
