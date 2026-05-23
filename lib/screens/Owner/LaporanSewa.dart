import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';

class LaporanSewa extends StatefulWidget {
  const LaporanSewa({super.key});

  @override
  State<LaporanSewa> createState() => _LaporanSewaState();
}

class _LaporanSewaState extends State<LaporanSewa> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  bool isLoading = true;
  bool isActionLoading = false;

  List<Map<String, dynamic>> reports = [];
  Map<int, Map<String, dynamic>> rentalHistoryById = {};

  // Menyimpan card mana yang sedang dibuka/extend
  Set<int> expandedReportKeys = {};

  @override
  void initState() {
    super.initState();
    fetchRentalBookings();
  }

  int getReportKey(Map<String, dynamic> report) {
    final booking = toMap(report["booking"]) ?? {};
    final payment = toMap(report["payment"]) ?? {};

    final paymentId = parseIntValue(payment["id"]);
    final bookingId = parseIntValue(booking["id"]);

    if (paymentId > 0) return paymentId;
    if (bookingId > 0) return bookingId;

    return report.hashCode;
  }

  void toggleReportExpanded(Map<String, dynamic> report) {
    final key = getReportKey(report);

    setState(() {
      if (expandedReportKeys.contains(key)) {
        expandedReportKeys.remove(key);
      } else {
        expandedReportKeys.add(key);
      }
    });
  }

  Widget extendShortButton({
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
        ),
        label: Text(
          isExpanded ? "Short" : "Extend",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryColor.withOpacity(0.35)),
          backgroundColor: const Color(0xFFF4F6FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  String get baseUrlWithoutApi {
    return ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
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

  Future<String?> getValidToken() async {
    final rawToken = await ApiService().getToken();
    final token = cleanToken(rawToken);

    debugPrint("TOKEN STATUS:");
    debugPrint(
      token.isEmpty ? "TOKEN KOSONG" : "TOKEN ADA LENGTH: ${token.length}",
    );

    if (token.isEmpty) return null;

    return token;
  }

  Map<String, String> authHeaders(String token) {
    final cleanedToken = cleanToken(token);

    return {
      "Authorization": "Bearer $cleanedToken",
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-Requested-With": "XMLHttpRequest",
    };
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

    if (value is List) return value;

    if (value is Map) {
      if (value["data"] is List) return value["data"];

      if (value["data"] is Map && value["data"]["data"] is List) {
        return value["data"]["data"];
      }

      if (value["rental_bookings"] is List) return value["rental_bookings"];
      if (value["rentalBookings"] is List) return value["rentalBookings"];
      if (value["bookings"] is List) return value["bookings"];
      if (value["items"] is List) return value["items"];
      if (value["results"] is List) return value["results"];
    }

    return [];
  }

  int parseIntValue(dynamic value) {
    if (value == null) return 0;

    final cleaned = value.toString().replaceAll(RegExp(r"[^0-9]"), "");

    if (cleaned.isEmpty) return 0;

    return int.tryParse(cleaned) ?? 0;
  }

  String cleanLower(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
  }

  String safeText(dynamic value, {String fallback = "-"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  int getRentalBookingIdFromData(Map<String, dynamic> data) {
    final rentalBooking =
        toMap(data["rental_booking"]) ??
        toMap(data["rentalBooking"]) ??
        toMap(data["booking"]);

    return parseIntValue(
      data["rental_booking_id"] ??
          data["rentalBookingId"] ??
          data["booking_id"] ??
          rentalBooking?["id"] ??
          data["id"],
    );
  }

  Map<String, dynamic> getPropertyFromHistory(Map<String, dynamic> history) {
    final rentalBooking =
        toMap(history["rental_booking"]) ??
        toMap(history["rentalBooking"]) ??
        toMap(history["booking"]);

    return toMap(history["place_property"]) ??
        toMap(history["placeProperty"]) ??
        toMap(history["property"]) ??
        toMap(history["kos"]) ??
        toMap(history["kost"]) ??
        toMap(rentalBooking?["place_property"]) ??
        toMap(rentalBooking?["placeProperty"]) ??
        toMap(rentalBooking?["property"]) ??
        toMap(rentalBooking?["kos"]) ??
        toMap(rentalBooking?["kost"]) ??
        {};
  }

  Future<Map<int, Map<String, dynamic>>> fetchRentalBookingHistoryMap(
    String token,
  ) async {
    final Map<int, Map<String, dynamic>> result = {};

    try {
      final url = Uri.parse("${ApiService.baseUrl}/rental-bookings/history");

      debugPrint("GET RENTAL BOOKINGS HISTORY URL:");
      debugPrint(url.toString());

      final response = await http
          .get(url, headers: authHeaders(token))
          .timeout(const Duration(seconds: 20));

      debugPrint("GET RENTAL BOOKINGS HISTORY STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET RENTAL BOOKINGS HISTORY BODY:");
      debugPrint(response.body);

      if (response.statusCode != 200) {
        return result;
      }

      final decoded = jsonDecode(response.body);
      final histories = parseDynamicList(decoded);

      for (final item in histories) {
        final history = toMap(item);

        if (history == null) continue;

        final rentalBookingId = getRentalBookingIdFromData(history);

        if (rentalBookingId > 0) {
          result[rentalBookingId] = history;
        }
      }

      debugPrint("HISTORY MAP TOTAL:");
      debugPrint(result.length.toString());

      return result;
    } catch (e) {
      debugPrint("FETCH RENTAL BOOKING HISTORY ERROR:");
      debugPrint(e.toString());

      return result;
    }
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

  String formatRupiah(dynamic value) {
    if (value == null) return "0";

    String raw = value.toString().trim();

    if (raw.isEmpty || raw == "null") return "0";

    raw = raw.replaceAll("Rp", "").trim();

    if (RegExp(r',\d{1,2}$').hasMatch(raw)) {
      raw = raw.split(',').first;
    }

    if (RegExp(r'\.\d{1,2}$').hasMatch(raw)) {
      raw = raw.split('.').first;
    }

    final number = raw.replaceAll(RegExp(r"[^0-9]"), "");

    if (number.isEmpty) return "0";

    final buffer = StringBuffer();
    int count = 0;

    for (int i = number.length - 1; i >= 0; i--) {
      buffer.write(number[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write(".");
        count = 0;
      }
    }

    return buffer.toString().split("").reversed.join();
  }

  String formatDate(dynamic value) {
    if (value == null) return "-";

    final raw = value.toString();

    if (raw.isEmpty || raw == "null") return "-";

    final date = DateTime.tryParse(raw);

    if (date == null) return raw;

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

  Future<void> fetchRentalBookings() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final token = await getValidToken();

      if (token == null || token.isEmpty) {
        showMessage("Token tidak ditemukan, silakan login ulang");

        if (!mounted) return;

        setState(() {
          reports = [];
          isLoading = false;
        });

        return;
      }

      final historyMap = await fetchRentalBookingHistoryMap(token);

      final url = Uri.parse("${ApiService.baseUrl}/rental-bookings");

      debugPrint("GET RENTAL BOOKINGS FOR LAPORAN SEWA URL:");
      debugPrint(url.toString());

      final response = await http
          .get(url, headers: authHeaders(token))
          .timeout(const Duration(seconds: 20));

      debugPrint("GET RENTAL BOOKINGS FOR LAPORAN SEWA STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET RENTAL BOOKINGS FOR LAPORAN SEWA BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final bookings = parseDynamicList(decoded);

        final List<Map<String, dynamic>> pendingReports = [];

        for (final item in bookings) {
          final booking = toMap(item);

          if (booking == null) continue;

          final payment = getPendingPaymentFromBooking(booking);

          if (payment == null) continue;

          final invoice = getInvoiceFromBookingOrPayment(
            booking: booking,
            payment: payment,
          );

          final rentalBookingId = getRentalBookingIdFromData(booking);
          final history = historyMap[rentalBookingId] ?? {};

          debugPrint("MATCH HISTORY FOR BOOKING:");
          debugPrint(
            {
              "rental_booking_id": rentalBookingId,
              "has_history": history.isNotEmpty,
              "history_property": getPropertyFromHistory(history),
            }.toString(),
          );

          pendingReports.add({
            "booking": booking,
            "payment": payment,
            "invoice": invoice,
            "history": history,
          });
        }

        if (!mounted) return;

        setState(() {
          rentalHistoryById = historyMap;
          reports = pendingReports;
        });
      } else {
        showMessage(
          parseResponseMessage(response.body, "Gagal mengambil pengajuan sewa"),
        );

        if (!mounted) return;

        setState(() {
          reports = [];
        });
      }
    } catch (e) {
      debugPrint("FETCH RENTAL BOOKINGS ERROR:");
      debugPrint(e.toString());

      showMessage("Terjadi kesalahan saat mengambil pengajuan sewa");

      if (!mounted) return;

      setState(() {
        reports = [];
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, dynamic>? getPendingPaymentFromBooking(
    Map<String, dynamic> booking,
  ) {
    final List<dynamic> paymentCandidates = [];

    void addIfExists(dynamic value) {
      if (value == null) return;

      if (value is List) {
        paymentCandidates.addAll(value);
      } else {
        paymentCandidates.add(value);
      }
    }

    addIfExists(booking["rental_payments"]);
    addIfExists(booking["rentalPayments"]);
    addIfExists(booking["payments"]);
    addIfExists(booking["payment"]);
    addIfExists(booking["rental_payment"]);
    addIfExists(booking["rentalPayment"]);
    addIfExists(booking["latest_payment"]);
    addIfExists(booking["latestPayment"]);

    final invoice = getInvoiceFromBooking(booking);

    if (invoice.isNotEmpty) {
      addIfExists(invoice["payments"]);
      addIfExists(invoice["rental_payments"]);
      addIfExists(invoice["rentalPayments"]);
      addIfExists(invoice["payment"]);
      addIfExists(invoice["latest_payment"]);
      addIfExists(invoice["latestPayment"]);
    }

    for (final item in paymentCandidates) {
      final payment = toMap(item);

      if (payment == null) continue;

      final paymentStatus = cleanLower(
        payment["status"] ?? payment["payment_status"],
      );

      debugPrint("CHECK RENTAL PAYMENT STATUS:");
      debugPrint(
        {
          "payment_id": payment["id"],
          "payment_status": paymentStatus,
          "payment_type": payment["type"],
          "sender_name": payment["sender_name"],
          "notes": payment["notes"],
        }.toString(),
      );

      final isPending =
          paymentStatus == "pending" ||
          paymentStatus == "waiting_confirmation" ||
          paymentStatus == "waiting" ||
          paymentStatus == "unverified" ||
          paymentStatus == "waiting_verification" ||
          paymentStatus == "menunggu";

      if (isPending) {
        return payment;
      }
    }

    return null;
  }

  Map<String, dynamic> getInvoiceFromBooking(Map<String, dynamic> booking) {
    final invoice =
        toMap(booking["invoice"]) ??
        toMap(booking["current_invoice"]) ??
        toMap(booking["currentInvoice"]) ??
        toMap(booking["initial_invoice"]) ??
        toMap(booking["initialInvoice"]);

    if (invoice != null) return invoice;

    final invoices = booking["invoices"];

    if (invoices is List && invoices.isNotEmpty) {
      final firstInvoice = toMap(invoices.first);

      if (firstInvoice != null) return firstInvoice;
    }

    return {};
  }

  Map<String, dynamic> getInvoiceFromBookingOrPayment({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> payment,
  }) {
    final paymentInvoice = toMap(payment["invoice"]);

    if (paymentInvoice != null) return paymentInvoice;

    return getInvoiceFromBooking(booking);
  }

  Map<String, dynamic> getProperty(Map<String, dynamic> booking) {
    final nestedBooking =
        toMap(booking["rental_booking"]) ??
        toMap(booking["rentalBooking"]) ??
        toMap(booking["booking"]);

    return toMap(booking["place_property"]) ??
        toMap(booking["placeProperty"]) ??
        toMap(booking["property"]) ??
        toMap(booking["kos"]) ??
        toMap(booking["kost"]) ??
        toMap(nestedBooking?["place_property"]) ??
        toMap(nestedBooking?["placeProperty"]) ??
        toMap(nestedBooking?["property"]) ??
        toMap(nestedBooking?["kos"]) ??
        toMap(nestedBooking?["kost"]) ??
        {};
  }

  Map<String, dynamic> getUser(Map<String, dynamic> booking) {
    return toMap(booking["user"]) ??
        toMap(booking["tenant"]) ??
        toMap(booking["customer"]) ??
        {};
  }

  String getPropertyNameFromReport({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> history,
  }) {
    final property = getProperty(booking);
    final historyProperty = getPropertyFromHistory(history);

    final rentalBooking =
        toMap(booking["rental_booking"]) ??
        toMap(booking["rentalBooking"]) ??
        toMap(booking["booking"]);

    final historyRentalBooking =
        toMap(history["rental_booking"]) ??
        toMap(history["rentalBooking"]) ??
        toMap(history["booking"]);

    final rentalBookingProperty =
        toMap(rentalBooking?["place_property"]) ??
        toMap(rentalBooking?["placeProperty"]) ??
        toMap(rentalBooking?["property"]) ??
        toMap(rentalBooking?["kos"]) ??
        toMap(rentalBooking?["kost"]) ??
        {};

    final historyRentalBookingProperty =
        toMap(historyRentalBooking?["place_property"]) ??
        toMap(historyRentalBooking?["placeProperty"]) ??
        toMap(historyRentalBooking?["property"]) ??
        toMap(historyRentalBooking?["kos"]) ??
        toMap(historyRentalBooking?["kost"]) ??
        {};

    final candidates = [
      property["title"],
      property["property_name"],
      property["nama_kos"],
      property["name"],
      property["nama"],

      rentalBookingProperty["title"],
      rentalBookingProperty["property_name"],
      rentalBookingProperty["nama_kos"],
      rentalBookingProperty["name"],
      rentalBookingProperty["nama"],

      historyProperty["title"],
      historyProperty["property_name"],
      historyProperty["nama_kos"],
      historyProperty["name"],
      historyProperty["nama"],

      historyRentalBookingProperty["title"],
      historyRentalBookingProperty["property_name"],
      historyRentalBookingProperty["nama_kos"],
      historyRentalBookingProperty["name"],
      historyRentalBookingProperty["nama"],

      booking["place_property_name"],
      booking["property_name"],
      booking["nama_kos"],
      booking["kos_name"],

      history["place_property_name"],
      history["property_name"],
      history["nama_kos"],
      history["kos_name"],
    ];

    for (final item in candidates) {
      final text = item?.toString().trim() ?? "";

      if (text.isNotEmpty && text != "null") {
        debugPrint("FINAL NAMA KOS:");
        debugPrint(text);
        return text;
      }
    }

    debugPrint("FINAL NAMA KOS:");
    debugPrint("Nama kos tidak tersedia");

    return "Nama kos tidak tersedia";
  }

  String getPropertyAddressFromReport({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> history,
  }) {
    final property = getProperty(booking);
    final historyProperty = getPropertyFromHistory(history);
    final city = toMap(property["city"]);
    final historyCity = toMap(historyProperty["city"]);
    final historyRentalBooking =
        toMap(history["rental_booking"]) ??
        toMap(history["rentalBooking"]) ??
        toMap(history["booking"]);

    return safeText(
      property["address"] ??
          property["alamat"] ??
          city?["name"] ??
          booking["address"] ??
          booking["alamat"] ??
          historyProperty["address"] ??
          historyProperty["alamat"] ??
          historyCity?["name"] ??
          history["address"] ??
          history["alamat"] ??
          historyRentalBooking?["address"] ??
          historyRentalBooking?["alamat"],
      fallback: "Alamat belum tersedia",
    );
  }

  String getPropertyImageFromReport({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> history,
  }) {
    final directImage = getPropertyImage(booking);

    if (directImage.isNotEmpty) return directImage;

    final historyProperty = getPropertyFromHistory(history);

    final mainImage = historyProperty["main_image"];

    if (mainImage != null && mainImage.toString() != "null") {
      final fixed = fixImageUrl(mainImage);

      if (fixed.isNotEmpty) return fixed;
    }

    final images = historyProperty["images"];

    if (images is List && images.isNotEmpty) {
      final fixed = fixImageUrl(images.first);

      if (fixed.isNotEmpty) return fixed;
    }

    final historyImage =
        history["image"] ??
        history["image_url"] ??
        history["main_image"] ??
        history["photo"];

    final fixedHistoryImage = fixImageUrl(historyImage);

    if (fixedHistoryImage.isNotEmpty) return fixedHistoryImage;

    return "";
  }

  String getTenantName(Map<String, dynamic> booking) {
    final user = getUser(booking);

    return safeText(
      user["name"] ??
          user["username"] ??
          user["full_name"] ??
          booking["user_name"] ??
          booking["tenant_name"],
      fallback: "Penyewa",
    );
  }

  String getSenderName(
    Map<String, dynamic> booking,
    Map<String, dynamic> payment,
  ) {
    return safeText(
      payment["sender_name"] ??
          payment["senderName"] ??
          booking["sender_name"] ??
          booking["senderName"],
      fallback: "-",
    );
  }

  String getPaymentNotes(
    Map<String, dynamic> booking,
    Map<String, dynamic> payment,
  ) {
    return safeText(
      payment["notes"] ??
          payment["note"] ??
          payment["catatan"] ??
          booking["notes"] ??
          booking["note"] ??
          booking["catatan"],
      fallback: "-",
    );
  }

  String fixImageUrl(dynamic img) {
    String url = "";

    if (img is String) {
      url = img;
    } else if (img is Map) {
      final fullImageUrl = img["full_image_url"]?.toString() ?? "";

      if (fullImageUrl.isNotEmpty &&
          fullImageUrl.startsWith("http") &&
          !fullImageUrl.endsWith("/storage")) {
        url = fullImageUrl;
      } else {
        url =
            img["url"]?.toString() ??
            img["image"]?.toString() ??
            img["path"]?.toString() ??
            img["image_path"]?.toString() ??
            img["file"]?.toString() ??
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

  String getPropertyImage(Map<String, dynamic> booking) {
    final property = getProperty(booking);

    final mainImage = property["main_image"];

    if (mainImage != null && mainImage.toString() != "null") {
      final fixed = fixImageUrl(mainImage);

      if (fixed.isNotEmpty) return fixed;
    }

    final images = property["images"];

    if (images is List && images.isNotEmpty) {
      final fixed = fixImageUrl(images.first);

      if (fixed.isNotEmpty) return fixed;
    }

    return "";
  }

  String getProofUrl(dynamic proof) {
    final proofPath = proof?.toString() ?? "";

    if (proofPath.isEmpty || proofPath == "null") return "";

    if (proofPath.startsWith("http")) return proofPath;

    if (proofPath.startsWith("/storage")) {
      return "$baseUrlWithoutApi$proofPath";
    }

    if (proofPath.startsWith("storage")) {
      return "$baseUrlWithoutApi/$proofPath";
    }

    return "$baseUrlWithoutApi/storage/$proofPath";
  }

  Future<void> approvePayment({
    required int paymentId,
    required String verifiedAmount,
  }) async {
    final cleanedAmount = verifiedAmount
        .replaceAll("Rp", "")
        .replaceAll(".", "")
        .replaceAll(",", "")
        .trim();

    if (cleanedAmount.isEmpty) {
      showMessage("Nominal verifikasi tidak boleh kosong");
      return;
    }

    final amount = double.tryParse(cleanedAmount);

    if (amount == null || amount <= 0) {
      showMessage("Nominal verifikasi tidak valid");
      return;
    }

    if (!mounted) return;

    setState(() {
      isActionLoading = true;
    });

    try {
      final token = await getValidToken();

      if (token == null || token.isEmpty) {
        showMessage(
          "Token tidak ditemukan. Silakan login ulang sebagai owner.",
        );
        return;
      }

      final url = Uri.parse(
        "${ApiService.baseUrl}/rental-payments/$paymentId/approve",
      );

      debugPrint("APPROVE PAYMENT URL:");
      debugPrint(url.toString());

      final response = await http
          .post(
            url,
            headers: authHeaders(token),
            body: jsonEncode({"verified_amount": amount, "status": "approved"}),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("APPROVE PAYMENT STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("APPROVE PAYMENT BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        showMessage("Pembayaran berhasil di-accept", success: true);
        await fetchRentalBookings();
      } else {
        showMessage(
          parseResponseMessage(response.body, "Gagal accept pembayaran"),
        );
      }
    } catch (e) {
      debugPrint("APPROVE PAYMENT ERROR:");
      debugPrint(e.toString());

      showMessage("Terjadi kesalahan saat accept pembayaran");
    } finally {
      if (!mounted) return;

      setState(() {
        isActionLoading = false;
      });
    }
  }

  Future<void> rejectPayment(int paymentId) async {
    if (!mounted) return;

    setState(() {
      isActionLoading = true;
    });

    try {
      final token = await getValidToken();

      if (token == null || token.isEmpty) {
        showMessage(
          "Token tidak ditemukan. Silakan login ulang sebagai owner.",
        );
        return;
      }

      final url = Uri.parse(
        "${ApiService.baseUrl}/rental-payments/$paymentId/reject",
      );

      debugPrint("REJECT PAYMENT URL:");
      debugPrint(url.toString());

      final response = await http
          .post(
            url,
            headers: authHeaders(token),
            body: jsonEncode({"status": "rejected"}),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("REJECT PAYMENT STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("REJECT PAYMENT BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        showMessage("Pembayaran berhasil di-reject", success: true);
        await fetchRentalBookings();
      } else {
        showMessage(
          parseResponseMessage(response.body, "Gagal reject pembayaran"),
        );
      }
    } catch (e) {
      debugPrint("REJECT PAYMENT ERROR:");
      debugPrint(e.toString());

      showMessage("Terjadi kesalahan saat reject pembayaran");
    } finally {
      if (!mounted) return;

      setState(() {
        isActionLoading = false;
      });
    }
  }

  void showApproveDialog(Map<String, dynamic> report) {
    final payment = toMap(report["payment"]) ?? {};
    final paymentId = parseIntValue(payment["id"]);

    if (paymentId <= 0) {
      showMessage("ID pembayaran tidak ditemukan dari data /rental-bookings");
      return;
    }

    final claimedAmount = payment["claimed_amount"] ?? payment["amount"] ?? "0";

    final controller = TextEditingController(
      text: formatRupiah(claimedAmount).replaceAll(".", ""),
    );

    showDialog(
      context: context,
      barrierDismissible: !isActionLoading,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            "Accept Pembayaran",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Nominal diterima",
              hintText: "Contoh: 1000000",
              prefixText: "Rp ",
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isActionLoading
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: isActionLoading
                  ? null
                  : () async {
                      Navigator.pop(context);

                      await approvePayment(
                        paymentId: paymentId,
                        verifiedAmount: controller.text,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Accept"),
            ),
          ],
        );
      },
    );
  }

  void showRejectDialog(Map<String, dynamic> report) {
    final payment = toMap(report["payment"]) ?? {};
    final paymentId = parseIntValue(payment["id"]);

    if (paymentId <= 0) {
      showMessage("ID pembayaran tidak ditemukan dari data /rental-bookings");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !isActionLoading,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Reject Pembayaran?",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            "Status rental payment akan diubah menjadi rejected.",
          ),
          actions: [
            TextButton(
              onPressed: isActionLoading
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: isActionLoading
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await rejectPayment(paymentId);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Reject"),
            ),
          ],
        );
      },
    );
  }

  void showProofImage(Map<String, dynamic> report) {
    final payment = toMap(report["payment"]) ?? {};
    final imageUrl = getProofUrl(payment["payment_proof"]);

    if (imageUrl.isEmpty) {
      showMessage("Bukti pembayaran tidak tersedia");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "Gagal memuat bukti pembayaran",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
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

  Widget buildHeader() {
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
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 38,
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
                    "Laporan Sewa",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Verifikasi Pembayaran",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${reports.length} pengajuan menunggu accept/reject",
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

  Widget connectedSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
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

  Widget totalBox({required String title, required String amount}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
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
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rp $amount",
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

  Widget proofButton(Map<String, dynamic> report) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () {
          showProofImage(report);
        },
        icon: Icon(Icons.zoom_in_rounded, color: primaryColor),
        label: Text(
          "Lihat Bukti Pembayaran",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget actionButtons(Map<String, dynamic> report) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: isActionLoading
                  ? null
                  : () {
                      showRejectDialog(report);
                    },
              icon: const Icon(Icons.close_rounded),
              label: const Text(
                "Reject",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isActionLoading
                  ? null
                  : () {
                      showApproveDialog(report);
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                "Accept",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildReportCard(Map<String, dynamic> report) {
    final booking = toMap(report["booking"]) ?? {};
    final payment = toMap(report["payment"]) ?? {};
    final invoice = toMap(report["invoice"]) ?? {};
    final history = toMap(report["history"]) ?? {};

    final reportKey = getReportKey(report);
    final isExpanded = expandedReportKeys.contains(reportKey);

    final imageUrl = getPropertyImageFromReport(
      booking: booking,
      history: history,
    );

    final propertyName = getPropertyNameFromReport(
      booking: booking,
      history: history,
    );

    final address = getPropertyAddressFromReport(
      booking: booking,
      history: history,
    );

    final tenantName = getTenantName(booking);

    final bookingId = safeText(booking["id"], fallback: "-");
    final paymentId = safeText(payment["id"], fallback: "-");
    final senderName = getSenderName(booking, payment);
    final paymentNotes = getPaymentNotes(booking, payment);

    final claimedAmount =
        payment["claimed_amount"] ??
        payment["amount"] ??
        booking["total_price"] ??
        booking["amount"];

    final totalAmount =
        invoice["total_amount"] ??
        booking["total_price"] ??
        booking["grand_total"] ??
        payment["amount"] ??
        claimedAmount;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
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
                          "Menunggu Verifikasi",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        propertyName,
                        maxLines: isExpanded ? 3 : 1,
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
                        address,
                        maxLines: isExpanded ? 3 : 1,
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
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: connectedSectionCard(
              title: isExpanded ? "Data Pengajuan Lengkap" : "Data Pengajuan",
              icon: Icons.assignment_outlined,
              children: [
                if (!isExpanded) ...[
                  summaryItem(
                    icon: Icons.person_outline,
                    title: "Nama Penyewa",
                    value: tenantName,
                  ),
                  summaryItem(
                    icon: Icons.receipt_long_outlined,
                    title: "Payment ID",
                    value: paymentId,
                  ),
                  totalBox(
                    title: "Nominal Dikirim Penyewa",
                    amount: formatRupiah(claimedAmount),
                  ),
                  const SizedBox(height: 4),
                  extendShortButton(
                    isExpanded: false,
                    onTap: () {
                      toggleReportExpanded(report);
                    },
                  ),
                ] else ...[
                  summaryItem(
                    icon: Icons.person_outline,
                    title: "Nama Penyewa",
                    value: tenantName,
                  ),
                  summaryItem(
                    icon: Icons.confirmation_number_outlined,
                    title: "Booking ID",
                    value: bookingId,
                  ),
                  summaryItem(
                    icon: Icons.receipt_long_outlined,
                    title: "Payment ID",
                    value: paymentId,
                  ),
                  summaryItem(
                    icon: Icons.account_circle_outlined,
                    title: "Nama Pengirim",
                    value: senderName,
                  ),
                  summaryItem(
                    icon: Icons.notes_rounded,
                    title: "Catatan",
                    value: paymentNotes,
                  ),
                  summaryItem(
                    icon: Icons.calendar_today_rounded,
                    title: "Tanggal Mulai",
                    value: formatDate(
                      booking["start_date"] ??
                          booking["check_in"] ??
                          booking["created_at"],
                    ),
                  ),
                  summaryItem(
                    icon: Icons.event_available_rounded,
                    title: "Tanggal Selesai",
                    value: formatDate(
                      booking["end_date"] ??
                          booking["check_out"] ??
                          invoice["period_end"],
                    ),
                  ),
                  summaryItem(
                    icon: Icons.receipt_outlined,
                    title: "Total Invoice",
                    value: "Rp ${formatRupiah(totalAmount)}",
                  ),
                  totalBox(
                    title: "Nominal Dikirim Penyewa",
                    amount: formatRupiah(claimedAmount),
                  ),
                  const SizedBox(height: 4),
                  proofButton(report),
                  const SizedBox(height: 14),
                  actionButtons(report),
                  const SizedBox(height: 12),
                  extendShortButton(
                    isExpanded: true,
                    onTap: () {
                      toggleReportExpanded(report);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyState() {
    return Container(
      width: double.infinity,
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
        children: [
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(color: softGreen, shape: BoxShape.circle),
            child: Icon(Icons.verified_rounded, color: primaryColor, size: 42),
          ),
          const SizedBox(height: 16),
          const Text(
            "Tidak Ada Pengajuan Pending",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "Semua pengajuan pembayaran sudah di-accept atau di-reject.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: fetchRentalBookings,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Refresh"),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
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
          "Laporan Sewa",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : fetchRentalBookings,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: primaryColor,
            onRefresh: fetchRentalBookings,
            child: isLoading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    child: Column(
                      children: [
                        buildHeader(),
                        if (reports.isEmpty)
                          emptyState()
                        else
                          ...reports.map(buildReportCard).toList(),
                      ],
                    ),
                  ),
          ),
          if (isActionLoading)
            Container(
              color: Colors.black.withOpacity(0.18),
              child: Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}
