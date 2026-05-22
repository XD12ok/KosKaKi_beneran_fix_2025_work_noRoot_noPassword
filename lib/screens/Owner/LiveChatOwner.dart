import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';

class Livechatowner extends StatefulWidget {
  final int conversationId;
  final String username;

  const Livechatowner({
    super.key,
    required this.conversationId,
    required this.username,
  });

  @override
  State<Livechatowner> createState() => _LivechatownerState();
}

class _LivechatownerState extends State<Livechatowner> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color backgroundColor = const Color(0xFFF6F8FA);
  final Color softGreen = const Color(0xFFEAF5EB);

  static const String surveyBookingPrefix = "KOSKAKI_SURVEY_BOOKING_CARD::";
  static const String surveyReschedulePrefix =
      "KOSKAKI_SURVEY_RESCHEDULE_CARD::";

  List<dynamic> messages = [];

  bool isLoading = true;
  bool isSending = false;

  int? currentUserId;
  String currentUserRole = "";

  final Set<String> loadingActions = {};

  @override
  void initState() {
    super.initState();
    prepareChat();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  bool get isOwnerAccount {
    final role = currentUserRole.toLowerCase();

    return role.contains("owner") ||
        role.contains("pemilik") ||
        role == "owners";
  }

  bool get isResidentAccount {
    final role = currentUserRole.toLowerCase();

    return role.contains("resident") ||
        role.contains("user") ||
        role.contains("penyewa") ||
        role == "residents";
  }

  Future<void> prepareChat() async {
    await loadCurrentUser();
    await loadMessages();
  }

  Future<void> loadCurrentUser() async {
    try {
      final user = await ApiService().getUser();

      if (!mounted) return;

      setState(() {
        currentUserId = int.tryParse(user?['id']?.toString() ?? '');
        currentUserRole = user?['role']?.toString().toLowerCase() ?? "";
      });
    } catch (e) {
      debugPrint("LOAD CURRENT USER ERROR: $e");
    }
  }

  List<dynamic> sortMessagesOldToNew(List<dynamic> source) {
    final sorted = List<dynamic>.from(source);

    sorted.sort((a, b) {
      final dateA = getMessageDate(a);
      final dateB = getMessageDate(b);

      if (dateA != null && dateB != null) {
        return dateA.compareTo(dateB);
      }

      final idA = a is Map ? int.tryParse(a['id']?.toString() ?? '') ?? 0 : 0;
      final idB = b is Map ? int.tryParse(b['id']?.toString() ?? '') ?? 0 : 0;

      return idA.compareTo(idB);
    });

    return sorted;
  }

  Future<void> loadMessages() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final result = await ApiService().getConversationMessages(
        widget.conversationId,
      );

      if (!mounted) return;

      setState(() {
        messages = sortMessagesOldToNew(result);
        isLoading = false;
      });

      scrollToBottom();
    } catch (e) {
      debugPrint("LOAD MESSAGES ERROR: $e");

      if (!mounted) return;

      setState(() {
        messages = [];
        isLoading = false;
      });

      showSnack("Gagal memuat pesan");
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty || isSending) return;

    final tempMessage = {
      "id": DateTime.now().millisecondsSinceEpoch,
      "message": text,
      "is_me": true,
      "created_at": DateTime.now().toIso8601String(),
      "sending": true,
    };

    setState(() {
      isSending = true;
      messages = sortMessagesOldToNew([...messages, tempMessage]);
      messageController.clear();
    });

    scrollToBottom();

    try {
      final result = await ApiService().sendConversationMessage(
        conversationId: widget.conversationId,
        message: text,
      );

      if (result != null) {
        await loadMessages();
      } else {
        setState(() {
          messages.remove(tempMessage);
        });

        showSnack("Gagal mengirim pesan");
      }
    } catch (e) {
      debugPrint("SEND MESSAGE ERROR: $e");

      setState(() {
        messages.remove(tempMessage);
      });

      showSnack("Terjadi kesalahan saat mengirim pesan");
    } finally {
      if (!mounted) return;

      setState(() {
        isSending = false;
      });
    }
  }

  Future<void> sendSpecialCardMessage(String message) async {
    final result = await ApiService().sendConversationMessage(
      conversationId: widget.conversationId,
      message: message,
    );

    if (result == null) {
      throw Exception("Gagal mengirim update ke chat");
    }
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void showSnack(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? Colors.green : primaryColor,
      ),
    );
  }

  String getMessageText(dynamic message) {
    if (message is! Map) return "";

    return message['message']?.toString() ??
        message['body']?.toString() ??
        message['text']?.toString() ??
        message['content']?.toString() ??
        "";
  }

  DateTime? getMessageDate(dynamic message) {
    if (message is! Map) return null;

    final rawTime =
        message['created_at']?.toString() ??
        message['time']?.toString() ??
        message['updated_at']?.toString() ??
        "";

    if (rawTime.isEmpty) return null;

    final parsed = DateTime.tryParse(rawTime);

    if (parsed == null) return null;

    return parsed.toLocal();
  }

  String getMessageTime(dynamic message) {
    final local = getMessageDate(message);

    if (local == null) {
      if (message is! Map) return "";

      return message['created_at']?.toString() ??
          message['time']?.toString() ??
          message['updated_at']?.toString() ??
          "";
    }

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return "$hour:$minute";
  }

  bool isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String getDateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return "Hari ini";
    }

    if (difference == 1) {
      return "Kemarin";
    }

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

  bool isMyMessage(dynamic message) {
    if (message is! Map) return false;

    if (message['is_me'] != null) {
      return message['is_me'] == true;
    }

    final senderId =
        message['sender_id'] ??
        message['user_id'] ??
        message['from_user_id'] ??
        message['sender']?['id'] ??
        message['user']?['id'];

    if (currentUserId != null && senderId != null) {
      return senderId.toString() == currentUserId.toString();
    }

    final senderType = message['sender_type']?.toString().toLowerCase() ?? "";

    if (senderType == "resident" || senderType == "user") {
      return isResidentAccount;
    }

    if (senderType == "owner" || senderType == "owners") {
      return isOwnerAccount;
    }

    final from = message['from']?.toString().toLowerCase() ?? "";

    if (from == "me") {
      return true;
    }

    return false;
  }

  bool isSendingMessage(dynamic message) {
    if (message is! Map) return false;

    return message['sending'] == true;
  }

  Map<String, dynamic>? decodePayloadFromText(String text, String prefix) {
    if (!text.startsWith(prefix)) return null;

    final raw = text.replaceFirst(prefix, "");

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (e) {
      debugPrint("DECODE PAYLOAD ERROR: $e");
      return null;
    }
  }

  Map<String, dynamic>? getPayloadFromMessage(
    dynamic message,
    String prefix,
    String expectedCardType,
  ) {
    if (message is! Map) return null;

    final text = getMessageText(message).trim();

    final fromText = decodePayloadFromText(text, prefix);

    if (fromText != null) {
      return fromText;
    }

    final payload = message['payload'];

    if (payload is Map<String, dynamic>) {
      if (payload['card_type']?.toString() == expectedCardType) {
        return payload;
      }
    }

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);

      if (map['card_type']?.toString() == expectedCardType) {
        return map;
      }
    }

    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);

        if (decoded is Map<String, dynamic> &&
            decoded['card_type']?.toString() == expectedCardType) {
          return decoded;
        }

        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);

          if (map['card_type']?.toString() == expectedCardType) {
            return map;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Map<String, dynamic>? getSurveyBookingPayload(dynamic message) {
    return getPayloadFromMessage(
      message,
      surveyBookingPrefix,
      "survey_booking",
    );
  }

  Map<String, dynamic>? getSurveyReschedulePayload(dynamic message) {
    return getPayloadFromMessage(
      message,
      surveyReschedulePrefix,
      "survey_reschedule",
    );
  }

  String getEffectiveBookingStatus(int bookingId, String fallback) {
    String status = fallback.trim().isEmpty ? "pending" : fallback;

    for (final message in messages) {
      final bookingPayload = getSurveyBookingPayload(message);

      if (bookingPayload != null) {
        final currentBookingId = int.tryParse(
          bookingPayload['booking_id']?.toString() ?? "",
        );

        if (currentBookingId == bookingId) {
          final nextStatus =
              bookingPayload['status']?.toString() ??
              bookingPayload['booking_status']?.toString() ??
              "";

          if (nextStatus.trim().isNotEmpty) {
            status = nextStatus;
          }
        }
      }

      final reschedulePayload = getSurveyReschedulePayload(message);

      if (reschedulePayload != null) {
        final currentBookingId = int.tryParse(
          reschedulePayload['booking_id']?.toString() ?? "",
        );

        if (currentBookingId == bookingId) {
          final rescheduleStatus =
              reschedulePayload['status']?.toString().toLowerCase() ??
              "pending";

          if (rescheduleStatus == "pending") {
            status = "reschedule_requested";
          } else if (rescheduleStatus == "approved" ||
              rescheduleStatus == "accepted") {
            status = "reschedule_approved";
          } else if (rescheduleStatus == "rejected") {
            status = "reschedule_rejected";
          } else if (rescheduleStatus == "cancelled" ||
              rescheduleStatus == "canceled") {
            status = "reschedule_cancelled";
          }
        }
      }
    }

    return status;
  }

  String getEffectiveRescheduleStatus(int rescheduleId, String fallback) {
    String status = fallback.trim().isEmpty ? "pending" : fallback;

    for (final message in messages) {
      final payload = getSurveyReschedulePayload(message);

      if (payload == null) continue;

      final currentId = int.tryParse(
        payload['reschedule_id']?.toString() ?? "",
      );

      if (currentId == rescheduleId) {
        final nextStatus = payload['status']?.toString() ?? "";

        if (nextStatus.trim().isNotEmpty) {
          status = nextStatus;
        }
      }
    }

    return status;
  }

  String normalizeStatus(String value) {
    return value.toLowerCase().trim();
  }

  bool isBookingPending(String status) {
    final normalized = normalizeStatus(status);

    return normalized == "pending" ||
        normalized == "requested" ||
        normalized == "waiting";
  }

  String statusLabel(String status) {
    final normalized = normalizeStatus(status);

    if (normalized == "pending" ||
        normalized == "requested" ||
        normalized == "waiting") {
      return "Menunggu";
    }

    if (normalized == "accepted" || normalized == "approved") {
      return "Diterima";
    }

    if (normalized == "rejected") {
      return "Ditolak";
    }

    if (normalized == "cancelled" || normalized == "canceled") {
      return "Dibatalkan";
    }

    if (normalized == "reschedule_requested") {
      return "Reschedule Diajukan";
    }

    if (normalized == "reschedule_approved") {
      return "Reschedule Diterima";
    }

    if (normalized == "reschedule_rejected") {
      return "Reschedule Ditolak";
    }

    if (normalized == "reschedule_cancelled") {
      return "Reschedule Dibatalkan";
    }

    if (normalized == "completed" || normalized == "complete") {
      return "Selesai";
    }

    return status.isEmpty ? "Menunggu" : status;
  }

  Color statusColor(String status) {
    final normalized = normalizeStatus(status);

    if (normalized == "accepted" ||
        normalized == "approved" ||
        normalized == "reschedule_approved" ||
        normalized == "completed" ||
        normalized == "complete") {
      return Colors.green;
    }

    if (normalized == "rejected" ||
        normalized == "reschedule_rejected" ||
        normalized == "cancelled" ||
        normalized == "canceled" ||
        normalized == "reschedule_cancelled") {
      return Colors.red;
    }

    if (normalized == "reschedule_requested") {
      return Colors.deepPurple;
    }

    return Colors.orange;
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

  String readableDate(String raw) {
    if (raw.trim().isEmpty) return "-";

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

  String readableTime(String raw) {
    if (raw.trim().isEmpty) return "-";

    if (raw.contains(":")) {
      final split = raw.split(":");

      if (split.length >= 2) {
        return "${split[0].padLeft(2, '0')}:${split[1].padLeft(2, '0')} WIB";
      }
    }

    return "$raw WIB";
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

  void setActionLoading(String key, bool value) {
    if (!mounted) return;

    setState(() {
      if (value) {
        loadingActions.add(key);
      } else {
        loadingActions.remove(key);
      }
    });
  }

  bool isActionLoading(String key) {
    return loadingActions.contains(key);
  }

  Future<void> postBookingAction({
    required int bookingId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final key = "booking-$bookingId-$action";

    if (isActionLoading(key)) return;

    setActionLoading(key, true);

    try {
      final token = await ApiService().getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan, silakan login ulang");
      }

      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/bookings/$bookingId/$action"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("BOOKING ACTION STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("BOOKING ACTION RESPONSE:");
      debugPrint(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          parseResponseMessage(response.body, "Gagal memproses booking"),
        );
      }

      String newStatus = "pending";
      String successText = "Booking berhasil diproses";

      if (action == "accept") {
        newStatus = "accepted";
        successText = "Survey berhasil diterima";
      } else if (action == "reject") {
        newStatus = "rejected";
        successText = "Survey berhasil ditolak";
      } else if (action == "cancel") {
        newStatus = "cancelled";
        successText = "Survey berhasil dibatalkan";
      }

      await sendSurveyBookingUpdateCard(oldPayload: payload, status: newStatus);

      await loadMessages();

      showSnack(successText, success: true);
    } catch (e) {
      debugPrint("POST BOOKING ACTION ERROR:");
      debugPrint(e.toString());

      String message = e.toString();

      if (message.startsWith("Exception: ")) {
        message = message.replaceFirst("Exception: ", "");
      }

      showSnack(message);
    } finally {
      setActionLoading(key, false);
    }
  }

  Future<void> sendSurveyBookingUpdateCard({
    required Map<String, dynamic> oldPayload,
    required String status,
  }) async {
    final payload = Map<String, dynamic>.from(oldPayload);

    payload['card_type'] = 'survey_booking';
    payload['status'] = status;
    payload['updated_by'] = isOwnerAccount ? 'owner' : 'resident';
    payload['updated_at'] = DateTime.now().toIso8601String();

    final message = "$surveyBookingPrefix${jsonEncode(payload)}";

    await sendSpecialCardMessage(message);
  }

  Future<void> openRescheduleSheet(Map<String, dynamic> bookingPayload) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final now = DateTime.now();

              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now.add(const Duration(days: 1)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 90)),
                helpText: "Pilih Tanggal Reschedule",
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

              if (date == null) return;

              setModalState(() {
                selectedDate = date;
              });
            }

            Future<void> pickTime() async {
              final time = await showTimePicker(
                context: context,
                initialTime:
                    selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
                helpText: "Pilih Jam Reschedule",
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

              if (time == null) return;

              setModalState(() {
                selectedTime = time;
              });
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 26,
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
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_repeat_rounded,
                        color: primaryColor,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Reschedule Survey",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Pilih jadwal baru. Jadwal ini akan dikirim ke user dan user bisa menerima atau menolak.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    modalPickerButton(
                      title: "Tanggal Baru",
                      value: selectedDate == null
                          ? "Pilih tanggal"
                          : readableDate(formatDate(selectedDate!)),
                      icon: Icons.calendar_month_rounded,
                      onTap: pickDate,
                    ),
                    const SizedBox(height: 12),
                    modalPickerButton(
                      title: "Jam Baru",
                      value: selectedTime == null
                          ? "Pilih jam"
                          : readableTime(formatTime(selectedTime!)),
                      icon: Icons.access_time_rounded,
                      onTap: pickTime,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(
                                  color: primaryColor.withOpacity(0.25),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                              },
                              child: const Text(
                                "Batal",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              onPressed: () {
                                if (selectedDate == null) {
                                  showSnack("Pilih tanggal reschedule");
                                  return;
                                }

                                if (selectedTime == null) {
                                  showSnack("Pilih jam reschedule");
                                  return;
                                }

                                Navigator.pop(sheetContext, {
                                  'date': formatDate(selectedDate!),
                                  'time': formatTime(selectedTime!),
                                });
                              },
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text(
                                "Kirim Reschedule",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final bookingId = int.tryParse(bookingPayload['booking_id'].toString());

    if (bookingId == null || bookingId <= 0) {
      showSnack("ID booking tidak ditemukan");
      return;
    }

    await submitReschedule(
      bookingPayload: bookingPayload,
      bookingId: bookingId,
      newDate: result['date'].toString(),
      newTime: result['time'].toString(),
    );
  }

  Widget modalPickerButton({
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

  Future<void> submitReschedule({
    required Map<String, dynamic> bookingPayload,
    required int bookingId,
    required String newDate,
    required String newTime,
  }) async {
    final key = "booking-$bookingId-reschedule";

    if (isActionLoading(key)) return;

    setActionLoading(key, true);

    try {
      final token = await ApiService().getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan, silakan login ulang");
      }

      final body = {
        'booking_id': bookingId.toString(),
        'date': newDate,
        'time': newTime,
        'new_date': newDate,
        'new_time': newTime,
        'reschedule_date': newDate,
        'reschedule_time': newTime,
        'scheduled_date': newDate,
        'scheduled_time': newTime,
        'reason': 'Pemilik kos mengajukan perubahan jadwal survey',
      };

      debugPrint("CREATE RESCHEDULE BODY:");
      debugPrint(body.toString());

      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/booking-reschedules"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: body,
      );

      debugPrint("CREATE RESCHEDULE STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("CREATE RESCHEDULE RESPONSE:");
      debugPrint(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          parseResponseMessage(response.body, "Gagal mengajukan reschedule"),
        );
      }

      final data = parseResponseData(response.body);

      final rescheduleId = int.tryParse(
        data['id']?.toString() ??
            data['reschedule_id']?.toString() ??
            data['booking_reschedule_id']?.toString() ??
            "",
      );

      if (rescheduleId == null || rescheduleId <= 0) {
        throw Exception(
          "Reschedule dibuat, tapi ID reschedule tidak ditemukan",
        );
      }

      await sendRescheduleCard(
        oldBookingPayload: bookingPayload,
        rescheduleId: rescheduleId,
        newDate: newDate,
        newTime: newTime,
        status: "pending",
      );

      await loadMessages();

      showSnack("Reschedule berhasil dikirim ke user", success: true);
    } catch (e) {
      debugPrint("SUBMIT RESCHEDULE ERROR:");
      debugPrint(e.toString());

      String message = e.toString();

      if (message.startsWith("Exception: ")) {
        message = message.replaceFirst("Exception: ", "");
      }

      showSnack(message);
    } finally {
      setActionLoading(key, false);
    }
  }

  Future<void> sendRescheduleCard({
    required Map<String, dynamic> oldBookingPayload,
    required int rescheduleId,
    required String newDate,
    required String newTime,
    required String status,
  }) async {
    final payload = {
      'card_type': 'survey_reschedule',
      'reschedule_id': rescheduleId,
      'booking_id': oldBookingPayload['booking_id'],
      'property_id': oldBookingPayload['property_id'],
      'owner_id': oldBookingPayload['owner_id'],
      'title': oldBookingPayload['title'],
      'address': oldBookingPayload['address'],
      'image_url': oldBookingPayload['image_url'],
      'old_survey_date': oldBookingPayload['survey_date'],
      'old_survey_time': oldBookingPayload['survey_time'],
      'new_survey_date': newDate,
      'new_survey_time': newTime,
      'status': status,
      'created_by': 'owner',
      'resident_actions': ['approve', 'reject'],
    };

    final message = "$surveyReschedulePrefix${jsonEncode(payload)}";

    await sendSpecialCardMessage(message);
  }

  Future<void> postRescheduleAction({
    required Map<String, dynamic> payload,
    required String action,
  }) async {
    final rescheduleId = int.tryParse(
      payload['reschedule_id']?.toString() ?? "",
    );

    if (rescheduleId == null || rescheduleId <= 0) {
      showSnack("ID reschedule tidak ditemukan");
      return;
    }

    final key = "reschedule-$rescheduleId-$action";

    if (isActionLoading(key)) return;

    setActionLoading(key, true);

    try {
      final token = await ApiService().getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan, silakan login ulang");
      }

      final response = await http.post(
        Uri.parse(
          "${ApiService.baseUrl}/booking-reschedules/$rescheduleId/$action",
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("RESCHEDULE ACTION STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("RESCHEDULE ACTION RESPONSE:");
      debugPrint(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          parseResponseMessage(response.body, "Gagal memproses reschedule"),
        );
      }

      final newStatus = action == "approve" ? "approved" : "rejected";

      await sendRescheduleUpdateCard(oldPayload: payload, status: newStatus);

      await loadMessages();

      showSnack(
        action == "approve"
            ? "Reschedule berhasil diterima"
            : "Reschedule berhasil ditolak",
        success: true,
      );
    } catch (e) {
      debugPrint("POST RESCHEDULE ACTION ERROR:");
      debugPrint(e.toString());

      String message = e.toString();

      if (message.startsWith("Exception: ")) {
        message = message.replaceFirst("Exception: ", "");
      }

      showSnack(message);
    } finally {
      setActionLoading(key, false);
    }
  }

  Future<void> sendRescheduleUpdateCard({
    required Map<String, dynamic> oldPayload,
    required String status,
  }) async {
    final payload = Map<String, dynamic>.from(oldPayload);

    payload['card_type'] = 'survey_reschedule';
    payload['status'] = status;
    payload['updated_by'] = isOwnerAccount ? 'owner' : 'resident';
    payload['updated_at'] = DateTime.now().toIso8601String();

    final message = "$surveyReschedulePrefix${jsonEncode(payload)}";

    await sendSpecialCardMessage(message);
  }

  Widget buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }

  Widget buildMessageItem(int index) {
    final currentMessage = messages[index];
    final currentDate = getMessageDate(currentMessage);

    bool showDateSeparator = false;

    if (currentDate != null) {
      if (index == 0) {
        showDateSeparator = true;
      } else {
        final previousMessage = messages[index - 1];
        final previousDate = getMessageDate(previousMessage);

        if (previousDate == null || !isSameDay(currentDate, previousDate)) {
          showDateSeparator = true;
        }
      }
    }

    return Column(
      children: [
        if (showDateSeparator && currentDate != null)
          buildDateSeparator(getDateLabel(currentDate)),
        buildMessageBubble(currentMessage),
      ],
    );
  }

  Widget buildMessageBubble(dynamic message) {
    final bookingPayload = getSurveyBookingPayload(message);

    if (bookingPayload != null) {
      return buildSurveyBookingCard(message, bookingPayload);
    }

    final reschedulePayload = getSurveyReschedulePayload(message);

    if (reschedulePayload != null) {
      return buildSurveyRescheduleCard(message, reschedulePayload);
    }

    final mine = isMyMessage(message);
    final sending = isSendingMessage(message);
    final text = getMessageText(message);
    final time = getMessageTime(message);

    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: mine ? 56 : 0,
          right: mine ? 0 : 56,
          bottom: 12,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: mine ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: mine ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sending)
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.7,
                      color: Colors.grey.shade500,
                    ),
                  ),
                if (sending) const SizedBox(width: 5),
                Text(
                  sending ? "Mengirim..." : time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSurveyBookingCard(dynamic message, Map<String, dynamic> payload) {
    final mine = isMyMessage(message);
    final time = getMessageTime(message);

    final bookingId =
        int.tryParse(payload['booking_id']?.toString() ?? "") ?? 0;

    final effectiveStatus = getEffectiveBookingStatus(
      bookingId,
      payload['status']?.toString() ?? "pending",
    );

    final title = payload['title']?.toString() ?? "Survey Kost";
    final address = payload['address']?.toString() ?? "";
    final imageUrl = payload['image_url']?.toString() ?? "";
    final date = payload['survey_date']?.toString() ?? "";
    final surveyTime = payload['survey_time']?.toString() ?? "";

    final showOwnerActions =
        isOwnerAccount && isBookingPending(effectiveStatus);
    final showResidentCancel =
        isResidentAccount && isBookingPending(effectiveStatus);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.78,
        margin: EdgeInsets.only(
          left: mine ? 38 : 0,
          right: mine ? 0 : 38,
          bottom: 12,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 20),
                ),
                border: Border.all(color: primaryColor.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSurveyCardHeader(
                    imageUrl: imageUrl,
                    title: title,
                    subtitle: "Pengajuan survey kost",
                    status: effectiveStatus,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      children: [
                        surveyInfoRow(
                          icon: Icons.location_on_outlined,
                          title: "Alamat",
                          value: address.trim().isEmpty
                              ? "Alamat belum ditambahkan"
                              : address,
                        ),
                        const SizedBox(height: 9),
                        surveyInfoRow(
                          icon: Icons.calendar_month_rounded,
                          title: "Tanggal Survey",
                          value: readableDate(date),
                        ),
                        const SizedBox(height: 9),
                        surveyInfoRow(
                          icon: Icons.access_time_rounded,
                          title: "Jam Survey",
                          value: readableTime(surveyTime),
                        ),
                        if (showOwnerActions) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: smallActionButton(
                                  label: "Reject",
                                  icon: Icons.close_rounded,
                                  color: Colors.red,
                                  loadingKey: "booking-$bookingId-reject",
                                  onTap: () {
                                    postBookingAction(
                                      bookingId: bookingId,
                                      action: "reject",
                                      payload: payload,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: smallActionButton(
                                  label: "Accept",
                                  icon: Icons.check_rounded,
                                  color: Colors.green,
                                  loadingKey: "booking-$bookingId-accept",
                                  onTap: () {
                                    postBookingAction(
                                      bookingId: bookingId,
                                      action: "accept",
                                      payload: payload,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(
                                  color: primaryColor.withOpacity(0.25),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed:
                                  isActionLoading(
                                    "booking-$bookingId-reschedule",
                                  )
                                  ? null
                                  : () {
                                      openRescheduleSheet(payload);
                                    },
                              icon:
                                  isActionLoading(
                                    "booking-$bookingId-reschedule",
                                  )
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.event_repeat_rounded,
                                      size: 18,
                                    ),
                              label: const Text(
                                "Reschedule",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                        if (showResidentCancel) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(
                                  color: Colors.red.withOpacity(0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed:
                                  isActionLoading("booking-$bookingId-cancel")
                                  ? null
                                  : () {
                                      postBookingAction(
                                        bookingId: bookingId,
                                        action: "cancel",
                                        payload: payload,
                                      );
                                    },
                              icon: isActionLoading("booking-$bookingId-cancel")
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text(
                                "Cancel Survey",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSurveyRescheduleCard(
    dynamic message,
    Map<String, dynamic> payload,
  ) {
    final mine = isMyMessage(message);
    final time = getMessageTime(message);

    final rescheduleId =
        int.tryParse(payload['reschedule_id']?.toString() ?? "") ?? 0;

    final effectiveStatus = getEffectiveRescheduleStatus(
      rescheduleId,
      payload['status']?.toString() ?? "pending",
    );

    final title = payload['title']?.toString() ?? "Reschedule Survey";
    final address = payload['address']?.toString() ?? "";
    final imageUrl = payload['image_url']?.toString() ?? "";

    final oldDate = payload['old_survey_date']?.toString() ?? "";
    final oldTime = payload['old_survey_time']?.toString() ?? "";

    final newDate = payload['new_survey_date']?.toString() ?? "";
    final newTime = payload['new_survey_time']?.toString() ?? "";

    final showResidentActions =
        isResidentAccount && normalizeStatus(effectiveStatus) == "pending";

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.78,
        margin: EdgeInsets.only(
          left: mine ? 38 : 0,
          right: mine ? 0 : 38,
          bottom: 12,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 20),
                ),
                border: Border.all(color: Colors.deepPurple.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSurveyCardHeader(
                    imageUrl: imageUrl,
                    title: title,
                    subtitle: "Permintaan reschedule survey",
                    status: effectiveStatus,
                    forceColor: Colors.deepPurple,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      children: [
                        surveyInfoRow(
                          icon: Icons.location_on_outlined,
                          title: "Alamat",
                          value: address.trim().isEmpty
                              ? "Alamat belum ditambahkan"
                              : address,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              surveyInfoRow(
                                icon: Icons.history_rounded,
                                title: "Jadwal Lama",
                                value:
                                    "${readableDate(oldDate)} • ${readableTime(oldTime)}",
                              ),
                              const SizedBox(height: 10),
                              surveyInfoRow(
                                icon: Icons.event_available_rounded,
                                title: "Jadwal Baru",
                                value:
                                    "${readableDate(newDate)} • ${readableTime(newTime)}",
                              ),
                            ],
                          ),
                        ),
                        if (showResidentActions) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: smallActionButton(
                                  label: "Reject",
                                  icon: Icons.close_rounded,
                                  color: Colors.red,
                                  loadingKey: "reschedule-$rescheduleId-reject",
                                  onTap: () {
                                    postRescheduleAction(
                                      payload: payload,
                                      action: "reject",
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: smallActionButton(
                                  label: "Accept",
                                  icon: Icons.check_rounded,
                                  color: Colors.green,
                                  loadingKey:
                                      "reschedule-$rescheduleId-approve",
                                  onTap: () {
                                    postRescheduleAction(
                                      payload: payload,
                                      action: "approve",
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSurveyCardHeader({
    required String imageUrl,
    required String title,
    required String subtitle,
    required String status,
    Color? forceColor,
  }) {
    final badgeColor = forceColor ?? statusColor(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl.trim().isEmpty
                  ? const Icon(
                      Icons.home_work_outlined,
                      color: Colors.white,
                      size: 30,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.home_work_outlined,
                          color: Colors.white,
                          size: 30,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.18,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
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

  Widget surveyInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget smallActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required String loadingKey,
    required VoidCallback onTap,
  }) {
    final loading = isActionLoading(loadingKey);

    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          loading ? "..." : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: primaryColor,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Belum ada pesan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF161A33),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Mulai percakapan untuk menanyakan ketersediaan, fasilitas, aturan kos, atau pengajuan survey.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 50,
                  maxHeight: 120,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: messageController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => sendMessage(),
                  decoration: InputDecoration(
                    hintText: "Tulis pesan...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSending ? Colors.grey : primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: isSending ? null : sendMessage,
                icon: isSending
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    final subtitle = isOwnerAccount ? "Penyewa" : "Pemilik kos";

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF161A33),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loadMessages,
            icon: Icon(Icons.refresh_rounded, color: primaryColor),
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
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: primaryColor,
        titleSpacing: 0,
        title: buildHeader(),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : messages.isEmpty
                ? RefreshIndicator(
                    color: primaryColor,
                    onRefresh: loadMessages,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.58,
                          child: buildEmptyState(),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: loadMessages,
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return buildMessageItem(index);
                      },
                    ),
                  ),
          ),
          buildChatInput(),
        ],
      ),
    );
  }
}
