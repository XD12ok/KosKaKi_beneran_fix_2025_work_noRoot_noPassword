import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:koskaki/screens/Owner/LiveChatOwner.dart';
import 'package:koskaki/service/api_service.dart';

class Payment extends StatefulWidget {
  final Map<String, dynamic>? rentalBooking;
  final int? rentalBookingId;

  const Payment({super.key, this.rentalBooking, this.rentalBookingId});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color softGreen = const Color(0xFFEAF5EB);
  final Color backgroundColor = const Color(0xFFF6F8FA);

  static const String rentalPaymentPrefix = "KOSKAKI_RENTAL_PAYMENT_CARD::";

  final ImagePicker picker = ImagePicker();

  bool hasReadArguments = false;
  bool isLoading = false;

  File? proofFile;

  Map<String, dynamic> rentalBooking = {};
  Map<String, dynamic> kos = {};

  int? rentalBookingId;
  int? propertyId;
  int? ownerId;

  String title = "Kos";
  String address = "";
  String ownerName = "Pemilik Kos";

  String rentalType = "";
  String rentalTitle = "Sewa";
  String durationLabel = "periode";

  int duration = 1;
  int unitPrice = 0;
  int totalPrice = 0;

  String startDate = "";
  String endDate = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (hasReadArguments) return;

