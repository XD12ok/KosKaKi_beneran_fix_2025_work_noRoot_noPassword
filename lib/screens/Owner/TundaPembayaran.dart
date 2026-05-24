import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';

const Color primaryColor = Color(0xFF0A0E50);
const Color secondaryColor = Color(0xFF2D2F8F);
const Color softBlue = Color(0xFFEFF2FF);
const Color softOrange = Color(0xFFFFF4E5);
const Color darkText = Color(0xFF161A33);

class TundaPembayaran extends StatefulWidget {
  const TundaPembayaran({super.key});

  @override
  State<TundaPembayaran> createState() => _TundaPembayaranState();
}

class _TundaPembayaranState extends State<TundaPembayaran> {
  bool loading = true;
  bool actionLoading = false;

  String? errorMessage;

  List<Map<String, dynamic>> delayRequests = [];

  String get baseUrlWithoutApi {
    return ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  }

  @override
  void initState() {
    super.initState();
    loadTundaPembayaran();
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
      "Authorization": "Bearer $cleanedToken",
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-Requested-With": "XMLHttpRequest",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
    };
  }

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<Map<String, dynamic>> parseDataList(dynamic decoded) {
    dynamic rawData;

    if (decoded is Map<String, dynamic>) {
      rawData = decoded["data"];

      if (rawData is Map<String, dynamic> && rawData["data"] != null) {
        rawData = rawData["data"];
      }

      if (rawData == null && decoded["rental_bookings"] != null) {
        rawData = decoded["rental_bookings"];
      }

      if (rawData == null && decoded["bookings"] != null) {
        rawData = decoded["bookings"];
      }

      if (rawData == null && decoded["invoices"] != null) {
        rawData = decoded["invoices"];
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

  String cleanLower(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
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

  int getRentalBookingId(Map<String, dynamic> booking) {
    return toInt(
          booking["rental_booking_id"] ??
              booking["rentalBookingId"] ??
              booking["id"] ??
              booking["rental_id"] ??
              booking["rentalId"],
        ) ??
        0;
  }

  int getInvoiceId(Map<String, dynamic> invoice) {
    return toInt(
          invoice["id"] ?? invoice["invoice_id"] ?? invoice["invoiceId"],
        ) ??
        0;
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

  String formatDateForBackend(DateTime date) {
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");

    return "${date.year}-$month-$day";
  }

  String formatDate(dynamic value) {
    if (value == null) return "-";

    final text = value.toString().trim();

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

  String formatRupiah(dynamic value) {
    final number = toInt(value) ?? 0;

    final result = number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp $result";
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

  String getPropertyName(Map<String, dynamic> booking) {
    final property = getProperty(booking);

    final value =
        property["title"] ??
        property["property_name"] ??
        property["nama_kos"] ??
        property["nama_kost"] ??
        property["name"] ??
        property["nama"] ??
        booking["place_property_name"] ??
        booking["property_name"] ??
        booking["nama_kos"] ??
        booking["nama_kost"] ??
        booking["kos_name"];

    final text = value?.toString().trim() ?? "";

    if (text.isEmpty || text == "null") {
      return "Nama kos tidak tersedia";
    }

    return text;
  }

  String getPropertyAddress(Map<String, dynamic> booking) {
    final property = getProperty(booking);
    final city = toMap(property["city"]);

    final value =
        property["address"] ??
        property["alamat"] ??
        city?["name"] ??
        booking["address"] ??
        booking["alamat"] ??
        booking["location"] ??
        booking["lokasi"];

    final text = value?.toString().trim() ?? "";

    if (text.isEmpty || text == "null") {
      return "Alamat belum tersedia";
    }

    return text;
  }

  String getTenantName(Map<String, dynamic> booking) {
    final user = getUser(booking);

    final value =
        user["name"] ??
        user["username"] ??
        user["full_name"] ??
        booking["user_name"] ??
        booking["tenant_name"];

    final text = value?.toString().trim() ?? "";

    if (text.isEmpty || text == "null") {
      return "Penyewa";
    }

    return text;
  }

  int getInvoiceRemainingAmount(Map<String, dynamic> invoice) {
    final remaining = toInt(invoice["remaining_amount"]);

    if (remaining != null && remaining > 0) {
      return remaining;
    }

    final total =
        toInt(
          invoice["total_amount"] ??
              invoice["amount"] ??
              invoice["grand_total"],
        ) ??
        0;

    final paid = toInt(invoice["paid_amount"]) ?? 0;

    final result = total - paid;

    return result > 0 ? result : 0;
  }

  bool isGraceActive(Map<String, dynamic> booking) {
    final status =
        booking["payment_status"]?.toString().toLowerCase().trim() ?? "";

    if (status != "grace") return false;

    final graceUntil = parseNullableDate(
      booking["grace_until"] ?? booking["graceUntil"],
    );

    if (graceUntil == null) return true;

    return DateTime.now().isBefore(endOfDay(graceUntil));
  }

  bool isInvoiceOverdue(Map<String, dynamic> invoice) {
    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";

    if (status == "paid" || status == "lunas") {
      return false;
    }

    if (status == "overdue" || status == "terlambat") {
      return true;
    }

    final amount = getInvoiceRemainingAmount(invoice);

    if (amount <= 0) return false;

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

  bool isInvoiceNeedDelay(Map<String, dynamic> invoice) {
    return isInvoiceOverdue(invoice);
  }

  String getInvoiceStatusText({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> booking,
    required bool onlyFamilyCode,
  }) {
    if (onlyFamilyCode) {
      return "Kode Family";
    }

    if (isGraceActive(booking)) {
      return "Masa Tunda";
    }

    if (isInvoiceOverdue(invoice)) {
      return "Overdue";
    }

    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";

    if (status == "unpaid" || status == "belum_bayar") {
      return "Belum Bayar";
    }

    if (status == "partial") {
      return "Sebagian";
    }

    if (status.isEmpty || status == "null") {
      return "Belum Bayar";
    }

    return status;
  }

  Color getInvoiceStatusColor({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> booking,
    required bool onlyFamilyCode,
  }) {
    if (onlyFamilyCode) return primaryColor;

    if (isGraceActive(booking)) return Colors.orange;

    if (isInvoiceOverdue(invoice)) return Colors.red;

    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";

    if (status == "unpaid" || status == "belum_bayar") return Colors.orange;
    if (status == "partial") return Colors.deepOrange;
    if (status == "overdue" || status == "terlambat") return Colors.red;

    return primaryColor;
  }

  bool isLikelyFamilyCode(dynamic value) {
    if (value == null) return false;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return false;
    if (text.length < 4 || text.length > 60) return false;
    if (RegExp(r'^\d+$').hasMatch(text)) return false;

    return RegExp(r'[A-Za-z]').hasMatch(text);
  }

  String getStringValue(dynamic value) {
    if (!isLikelyFamilyCode(value)) return "";

    return value.toString().trim();
  }

  String extractFamilyCodeFromMap(Map<String, dynamic> map) {
    final directKeys = [
      "family_code",
      "familyCode",
      "invite_code",
      "inviteCode",
      "family_invite_code_text",
      "familyInviteCodeText",
    ];

    for (final key in directKeys) {
      final text = getStringValue(map[key]);

      if (text.isNotEmpty) {
        return text;
      }
    }

    final nestedKeys = [
      "family_invite_code",
      "familyInviteCode",
      "family_invite",
      "familyInvite",
      "invite",
    ];

    for (final key in nestedKeys) {
      final nested = toMap(map[key]);

      if (nested != null) {
        final code = getStringValue(
          nested["code"] ??
              nested["family_code"] ??
              nested["invite_code"] ??
              nested["familyCode"] ??
              nested["inviteCode"],
        );

        if (code.isNotEmpty) {
          return code;
        }
      }
    }

    final listKeys = ["family_invite_codes", "familyInviteCodes", "invites"];

    for (final key in listKeys) {
      final list = map[key];

      if (list is List) {
        for (final item in list) {
          final nested = toMap(item);

          if (nested == null) continue;

          final code = getStringValue(
            nested["code"] ??
                nested["family_code"] ??
                nested["invite_code"] ??
                nested["familyCode"] ??
                nested["inviteCode"],
          );

          if (code.isNotEmpty) {
            return code;
          }
        }
      }
    }

    return "";
  }

  String extractFamilyCode(dynamic decoded) {
    final map = toMap(decoded);

    if (map == null) return "";

    final direct = extractFamilyCodeFromMap(map);

    if (direct.isNotEmpty) {
      return direct;
    }

    final data = toMap(map["data"]);

    if (data != null) {
      final dataCode = extractFamilyCodeFromMap(data);

      if (dataCode.isNotEmpty) {
        return dataCode;
      }
    }

    return "";
  }

  String getFamilyCodeFromBooking(Map<String, dynamic> booking) {
    final direct = extractFamilyCodeFromMap(booking);

    if (direct.isNotEmpty) {
      return direct;
    }

    final user = getUser(booking);

    final userCode = extractFamilyCodeFromMap(user);

    if (userCode.isNotEmpty) {
      return userCode;
    }

    return "";
  }

  bool hasApprovedInitialPayment(Map<String, dynamic> booking) {
    final payments =
        booking["payments"] ??
        booking["rental_payments"] ??
        booking["rentalPayments"];

    bool hasAnyApprovedPayment = false;

    if (payments is List) {
      for (final item in payments) {
        final payment = toMap(item);

        if (payment == null) continue;

        final status = cleanLower(
          payment["status"] ?? payment["payment_status"],
        );

        final type = cleanLower(payment["type"]);

        if (status == "approved") {
          hasAnyApprovedPayment = true;
        }

        if (status == "approved" && type == "initial") {
          return true;
        }
      }
    }

    final bookingStatus = cleanLower(booking["status"]);
    final paymentStatus = cleanLower(booking["payment_status"]);
    final approvedAt = booking["approved_at"]?.toString().trim() ?? "";

    if (bookingStatus == "active" &&
        paymentStatus == "active" &&
        approvedAt.isNotEmpty &&
        approvedAt != "null" &&
        hasAnyApprovedPayment) {
      return true;
    }

    return false;
  }

  Future<String> fetchFamilyCodeForBooking({
    required int rentalBookingId,
    required String token,
  }) async {
    final urls = [
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/family-invite-code",
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/family-code",
      "${ApiService.baseUrl}/rental-booking/$rentalBookingId/family-invite-code",
      "${ApiService.baseUrl}/rental-booking/$rentalBookingId/family-code",
      "${ApiService.baseUrl}/family-invite-codes/rental-booking/$rentalBookingId",
      "${ApiService.baseUrl}/family-invite-code/rental-booking/$rentalBookingId",
      "${ApiService.baseUrl}/family-invite-codes/$rentalBookingId",
      "${ApiService.baseUrl}/family-invite-code/$rentalBookingId",
    ];

    for (final rawUrl in urls) {
      try {
        final response = await http
            .get(Uri.parse(rawUrl), headers: authHeaders(token))
            .timeout(const Duration(seconds: 15));

        debugPrint("GET FAMILY CODE URL:");
        debugPrint(rawUrl);
        debugPrint("GET FAMILY CODE STATUS:");
        debugPrint(response.statusCode.toString());
        debugPrint("GET FAMILY CODE BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final code = extractFamilyCode(decoded);

          if (code.isNotEmpty) {
            return code;
          }
        }

        if (response.statusCode != 404 && response.statusCode != 405) {
          return "";
        }
      } catch (e) {
        debugPrint("GET FAMILY CODE ERROR:");
        debugPrint(e.toString());
      }
    }

    return "";
  }

  bool hasPendingPayment(Map<String, dynamic> invoice) {
    final payments =
        invoice["payments"] ??
        invoice["rental_payments"] ??
        invoice["rentalPayments"];

    if (payments is List) {
      for (final item in payments) {
        final payment = toMap(item);

        if (payment == null) continue;

        final status = cleanLower(
          payment["status"] ?? payment["payment_status"],
        );

        if (status == "pending" ||
            status == "waiting" ||
            status == "waiting_confirmation" ||
            status == "waiting_verification" ||
            status == "menunggu" ||
            status == "unverified") {
          return true;
        }
      }
    }

    return false;
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
        final response = await http
            .get(Uri.parse(url), headers: authHeaders(token))
            .timeout(const Duration(seconds: 20));

        debugPrint("GET INVOICES TUNDA URL:");
        debugPrint(url);
        debugPrint("GET INVOICES TUNDA STATUS:");
        debugPrint(response.statusCode.toString());
        debugPrint("GET INVOICES TUNDA BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final invoices = parseDataList(decoded);

          return invoices.where((invoice) {
            final id = toInt(invoice["rental_booking_id"]);

            if (id == null || id <= 0) return true;

            return id == rentalBookingId;
          }).toList();
        }

        if (response.statusCode != 404 && response.statusCode != 405) {
          return [];
        }
      } catch (e) {
        debugPrint("FETCH INVOICES TUNDA ERROR:");
        debugPrint(e.toString());
      }
    }

    return [];
  }

  Future<void> loadTundaPembayaran() async {
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

      final response = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/rental-bookings?_=$cacheBuster"),
            headers: authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("GET BOOKINGS TUNDA STATUS:");
      debugPrint(response.statusCode.toString());
      debugPrint("GET BOOKINGS TUNDA BODY:");
      debugPrint(response.body);

      if (response.statusCode == 401) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = "Sesi login habis. Silakan login ulang.";
        });

        return;
      }

      if (response.statusCode != 200) {
        final message = parseResponseMessage(
          response.body,
          "Gagal memuat data tunda pembayaran.",
        );

        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = message;
        });

        return;
      }

      final decoded = jsonDecode(response.body);
      final bookings = parseDataList(decoded);

      final List<Map<String, dynamic>> result = [];

      for (final rawBooking in bookings) {
        final booking = Map<String, dynamic>.from(rawBooking);
        final rentalBookingId = getRentalBookingId(booking);

        debugPrint("TUNDA RENTAL BOOKING ID USED:");
        debugPrint(
          {
            "id": booking["id"],
            "booking_id": booking["booking_id"],
            "rental_booking_id_used": rentalBookingId,
          }.toString(),
        );

        if (rentalBookingId <= 0) continue;

        final invoices = await fetchInvoicesForBooking(
          rentalBookingId: rentalBookingId,
          token: token,
        );

        String familyCode = getFamilyCodeFromBooking(booking);
        final initialPaid = hasApprovedInitialPayment(booking);

        if (familyCode.isEmpty && initialPaid) {
          familyCode = await fetchFamilyCodeForBooking(
            rentalBookingId: rentalBookingId,
            token: token,
          );
        }

        bool addedGraceCard = false;

        for (final rawInvoice in invoices) {
          final invoice = Map<String, dynamic>.from(rawInvoice);

          final shouldShowGrace =
              isInvoiceNeedDelay(invoice) || isGraceActive(booking);

          if (!shouldShowGrace) continue;

          result.add({
            "booking": booking,
            "invoice": invoice,
            "mode": "grace",
            "family_code": familyCode,
            "has_initial_payment": initialPaid,
            "has_pending_payment": hasPendingPayment(invoice),
          });

          addedGraceCard = true;
        }

        if (!addedGraceCard && familyCode.isNotEmpty) {
          result.add({
            "booking": booking,
            "invoice": invoices.isNotEmpty
                ? invoices.first
                : <String, dynamic>{},
            "mode": "family",
            "family_code": familyCode,
            "has_initial_payment": true,
            "has_pending_payment": false,
          });
        }
      }

      result.sort((a, b) {
        final bookingA = toMap(a["booking"]) ?? {};
        final bookingB = toMap(b["booking"]) ?? {};
        final invoiceA = toMap(a["invoice"]) ?? {};
        final invoiceB = toMap(b["invoice"]) ?? {};

        final modeA = a["mode"]?.toString() ?? "";
        final modeB = b["mode"]?.toString() ?? "";

        if (modeA == "grace" && modeB == "family") return -1;
        if (modeA == "family" && modeB == "grace") return 1;

        final graceA = parseNullableDate(
          bookingA["grace_until"] ?? bookingA["graceUntil"],
        );

        final graceB = parseNullableDate(
          bookingB["grace_until"] ?? bookingB["graceUntil"],
        );

        final dueA = parseNullableDate(
          invoiceA["due_date"] ?? invoiceA["dueDate"],
        );

        final dueB = parseNullableDate(
          invoiceB["due_date"] ?? invoiceB["dueDate"],
        );

        final dateA = graceA ?? dueA ?? DateTime(2000);
        final dateB = graceB ?? dueB ?? DateTime(2000);

        return dateA.compareTo(dateB);
      });

      if (!mounted) return;

      setState(() {
        delayRequests = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD TUNDA PEMBAYARAN ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = "Terjadi kesalahan saat memuat tunda pembayaran.";
      });
    }
  }

  Future<bool> giveGrace({
    required int rentalBookingId,
    required DateTime graceUntil,
  }) async {
    final token = cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      showMessage("Token tidak ditemukan. Silakan login ulang.");
      return false;
    }

    if (rentalBookingId <= 0) {
      showMessage("Rental booking ID tidak valid.");
      return false;
    }

    if (!mounted) return false;

    setState(() {
      actionLoading = true;
    });

    final graceText = formatDateForBackend(graceUntil);

    final urls = [
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/grace",
      "${ApiService.baseUrl}/rental-booking/$rentalBookingId/grace",
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/give-grace",
      "${ApiService.baseUrl}/rental-booking/$rentalBookingId/give-grace",
      "${ApiService.baseUrl}/invoices/rental-booking/$rentalBookingId/grace",
      "${ApiService.baseUrl}/give-grace/$rentalBookingId",
    ];

    http.Response? lastResponse;

    try {
      for (final rawUrl in urls) {
        final url = Uri.parse(rawUrl);

        debugPrint("GIVE GRACE URL:");
        debugPrint(url.toString());
        debugPrint("GIVE GRACE BODY:");
        debugPrint({"grace_until": graceText}.toString());

        final response = await http
            .post(
              url,
              headers: authHeaders(token),
              body: jsonEncode({"grace_until": graceText}),
            )
            .timeout(const Duration(seconds: 20));

        lastResponse = response;

        debugPrint("GIVE GRACE STATUS:");
        debugPrint(response.statusCode.toString());
        debugPrint("GIVE GRACE RESPONSE:");
        debugPrint(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          showMessage("Tunda pembayaran berhasil diberikan.", success: true);
          await loadTundaPembayaran();
          return true;
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        showMessage(
          parseResponseMessage(
            response.body,
            "Gagal memberi tunda pembayaran.",
          ),
        );

        return false;
      }

      showMessage(
        parseResponseMessage(
          lastResponse?.body ?? "",
          "Route grace belum cocok. Cek route api.php untuk InvoiceController@giveGrace.",
        ),
      );

      return false;
    } catch (e) {
      debugPrint("GIVE GRACE ERROR:");
      debugPrint(e.toString());

      showMessage("Terjadi kesalahan saat memberi tunda pembayaran.");
      return false;
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> showGraceDialog(Map<String, dynamic> item) async {
    final booking = toMap(item["booking"]) ?? {};
    final invoice = toMap(item["invoice"]) ?? {};

    final rentalBookingId = getRentalBookingId(booking);

    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));

    final currentGrace = parseNullableDate(
      booking["grace_until"] ?? booking["graceUntil"],
    );

    if (currentGrace != null && currentGrace.isAfter(DateTime.now())) {
      selectedDate = currentGrace;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickDate() async {
              final result = await showDatePicker(
                context: sheetContext,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );

              if (result == null) return;

              setSheetState(() {
                selectedDate = result;
              });
            }

            Widget quickButton({required String label, required int days}) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setSheetState(() {
                      selectedDate = DateTime.now().add(Duration(days: days));
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: softBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withOpacity(0.16)),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                        "Beri Tunda Pembayaran",
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
                      const SizedBox(height: 18),
                      buildInfoBox(
                        icon: Icons.person_rounded,
                        title: "Penyewa",
                        value: getTenantName(booking),
                      ),
                      buildInfoBox(
                        icon: Icons.receipt_long_rounded,
                        title: "Invoice",
                        value:
                            "#${getInvoiceId(invoice)} • ${formatRupiah(getInvoiceRemainingAmount(invoice))}",
                      ),
                      buildInfoBox(
                        icon: Icons.event_busy_rounded,
                        title: "Jatuh Tempo",
                        value: formatDate(invoice["due_date"]),
                      ),
                      GestureDetector(
                        onTap: pickDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: softOrange,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Tunda sampai tanggal",
                                      style: TextStyle(
                                        color: Colors.black45,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDate(selectedDate),
                                      style: const TextStyle(
                                        color: darkText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.edit_calendar_rounded,
                                color: primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          quickButton(label: "+3 Hari", days: 3),
                          const SizedBox(width: 8),
                          quickButton(label: "+7 Hari", days: 7),
                          const SizedBox(width: 8),
                          quickButton(label: "+14 Hari", days: 14),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: actionLoading
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);

                                  await giveGrace(
                                    rentalBookingId: rentalBookingId,
                                    graceUntil: selectedDate,
                                  );
                                },
                          icon: actionLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.schedule_rounded),
                          label: Text(
                            actionLoading
                                ? "Memproses..."
                                : "Simpan Tunda Pembayaran",
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
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? Colors.green : Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget buildInfoBox({
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
            color: primaryColor.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
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

  Widget buildFamilyCodeBox(String familyCode) {
    if (familyCode.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_rounded, color: primaryColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Kode Family",
                  style: TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              familyCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: familyCode));
                showMessage("Kode family berhasil disalin.", success: true);
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text(
                "Salin Kode Family",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDelayCard(Map<String, dynamic> item, int index) {
    final booking = toMap(item["booking"]) ?? {};
    final invoice = toMap(item["invoice"]) ?? {};

    final mode = item["mode"]?.toString() ?? "grace";
    final familyCode = item["family_code"]?.toString() ?? "";
    final onlyFamilyCode = mode == "family";

    final hasPending = item["has_pending_payment"] == true;

    final statusColor = getInvoiceStatusColor(
      invoice: invoice,
      booking: booking,
      onlyFamilyCode: onlyFamilyCode,
    );

    final graceUntil = parseNullableDate(
      booking["grace_until"] ?? booking["graceUntil"],
    );

    final activeGrace = isGraceActive(booking);
    final overdue = isInvoiceOverdue(invoice);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 70)),
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
              color: statusColor.withOpacity(0.09),
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
                    onlyFamilyCode
                        ? Icons.groups_rounded
                        : activeGrace
                        ? Icons.schedule_rounded
                        : overdue
                        ? Icons.warning_amber_rounded
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
                    getInvoiceStatusText(
                      invoice: invoice,
                      booking: booking,
                      onlyFamilyCode: onlyFamilyCode,
                    ),
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
            buildSmallRow(
              icon: Icons.person_rounded,
              color: primaryColor,
              text: getTenantName(booking),
            ),
            const SizedBox(height: 8),
            buildSmallRow(
              icon: Icons.location_on_rounded,
              color: primaryColor,
              text: getPropertyAddress(booking),
            ),
            if (!onlyFamilyCode) ...[
              const SizedBox(height: 8),
              buildSmallRow(
                icon: Icons.calendar_month_rounded,
                color: primaryColor,
                text:
                    "${formatDate(invoice["period_start"])} - ${formatDate(invoice["period_end"])}",
              ),
              const SizedBox(height: 8),
              buildSmallRow(
                icon: Icons.event_busy_rounded,
                color: statusColor,
                text: "Jatuh tempo: ${formatDate(invoice["due_date"])}",
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
                        "Sisa tagihan ${formatRupiah(getInvoiceRemainingAmount(invoice))}",
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
            ],
            if (activeGrace && !onlyFamilyCode) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.withOpacity(0.24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        graceUntil == null
                            ? "Sedang dalam masa tunda pembayaran."
                            : "Tunda pembayaran aktif sampai ${formatDate(graceUntil)}.",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasPending && !onlyFamilyCode) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.blue.withOpacity(0.18)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Penyewa sudah mengirim bukti pembayaran dan sedang menunggu verifikasi di halaman pembayaran.",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (familyCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              buildFamilyCodeBox(familyCode),
            ],
            if (!onlyFamilyCode) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: actionLoading
                      ? null
                      : () {
                          showGraceDialog(item);
                        },
                  icon: actionLoading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.schedule_send_rounded),
                  label: Text(
                    activeGrace
                        ? "Ubah Tanggal Tunda"
                        : "Beri Tunda Pembayaran",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeGrace ? Colors.orange : primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSmallRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color == primaryColor ? Colors.black54 : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tunda Pembayaran",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${delayRequests.length} data aktif",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loading ? null : loadTundaPembayaran,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
          height: 190,
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
      onRefresh: loadTundaPembayaran,
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
                  "Tidak ada data tunda pembayaran",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "User yang invoice-nya overdue atau sedang grace akan muncul di sini. Kode family juga akan muncul kalau tersedia dari backend.",
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
      onRefresh: loadTundaPembayaran,
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
                ElevatedButton.icon(
                  onPressed: loadTundaPembayaran,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    "Coba Lagi",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
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
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (loading) return buildLoading();

    if (errorMessage != null) return buildError();

    if (delayRequests.isEmpty) return buildEmpty();

    return RefreshIndicator(
      onRefresh: loadTundaPembayaran,
      color: primaryColor,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: delayRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return buildDelayCard(delayRequests[index], index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                buildHeader(),
                Expanded(child: buildContent()),
              ],
            ),
            if (actionLoading)
              Container(
                color: Colors.black.withOpacity(0.18),
                child: const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
