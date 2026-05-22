import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/LiveChatOwner.dart';
import 'package:koskaki/service/api_service.dart';

class AjukanSurvey extends StatefulWidget {
  final Map<String, dynamic>? kos;
  final int? propertyId;

  const AjukanSurvey({super.key, this.kos, this.propertyId});

  @override
  State<AjukanSurvey> createState() => _AjukanSurveyState();
}

class _AjukanSurveyState extends State<AjukanSurvey> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  bool isLoading = false;
  bool hasReadArguments = false;

  Map<String, dynamic> kos = {};

  int? propertyId;
  int? ownerId;

  String title = "Kos";
  String address = "";
  String ownerName = "Pemilik Kos";

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (hasReadArguments) return;

    hasReadArguments = true;

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
        args['property_id']?.toString() ??
            args['place_property_id']?.toString() ??
            args['id']?.toString() ??
            "",
      );

      title = args['title']?.toString() ?? "";
      address = args['address']?.toString() ?? "";

      final owner = args['owner'];

      if (owner is Map) {
        ownerId = int.tryParse(owner['id']?.toString() ?? "");
        ownerName = owner['name']?.toString() ?? "Pemilik Kos";
      }

      ownerId ??= int.tryParse(args['owner_id']?.toString() ?? "");
    }

    if (widget.kos != null) {
      routeData = Map<String, dynamic>.from(widget.kos!);
    }

    propertyId ??= widget.propertyId;

    if (routeData.isNotEmpty) {
      kos = routeData;

      propertyId ??= int.tryParse(
        routeData['id']?.toString() ??
            routeData['property_id']?.toString() ??
            routeData['place_property_id']?.toString() ??
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

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String formatDate(DateTime date) {
    return "${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}";
  }

  String formatTime(TimeOfDay time) {
    return "${twoDigits(time.hour)}:${twoDigits(time.minute)}";
  }

  String formatDateReadable(DateTime? date) {
    if (date == null) return "Pilih tanggal survey";

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

  String formatTimeReadable(TimeOfDay? time) {
    if (time == null) return "Pilih jam survey";
    return "${twoDigits(time.hour)}:${twoDigits(time.minute)} WIB";
  }

  Future<void> pickSurveyDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: "Pilih Tanggal Survey",
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
      selectedDate = result;
    });
  }

  Future<void> pickSurveyTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: "Pilih Jam Survey",
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
      selectedTime = result;
    });
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

      if (fixed.isNotEmpty) {
        return fixed;
      }
    }

    final images = kos['images'];

    if (images is List && images.isNotEmpty) {
      final fixed = fixUrl(images.first);

      if (fixed.isNotEmpty) {
        return fixed;
      }
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

  bool validateForm() {
    if (propertyId == null || propertyId! <= 0) {
      showMessage("ID kos tidak ditemukan");
      return false;
    }

    if (ownerId == null || ownerId! <= 0) {
      showMessage("ID pemilik kos tidak ditemukan");
      return false;
    }

    if (selectedDate == null) {
      showMessage("Pilih tanggal survey terlebih dahulu");
      return false;
    }

    if (selectedTime == null) {
      showMessage("Pilih jam survey terlebih dahulu");
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

  Future<Map<String, dynamic>?> createSurveyBooking({
    required String token,
    required String date,
    required String time,
  }) async {
    final Map<String, String> body = {
      // WAJIB SESUAI BACKEND
      // Error backend: "The place properties id field is required."
      // Jadi nama field yang benar adalah place_properties_id
      'place_properties_id': propertyId.toString(),

      // Tetap dikirim untuk jaga-jaga jika endpoint lain membaca nama field ini
      'property_id': propertyId.toString(),
      'place_property_id': propertyId.toString(),

      // Tipe booking survey
      'booking_type': 'survey',
      'type': 'survey',
      'category': 'survey',
      'status': 'pending',

      // Jadwal survey
      'date': date,
      'time': time,

      'booking_date': date,
      'booking_time': time,

      'survey_date': date,
      'survey_time': time,

      'visit_date': date,
      'visit_time': time,

      'scheduled_date': date,
      'scheduled_time': time,
    };

    if (ownerId != null && ownerId! > 0) {
      body['owner_id'] = ownerId.toString();
    }

    debugPrint("CREATE SURVEY BOOKING BODY:");
    debugPrint(body.toString());

    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/bookings"),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      body: body,
    );

    debugPrint("CREATE SURVEY BOOKING STATUS:");
    debugPrint(response.statusCode.toString());

    debugPrint("CREATE SURVEY BOOKING RESPONSE:");
    debugPrint(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return parseResponseData(response.body);
    }

    final message = parseResponseMessage(
      response.body,
      "Gagal mengajukan survey",
    );

    throw Exception(message);
  }

  Future<void> sendSurveyCardToChat({
    required String token,
    required int conversationId,
    required int bookingId,
    required String date,
    required String time,
  }) async {
    final payload = {
      'card_type': 'survey_booking',
      'booking_id': bookingId,

      // Tambahan penting
      'place_properties_id': propertyId,

      'property_id': propertyId,
      'owner_id': ownerId,
      'title': title,
      'address': address,
      'image_url': getImageUrl(),
      'survey_date': date,
      'survey_time': time,
      'status': 'pending',
      'created_by': 'resident',

      'owner_actions': ['accept', 'reject', 'reschedule'],

      'resident_actions': ['cancel'],

      'reschedule_owner_actions': ['cancel'],

      'reschedule_resident_actions': ['approve', 'reject'],
    };

    final encodedPayload = jsonEncode(payload);
    final messageText = "KOSKAKI_SURVEY_BOOKING_CARD::$encodedPayload";

    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/conversations/$conversationId/messages"),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      body: {
        'message': messageText,
        'content': messageText,
        'body': messageText,
        'type': 'survey_booking_card',
        'payload': encodedPayload,
      },
    );

    debugPrint("SEND SURVEY CARD STATUS:");
    debugPrint(response.statusCode.toString());

    debugPrint("SEND SURVEY CARD RESPONSE:");
    debugPrint(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final message = parseResponseMessage(
        response.body,
        "Survey dibuat, tapi gagal mengirim card ke chat",
      );

      throw Exception(message);
    }
  }

  Future<void> submitSurvey() async {
    if (!validateForm()) return;

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

      final String date = formatDate(selectedDate!);
      final String time = formatTime(selectedTime!);

      final bookingData = await createSurveyBooking(
        token: token,
        date: date,
        time: time,
      );

      final bookingId = int.tryParse(
        bookingData?['id']?.toString() ??
            bookingData?['booking_id']?.toString() ??
            "",
      );

      if (bookingId == null || bookingId <= 0) {
        throw Exception(
          "Booking berhasil dibuat, tapi ID booking tidak ditemukan",
        );
      }

      final conversationId = await ApiService().createOrGetConversationId(
        ownerId: ownerId!,
        placePropertyId: propertyId!,
      );

      if (conversationId == null || conversationId <= 0) {
        throw Exception("Booking dibuat, tapi conversation gagal dibuat");
      }

      await sendSurveyCardToChat(
        token: token,
        conversationId: conversationId,
        bookingId: bookingId,
        date: date,
        time: time,
      );

      if (!mounted) return;

      showMessage(
        "Survey berhasil diajukan dan dikirim ke chat",
        success: true,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Livechatowner(
            username: ownerName,
            conversationId: conversationId,
          ),
        ),
      );
    } catch (e) {
      debugPrint("SUBMIT SURVEY ERROR:");
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
          colors: [primaryColor, const Color(0xFF17206F)],
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
                    "Survey Kost",
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

  Widget dateTimeButton({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
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
              child: Icon(icon, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
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

  Widget infoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: primaryColor, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Setelah survey diajukan, pemilik kos akan menerima card survey di chat. Pemilik bisa menerima, menolak, atau mengajukan reschedule.",
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.45,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
            onPressed: isLoading ? null : submitSurvey,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              isLoading ? "Mengirim..." : "Ajukan Survey",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = formatDateReadable(selectedDate);
    final timeText = formatTimeReadable(selectedTime);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Ajukan Survey",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
      ),
      bottomNavigationBar: submitButton(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          child: Column(
            children: [
              buildHeader(),
              sectionCard(
                title: "Jadwal Survey",
                icon: Icons.event_available_rounded,
                children: [
                  dateTimeButton(
                    title: "Tanggal Survey",
                    value: dateText,
                    icon: Icons.calendar_month_rounded,
                    onTap: pickSurveyDate,
                  ),
                  const SizedBox(height: 12),
                  dateTimeButton(
                    title: "Jam Survey",
                    value: timeText,
                    icon: Icons.access_time_rounded,
                    onTap: pickSurveyTime,
                  ),
                ],
              ),
              sectionCard(
                title: "Ringkasan",
                icon: Icons.fact_check_outlined,
                children: [
                  summaryItem(
                    icon: Icons.home_work_outlined,
                    title: "Kos",
                    value: title,
                  ),
                  summaryItem(
                    icon: Icons.person_outline_rounded,
                    title: "Pemilik",
                    value: ownerName,
                  ),
                  summaryItem(
                    icon: Icons.calendar_today_rounded,
                    title: "Tanggal",
                    value: dateText,
                  ),
                  summaryItem(
                    icon: Icons.schedule_rounded,
                    title: "Jam",
                    value: timeText,
                  ),
                  infoBox(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