    hasReadArguments = true;
    readArguments();
  }

  void readArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      final rentalBookingArg = args['rental_booking'];

      if (rentalBookingArg is Map<String, dynamic>) {
        rentalBooking = Map<String, dynamic>.from(rentalBookingArg);
      } else if (rentalBookingArg is Map) {
        rentalBooking = Map<String, dynamic>.from(rentalBookingArg);
      }

      final kosArg = args['kos'];

      if (kosArg is Map<String, dynamic>) {
        kos = Map<String, dynamic>.from(kosArg);
      } else if (kosArg is Map) {
        kos = Map<String, dynamic>.from(kosArg);
      }

      rentalBookingId = toInt(
        args['rental_booking_id'] ??
            args['booking_id'] ??
            rentalBooking['id'] ??
            rentalBooking['rental_booking_id'],
      );

      propertyId = toInt(
        args['place_properties_id'] ??
            args['place_property_id'] ??
            args['property_id'] ??
            rentalBooking['place_properties_id'] ??
            rentalBooking['place_property_id'] ??
            rentalBooking['property_id'] ??
            kos['id'],
      );

      ownerId = toInt(
        args['owner_id'] ?? rentalBooking['owner_id'] ?? kos['owner_id'],
      );

      final owner = args['owner'] ?? rentalBooking['owner'] ?? kos['owner'];

      if (owner is Map) {
        ownerId ??= toInt(owner['id']);
        ownerName = owner['name']?.toString() ?? ownerName;
      }

      title =
          args['title']?.toString() ??
          rentalBooking['title']?.toString() ??
          kos['title']?.toString() ??
          kos['name']?.toString() ??
          "Kos";

      address =
          args['address']?.toString() ??
          rentalBooking['address']?.toString() ??
          kos['address']?.toString() ??
          "";

      ownerName =
          args['owner_name']?.toString() ??
          rentalBooking['owner_name']?.toString() ??
          ownerName;

      rentalType =
          args['rental_type']?.toString() ??
          rentalBooking['rental_type']?.toString() ??
          rentalBooking['rent_type']?.toString() ??
          rentalBooking['type']?.toString() ??
          "";

      rentalTitle =
          args['rental_title']?.toString() ?? getRentalTitle(rentalType);

      duration = toInt(args['duration'] ?? rentalBooking['duration']) ?? 1;

      durationLabel =
          args['duration_label']?.toString() ?? getDurationLabel(rentalType);

      startDate =
          args['start_date']?.toString() ??
          rentalBooking['start_date']?.toString() ??
          rentalBooking['check_in']?.toString() ??
          "";

      endDate =
          args['end_date']?.toString() ??
          rentalBooking['end_date']?.toString() ??
          rentalBooking['check_out']?.toString() ??
          "";

      unitPrice =
          toInt(
            args['unit_price'] ??
                rentalBooking['unit_price'] ??
                rentalBooking['price'],
          ) ??
          0;

      totalPrice =
          toInt(
            args['total_price'] ??
                args['amount'] ??
                rentalBooking['total_price'] ??
                rentalBooking['amount'] ??
                rentalBooking['grand_total'],
          ) ??
          0;
    }

    if (widget.rentalBooking != null) {
      rentalBooking = Map<String, dynamic>.from(widget.rentalBooking!);
    }

    rentalBookingId ??= widget.rentalBookingId;
    rentalBookingId ??= toInt(
      rentalBooking['id'] ?? rentalBooking['rental_booking_id'],
    );

    if (title.trim().isEmpty) {
      title = "Kos";
    }

    if (duration <= 0) {
      duration = 1;
    }
  }

  int? toInt(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return null;

    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return null;

    return int.tryParse(cleaned);
  }

  String getRentalTitle(String type) {
    final clean = type.toLowerCase().trim();

    if (clean == "night" || clean == "daily" || clean == "day") {
      return "Harian";
    }

    if (clean == "week" || clean == "weekly") {
      return "Mingguan";
    }

    if (clean == "month" || clean == "monthly") {
      return "Bulanan";
    }

    if (clean == "year" || clean == "yearly") {
      return "Tahunan";
    }

    return "Sewa";
  }

  String getDurationLabel(String type) {
    final clean = type.toLowerCase().trim();

    if (clean == "night" || clean == "daily" || clean == "day") {
      return "malam";
    }

    if (clean == "week" || clean == "weekly") {
      return "minggu";
    }

    if (clean == "month" || clean == "monthly") {
      return "bulan";
    }

    if (clean == "year" || clean == "yearly") {
      return "tahun";
    }

    return "periode";
  }

  String readableDate(String raw) {
    if (raw.trim().isEmpty || raw == "null") return "-";

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) return raw;

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

    return "${parsed.day} ${months[parsed.month - 1]} ${parsed.year}";
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
    final mainImage = kos['main_image'] ?? rentalBooking['main_image'];

    if (mainImage != null && mainImage.toString() != "null") {
      final fixed = fixUrl(mainImage);

      if (fixed.isNotEmpty) return fixed;
    }

    final images = kos['images'] ?? rentalBooking['images'];

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

  Future<void> pickImageFromGallery() async {
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );

    if (result == null) return;

    setState(() {
      proofFile = File(result.path);
    });
  }

  Future<void> pickImageFromCamera() async {
    final result = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );

    if (result == null) return;

    setState(() {
      proofFile = File(result.path);
    });
  }

  void showPickImageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(18),
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
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  "Pilih Bukti Pembayaran",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                imageSourceButton(
                  icon: Icons.photo_library_rounded,
                  title: "Ambil dari Galeri",
                  subtitle: "Pilih foto bukti transfer dari galeri",
                  onTap: () {
                    Navigator.pop(context);
                    pickImageFromGallery();
                  },
                ),
                const SizedBox(height: 12),
                imageSourceButton(
                  icon: Icons.camera_alt_rounded,
                  title: "Ambil dari Kamera",
                  subtitle: "Foto bukti pembayaran secara langsung",
                  onTap: () {
                    Navigator.pop(context);
                    pickImageFromCamera();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget imageSourceButton({
    required IconData icon,
    required String title,
    required String subtitle,
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  bool validatePayment() {
    if (rentalBookingId == null || rentalBookingId! <= 0) {
      showMessage("ID rental booking tidak ditemukan");
      return false;
    }

    if (proofFile == null) {
      showMessage("Upload bukti pembayaran terlebih dahulu");
      return false;
    }

    return true;
  }

  Map<String, dynamic> parseResponseData(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];

        if (data is Map<String, dynamic>) return data;

        if (data is Map) return Map<String, dynamic>.from(data);

        return decoded;
      }

      if (decoded is Map) return Map<String, dynamic>.from(decoded);

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

  int parsePaymentId(Map<String, dynamic> data) {
    final payment = data['payment'];
    final rentalPayment = data['rental_payment'];

    if (payment is Map) {
      final id = toInt(
        payment['id'] ?? payment['payment_id'] ?? payment['rental_payment_id'],
      );

      if (id != null && id > 0) return id;
    }

    if (rentalPayment is Map) {
      final id = toInt(
        rentalPayment['id'] ??
            rentalPayment['payment_id'] ??
            rentalPayment['rental_payment_id'],
      );

      if (id != null && id > 0) return id;
    }

    return toInt(
          data['id'] ??
              data['payment_id'] ??
              data['rental_payment_id'] ??
              data['rentalPaymentId'],
        ) ??
        0;
  }

  String parseProofUrl(Map<String, dynamic> data) {
    final payment = data['payment'];
    final rentalPayment = data['rental_payment'];

    if (payment is Map) {
      final proof =
          payment['proof_url'] ??
          payment['payment_proof_url'] ??
          payment['proof_image_url'] ??
          payment['image_url'] ??
          payment['full_image_url'] ??
          payment['proof'] ??
          payment['payment_proof'] ??
          payment['image'];

      final fixed = fixUrl(proof);

      if (fixed.isNotEmpty) return fixed;
    }

    if (rentalPayment is Map) {
      final proof =
          rentalPayment['proof_url'] ??
          rentalPayment['payment_proof_url'] ??
          rentalPayment['proof_image_url'] ??
          rentalPayment['image_url'] ??
          rentalPayment['full_image_url'] ??
          rentalPayment['proof'] ??
          rentalPayment['payment_proof'] ??
          rentalPayment['image'];

      final fixed = fixUrl(proof);

      if (fixed.isNotEmpty) return fixed;
    }

    final proof =
        data['proof_url'] ??
        data['payment_proof_url'] ??
        data['proof_image_url'] ??
        data['image_url'] ??
        data['full_image_url'] ??
        data['proof'] ??
        data['payment_proof'] ??
        data['image'];

    return fixUrl(proof);
  }

  Future<Map<String, dynamic>> uploadPaymentProof() async {
    final token = await ApiService().getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan, silakan login ulang");
    }

    if (rentalBookingId == null || rentalBookingId! <= 0) {
      throw Exception("ID rental booking tidak ditemukan");
    }

    if (proofFile == null) {
      throw Exception("Bukti pembayaran belum dipilih");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse(
        "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/upload-payment",
      ),
    );

    request.headers.addAll({
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    request.fields.addAll({
      // WAJIB SESUAI BACKEND
      "claimed_amount": totalPrice.toString(),

      // Opsional sesuai controller
      "sender_name": "",
      "payment_method": "transfer",
      "notes": "",

      // Cadangan, tidak masalah kalau backend mengabaikan
      "amount": totalPrice.toString(),
      "total_price": totalPrice.toString(),
      "payment_amount": totalPrice.toString(),
    });

    request.files.add(
      await http.MultipartFile.fromPath(
        // WAJIB SESUAI BACKEND
        "payment_proof",
        proofFile!.path,
      ),
    );

    debugPrint("UPLOAD PAYMENT URL:");
    debugPrint(
      "${ApiService.baseUrl}/rental-bookings/$rentalBookingId/upload-payment",
    );

    debugPrint("UPLOAD PAYMENT FIELDS:");
    debugPrint(request.fields.toString());

    debugPrint("UPLOAD PAYMENT FILE FIELD:");
    debugPrint("payment_proof");

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("UPLOAD PAYMENT STATUS:");
    debugPrint(response.statusCode.toString());

    debugPrint("UPLOAD PAYMENT RESPONSE:");
    debugPrint(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return parseResponseData(response.body);
    }

    throw Exception(
      parseResponseMessage(response.body, "Gagal mengupload bukti pembayaran"),
    );
  }

  Future<void> sendPaymentCardToChat({
    required int rentalPaymentId,
    required String proofUrl,
  }) async {
    if (ownerId == null || ownerId! <= 0) {
      throw Exception(
        "ID owner tidak ditemukan untuk mengirim notifikasi chat",
      );
    }

    if (propertyId == null || propertyId! <= 0) {
      throw Exception("ID kos tidak ditemukan untuk mengirim notifikasi chat");
    }

    final conversationId = await ApiService().createOrGetConversationId(
      ownerId: ownerId!,
      placePropertyId: propertyId!,
    );

    if (conversationId == null || conversationId <= 0) {
      throw Exception("Gagal membuat conversation untuk notifikasi owner");
    }

    final payload = {
      "card_type": "rental_payment",
      "rental_booking_id": rentalBookingId,
      "rental_payment_id": rentalPaymentId,
      "place_properties_id": propertyId,
      "property_id": propertyId,
      "owner_id": ownerId,
      "title": title,
      "address": address,
      "image_url": getImageUrl(),
      "proof_url": proofUrl,
      "rental_type": rentalType,
      "rental_title": rentalTitle,
      "duration": duration,
      "duration_label": durationLabel,
      "start_date": startDate,
      "end_date": endDate,
      "unit_price": unitPrice,
      "total_price": totalPrice,
      "status": "pending",
      "payment_status": "pending",
      "created_by": "resident",
      "owner_actions": ["approve", "reject"],
    };

    final message = "$rentalPaymentPrefix${jsonEncode(payload)}";

    final result = await ApiService().sendConversationMessage(
      conversationId: conversationId,
      message: message,
    );

    if (result == null) {
      throw Exception(
        "Pembayaran terupload, tapi gagal mengirim notifikasi chat",
      );
    }

    if (!mounted) return;

    showMessage("Bukti pembayaran terkirim ke pemilik", success: true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Livechatowner(username: ownerName, conversationId: conversationId),
      ),
    );
  }

  Future<void> submitPayment() async {
    if (!validatePayment()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final paymentData = await uploadPaymentProof();

      final rentalPaymentId = parsePaymentId(paymentData);
      final proofUrl = parseProofUrl(paymentData);

      if (rentalPaymentId <= 0) {
        throw Exception(
          "Bukti pembayaran berhasil dikirim, tapi ID payment tidak ditemukan",
        );
      }

      await sendPaymentCardToChat(
        rentalPaymentId: rentalPaymentId,
        proofUrl: proofUrl,
      );
    } catch (e) {
      debugPrint("SUBMIT PAYMENT ERROR:");
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
                    "Payment",
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

  Widget paymentInfoBox() {
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
              "Upload bukti pembayaran yang jelas. Setelah dikirim, pemilik kos akan menerima pemberitahuan dan bisa menerima atau menolak pembayaran.",
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

  Widget proofUploadBox() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: showPickImageSheet,
      child: Container(
        width: double.infinity,
        height: proofFile == null ? 190 : 260,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: proofFile == null
                ? Colors.grey.shade300
                : primaryColor.withOpacity(0.25),
            width: 1.3,
          ),
        ),
        child: proofFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: softGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.upload_file_rounded,
                      color: primaryColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Upload Bukti Pembayaran",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Klik untuk memilih foto bukti transfer",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(proofFile!, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.02),
                              Colors.black.withOpacity(0.55),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Bukti pembayaran siap dikirim",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "Ganti",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            proofFile = null;
                          });
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            onPressed: isLoading ? null : submitPayment,
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
              isLoading ? "Mengirim..." : "Kirim Bukti Pembayaran",
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
    return Scaffold(
      backgroundColor: backgroundColor,
      bottomNavigationBar: submitButton(),
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Payment",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 115),
          child: Column(
            children: [
              buildHeader(),
              sectionCard(
                title: "Ringkasan Sewa",
                icon: Icons.fact_check_outlined,
                children: [
                  summaryItem(
                    icon: Icons.home_work_outlined,
                    title: "Kos",
                    value: title,
                  ),
                  summaryItem(
                    icon: Icons.sell_outlined,
                    title: "Jenis Sewa",
                    value: rentalTitle,
                  ),
                  summaryItem(
                    icon: Icons.timelapse_rounded,
                    title: "Durasi",
                    value: "$duration $durationLabel",
                  ),
                  summaryItem(
                    icon: Icons.calendar_today_rounded,
                    title: "Tanggal Mulai",
                    value: readableDate(startDate),
                  ),
                  summaryItem(
                    icon: Icons.event_available_rounded,
                    title: "Tanggal Selesai",
                    value: readableDate(endDate),
                  ),
                  const SizedBox(height: 6),
                  totalBox(),
                ],
              ),
              sectionCard(
                title: "Upload Bukti",
                icon: Icons.upload_file_rounded,
                children: [
                  proofUploadBox(),
                  const SizedBox(height: 14),
                  paymentInfoBox(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
