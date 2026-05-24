import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/ListChat.dart';
import 'package:koskaki/screens/Resident/DetailKos_page.dart';
import 'package:koskaki/screens/Resident/Profile.dart';
import 'package:koskaki/screens/Resident/QrScan.dart';
import 'package:koskaki/screens/Resident/SearchResult.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Resident/RiwayatSewa.dart';
import 'package:koskaki/screens/Resident/Tunggakan.dart';
import 'package:koskaki/screens/Resident/FamilyUser.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryColor = Color(0xFF2D2F8F);
const Color secondaryColor = Color(0xFF5B5FEF);
const Color softBlue = Color(0xFFEFF2FF);
const Color darkText = Color(0xFF161A33);

enum KosFilter { rekomendasi, termurah, terbaru, terlengkap }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> kosList = [];

  Map<String, dynamic>? userData;

  bool loadingUser = true;
  bool loadingKos = true;
  bool loadingTunggakanBadge = true;
  bool loadingChatBadge = true;

  int totalTunggakan = 0;
  int totalNominalTunggakan = 0;
  int totalChatBadge = 0;

  Timer? chatBadgeTimer;
  int? currentUserIdForChatBadge;

  KosFilter selectedFilter = KosFilter.rekomendasi;

  @override
  void initState() {
    super.initState();
    loadUser();
    loadKosFromApi();
    loadTunggakanBadge();
  }

  @override
  void dispose() {
    chatBadgeTimer?.cancel();
    super.dispose();
  }

  void startChatBadgeTimer() {
    chatBadgeTimer?.cancel();

    chatBadgeTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      loadChatBadge(showLoading: false);
    });
  }

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String cleanText(dynamic value) {
    if (value == null) return "";

    if (value is Map || value is List) return "";

    return value.toString().trim();
  }

  List<dynamic> normalizeConversationResult(dynamic result) {
    if (result is List) return result;

    final resultMap = toMap(result);

    if (resultMap == null) return [];

    final data = resultMap['data'];
    final conversationsData = resultMap['conversations'];
    final chatsData = resultMap['chats'];
    final itemsData = resultMap['items'];

    if (data is List) return data;
    if (conversationsData is List) return conversationsData;
    if (chatsData is List) return chatsData;
    if (itemsData is List) return itemsData;

    final dataMap = toMap(data);

    if (dataMap != null) {
      final nestedConversations = dataMap['conversations'];
      final nestedChats = dataMap['chats'];
      final nestedItems = dataMap['items'];

      if (nestedConversations is List) return nestedConversations;
      if (nestedChats is List) return nestedChats;
      if (nestedItems is List) return nestedItems;
    }

    return [];
  }

  int getConversationIdForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return 0;

    final conversation = toMap(data['conversation']);

    return toInt(data['id']) ??
        toInt(data['conversation_id']) ??
        toInt(data['conversationId']) ??
        toInt(conversation?['id']) ??
        0;
  }

  int? getApiUnreadCountForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final keys = [
      'unread_count',
      'unread',
      'total_unread',
      'unread_messages',
      'unread_messages_count',
      'new_message_count',
      'new_messages_count',
      'resident_unread_count',
      'user_unread_count',
      'unread_count_resident',
      'unread_count_user',
    ];

    for (final key in keys) {
      if (data.containsKey(key)) {
        return toInt(data[key]) ?? 0;
      }
    }

    final unreadMap = toMap(data['unread_counts']);

    if (unreadMap != null) {
      final residentUnread =
          toInt(unreadMap['resident']) ??
          toInt(unreadMap['user']) ??
          toInt(unreadMap['current_user']) ??
          toInt(unreadMap['resident_count']) ??
          toInt(unreadMap['user_count']);

      if (residentUnread != null) {
        return residentUnread;
      }
    }

    return null;
  }

  dynamic getLastMessageValueForBadge(Map<String, dynamic> data) {
    final keys = [
      'last_message',
      'lastMessage',
      'latest_message',
      'latestMessage',
      'recent_message',
      'recentMessage',
      'last_chat',
      'lastChat',
      'message',
    ];

    for (final key in keys) {
      final value = data[key];

      if (value != null) {
        if (value is String && value.trim().isEmpty) continue;

        return value;
      }
    }

    final messages = data['messages'];

    if (messages is List && messages.isNotEmpty) {
      return messages.last;
    }

    final chatMessages = data['chat_messages'];

    if (chatMessages is List && chatMessages.isNotEmpty) {
      return chatMessages.last;
    }

    return null;
  }

  Map<String, dynamic>? getLastMessageMapForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final lastMessage = getLastMessageValueForBadge(data);
    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap == null) return null;

    final nestedData = toMap(lastMessageMap['data']);

    if (nestedData != null) {
      return nestedData;
    }

    return lastMessageMap;
  }

  String getTextFromMessageMapForBadge(Map<String, dynamic>? messageMap) {
    if (messageMap == null) return "";

    final keys = [
      'message',
      'body',
      'text',
      'content',
      'pesan',
      'isi_pesan',
      'last_message',
      'lastMessage',
      'latest_message',
      'latestMessage',
    ];

    for (final key in keys) {
      final value = cleanText(messageMap[key]);

      if (value.isNotEmpty) {
        return value;
      }
    }

    final nestedMessage = toMap(messageMap['message']);
    final nestedData = toMap(messageMap['data']);

    final nestedMessageText = getTextFromMessageMapForBadge(nestedMessage);

    if (nestedMessageText.isNotEmpty) {
      return nestedMessageText;
    }

    final nestedDataText = getTextFromMessageMapForBadge(nestedData);

    if (nestedDataText.isNotEmpty) {
      return nestedDataText;
    }

    return "";
  }

  DateTime? parseDateTimeForChatBadge(dynamic value) {
    final raw = cleanText(value);

    if (raw.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(raw);

    parsed ??= DateTime.tryParse(raw.replaceFirst(" ", "T"));

    if (parsed == null) return null;

    return parsed.toLocal();
  }

  DateTime? getChatDateForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final lastMessageMap = getLastMessageMapForBadge(chat);

    final dateFromMessage =
        parseDateTimeForChatBadge(lastMessageMap?['created_at']) ??
        parseDateTimeForChatBadge(lastMessageMap?['sent_at']) ??
        parseDateTimeForChatBadge(lastMessageMap?['time']) ??
        parseDateTimeForChatBadge(lastMessageMap?['timestamp']) ??
        parseDateTimeForChatBadge(lastMessageMap?['updated_at']);

    if (dateFromMessage != null) {
      return dateFromMessage;
    }

    return parseDateTimeForChatBadge(data['last_message_at']) ??
        parseDateTimeForChatBadge(data['latest_message_at']) ??
        parseDateTimeForChatBadge(data['last_chat_at']) ??
        parseDateTimeForChatBadge(data['updated_at']) ??
        parseDateTimeForChatBadge(data['created_at']) ??
        parseDateTimeForChatBadge(data['time']);
  }

  String getRawLastMessageForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessage = getLastMessageValueForBadge(data);
    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap != null) {
      final textFromMap = getTextFromMessageMapForBadge(lastMessageMap);

      if (textFromMap.isNotEmpty) {
        return textFromMap;
      }
    }

    final textFromDirectValue = cleanText(lastMessage);

    if (textFromDirectValue.isNotEmpty) {
      return textFromDirectValue;
    }

    final topLevelText = getTextFromMessageMapForBadge(data);

    if (topLevelText.isNotEmpty) {
      return topLevelText;
    }

    return "";
  }

  String getLastMessageKeyForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessageMap = getLastMessageMapForBadge(chat);
    final chatDate = getChatDateForBadge(chat);
    final rawText = getRawLastMessageForBadge(chat);

    final id = cleanText(lastMessageMap?['id']).isNotEmpty
        ? cleanText(lastMessageMap?['id'])
        : cleanText(data['last_message_id']).isNotEmpty
        ? cleanText(data['last_message_id'])
        : cleanText(data['latest_message_id']);

    final dateText = chatDate?.toIso8601String() ?? "";

    return "$id|$dateText|$rawText";
  }

  bool isLastMessageMineForBadge(dynamic chat) {
    final lastMessageMap = getLastMessageMapForBadge(chat);

    if (lastMessageMap == null) return false;

    if (lastMessageMap['is_me'] != null) {
      return lastMessageMap['is_me'] == true;
    }

    final senderId =
        toInt(lastMessageMap['sender_id']) ??
        toInt(lastMessageMap['user_id']) ??
        toInt(lastMessageMap['from_user_id']) ??
        toInt(toMap(lastMessageMap['sender'])?['id']) ??
        toInt(toMap(lastMessageMap['user'])?['id']);

    if (currentUserIdForChatBadge != null && senderId != null) {
      return senderId == currentUserIdForChatBadge;
    }

    final senderType = cleanText(lastMessageMap['sender_type']).toLowerCase();

    if (senderType == "resident" || senderType == "user") {
      return true;
    }

    final from = cleanText(lastMessageMap['from']).toLowerCase();

    if (from == "me" || from == "resident" || from == "user") {
      return true;
    }

    return false;
  }

  Future<Map<String, int>> readLocalChatUnreadMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString("home_chat_unread_counts");

      if (raw == null || raw.trim().isEmpty) return {};

      final decoded = jsonDecode(raw);

      if (decoded is! Map) return {};

      final result = <String, int>{};

      decoded.forEach((key, value) {
        result[key.toString()] = toInt(value) ?? 0;
      });

      return result;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> readLocalChatKeyMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString("home_chat_last_keys");

      if (raw == null || raw.trim().isEmpty) return {};

      final decoded = jsonDecode(raw);

      if (decoded is! Map) return {};

      final result = <String, String>{};

      decoded.forEach((key, value) {
        result[key.toString()] = value?.toString() ?? "";
      });

      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLocalChatBadgeData({
    required Map<String, int> unreadMap,
    required Map<String, String> keyMap,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("home_chat_unread_counts", jsonEncode(unreadMap));
    await prefs.setString("home_chat_last_keys", jsonEncode(keyMap));
  }

  Future<void> clearLocalChatBadge() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove("home_chat_unread_counts");

    if (!mounted) return;

    setState(() {
      totalChatBadge = 0;
    });
  }

  Future<void> loadChatBadge({
    bool showLoading = true,
    bool resetLocal = false,
  }) async {
    try {
      if (showLoading && mounted) {
        setState(() {
          loadingChatBadge = true;
        });
      }

      final api = ApiService();
      final token = cleanToken(await api.getToken());

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          totalChatBadge = 0;
          loadingChatBadge = false;
        });

        return;
      }

      if (currentUserIdForChatBadge == null) {
        final user = await api.getUser();

        final userMap = toMap(user);
        final dataUserMap = toMap(userMap?['data']);
        final nestedUserMap = toMap(userMap?['user']);

        currentUserIdForChatBadge =
            toInt(userMap?['id']) ??
            toInt(dataUserMap?['id']) ??
            toInt(nestedUserMap?['id']);
      }

      final result = await api.getConversations();
      final conversations = normalizeConversationResult(result);

      final localUnreadMap = resetLocal
          ? <String, int>{}
          : await readLocalChatUnreadMap();
      final localKeyMap = await readLocalChatKeyMap();

      bool hasApiUnread = false;
      int apiUnreadTotal = 0;

      for (final chat in conversations) {
        final conversationId = getConversationIdForBadge(chat);

        if (conversationId <= 0) continue;

        final idKey = conversationId.toString();
        final newKey = getLastMessageKeyForBadge(chat);
        final oldKey = localKeyMap[idKey];

        final apiUnread = getApiUnreadCountForBadge(chat);

        if (apiUnread != null) {
          hasApiUnread = true;
          apiUnreadTotal += apiUnread;
        } else {
          final isNewMessage =
              oldKey != null &&
              oldKey.isNotEmpty &&
              newKey.isNotEmpty &&
              oldKey != newKey;

          final lastMessageMine = isLastMessageMineForBadge(chat);

          if (!resetLocal && isNewMessage && !lastMessageMine) {
            localUnreadMap[idKey] = (localUnreadMap[idKey] ?? 0) + 1;
          }
        }

        if (newKey.isNotEmpty) {
          localKeyMap[idKey] = newKey;
        }
      }

      await saveLocalChatBadgeData(
        unreadMap: localUnreadMap,
        keyMap: localKeyMap,
      );

      final localTotal = localUnreadMap.values.fold<int>(
        0,
        (previous, value) => previous + value,
      );

      if (!mounted) return;

      setState(() {
        totalChatBadge = hasApiUnread ? apiUnreadTotal : localTotal;
        loadingChatBadge = false;
      });
    } catch (e) {
      debugPrint("ERROR LOAD CHAT BADGE:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        totalChatBadge = 0;
        loadingChatBadge = false;
      });
    }
  }

  Future<void> openChatListPage() async {
    await clearLocalChatBadge();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatListOwnerPage()),
    );

    if (!mounted) return;

    await loadChatBadge(resetLocal: true);
  }

  bool isGraceActiveForBadge(Map<String, dynamic> booking) {
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

  bool isPendingPaymentStatusForBadge(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    return status == "pending" ||
        status == "waiting" ||
        status == "waiting_confirmation" ||
        status == "waiting_verification" ||
        status == "unverified" ||
        status == "menunggu";
  }

  bool hasPendingPaymentForInvoiceBadge(Map<String, dynamic> invoice) {
    final payments =
        invoice["payments"] ??
        invoice["rental_payments"] ??
        invoice["rentalPayments"];

    if (payments is List) {
      for (final item in payments) {
        if (item is Map) {
          final payment = Map<String, dynamic>.from(item);

          if (isPendingPaymentStatusForBadge(payment["status"])) {
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<void> loadUser() async {
    try {
      final api = ApiService();
      final user = await api.getUser();

      if (!mounted) return;

      setState(() {
        userData = {
          "username": user?['name'] ?? "User",
          "email": user?['email'] ?? "-",
        };

        loadingUser = false;
      });
    } catch (e) {
      debugPrint("ERROR LOAD USER API: $e");

      if (!mounted) return;

      setState(() {
        loadingUser = false;
      });
    }
  }

  Future<void> loadKosFromApi() async {
    try {
      if (mounted) {
        setState(() {
          loadingKos = true;
        });
      }

      final api = ApiService();
      final token = await api.getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      debugPrint("STATUS LOAD KOS: ${response.statusCode}");
      debugPrint("BODY LOAD KOS: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        dynamic rawData;

        if (decoded is Map<String, dynamic>) {
          rawData = decoded['data'];

          if (rawData is Map<String, dynamic> && rawData['data'] != null) {
            rawData = rawData['data'];
          }
        } else {
          rawData = decoded;
        }

        if (rawData is List) {
          final data = rawData
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((item) {
                final status = item['status']?.toString().toLowerCase();

                return status == null ||
                    status == "active" ||
                    status == "aktif";
              })
              .toList();

          if (!mounted) return;

          setState(() {
            kosList = data;
            loadingKos = false;
          });
        } else {
          if (!mounted) return;

          setState(() {
            kosList = [];
            loadingKos = false;
          });
        }
      } else {
        if (!mounted) return;

        setState(() {
          kosList = [];
          loadingKos = false;
        });
      }
    } catch (e) {
      debugPrint("ERROR LOAD KOS API: $e");

      if (!mounted) return;

      setState(() {
        kosList = [];
        loadingKos = false;
      });
    }
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

  DateTime? parseNullableDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return null;

    return DateTime.tryParse(text);
  }

  DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
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

  bool isInvoiceOverdueForBadge(Map<String, dynamic> invoice) {
    final status = invoice["status"]?.toString().toLowerCase().trim() ?? "";

    if (status == "overdue" || status == "terlambat") {
      return true;
    }

    final dueDate = parseNullableDate(
      invoice["due_date"] ??
          invoice["dueDate"] ??
          invoice["payment_due_date"] ??
          invoice["paymentDueDate"] ??
          invoice["deadline"] ??
          invoice["period_end"] ??
          invoice["periodEnd"],
    );

    if (dueDate == null) return false;

    return DateTime.now().isAfter(endOfDay(dueDate));
  }

  bool isInvoiceTunggakanForBadge(
    Map<String, dynamic> invoice, {
    required Map<String, dynamic> booking,
  }) {
    final amount = getInvoicePayableAmount(invoice);

    if (amount <= 0) return false;

    if (hasPendingPaymentForInvoiceBadge(invoice)) return false;

    return isGraceActiveForBadge(booking) || isInvoiceOverdueForBadge(invoice);
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesForBadge({
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

        debugPrint("BADGE TUNGGAKAN INVOICE URL:");
        debugPrint(url);
        debugPrint("BADGE TUNGGAKAN INVOICE STATUS:");
        debugPrint(response.statusCode.toString());
        debugPrint("BADGE TUNGGAKAN INVOICE BODY:");
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
        debugPrint("ERROR FETCH BADGE TUNGGAKAN INVOICE:");
        debugPrint(e.toString());
      }
    }

    return [];
  }

  Future<void> loadTunggakanBadge() async {
    try {
      if (mounted) {
        setState(() {
          loadingTunggakanBadge = true;
        });
      }

      final api = ApiService();
      final token = cleanToken(await api.getToken());

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          totalTunggakan = 0;
          totalNominalTunggakan = 0;
          loadingTunggakanBadge = false;
        });

        return;
      }

      final cacheBuster = DateTime.now().millisecondsSinceEpoch;

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/rental-bookings?_=$cacheBuster"),
        headers: authHeaders(token),
      );

      debugPrint("BADGE TUNGGAKAN BOOKING STATUS:");
      debugPrint(response.statusCode.toString());
      debugPrint("BADGE TUNGGAKAN BOOKING BODY:");
      debugPrint(response.body);

      if (response.statusCode != 200) {
        if (!mounted) return;

        setState(() {
          totalTunggakan = 0;
          totalNominalTunggakan = 0;
          loadingTunggakanBadge = false;
        });

        return;
      }

      final decoded = jsonDecode(response.body);
      final bookings = parseDataList(decoded);

      int count = 0;
      int totalAmount = 0;

      for (final rawBooking in bookings) {
        final booking = Map<String, dynamic>.from(rawBooking);
        final rentalBookingId = getRentalBookingId(booking);

        if (rentalBookingId <= 0) continue;

        final invoices = await fetchInvoicesForBadge(
          rentalBookingId: rentalBookingId,
          token: token,
        );

        for (final invoice in invoices) {
          final invoiceMap = Map<String, dynamic>.from(invoice);

          if (isInvoiceTunggakanForBadge(invoiceMap, booking: booking)) {
            count++;
            totalAmount += getInvoicePayableAmount(invoiceMap);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        totalTunggakan = count;
        totalNominalTunggakan = totalAmount;
        loadingTunggakanBadge = false;
      });
    } catch (e) {
      debugPrint("ERROR LOAD BADGE TUNGGAKAN:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        totalTunggakan = 0;
        totalNominalTunggakan = 0;
        loadingTunggakanBadge = false;
      });
    }
  }

  String formatRupiah(int value) {
    final result = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp $result";
  }

  int getMainPriceValue(Map<String, dynamic> kos) {
    final month = toInt(kos['price_perMonth'] ?? kos['price_per_month']);
    final night = toInt(kos['price_perNight'] ?? kos['price_per_night']);
    final week = toInt(kos['price_perWeek'] ?? kos['price_per_week']);
    final year = toInt(kos['price_perYear'] ?? kos['price_per_year']);

    return month ?? night ?? week ?? year ?? 999999999;
  }

  String getKosPrice(Map<String, dynamic> kos) {
    final month = toInt(kos['price_perMonth'] ?? kos['price_per_month']);
    final night = toInt(kos['price_perNight'] ?? kos['price_per_night']);
    final week = toInt(kos['price_perWeek'] ?? kos['price_per_week']);
    final year = toInt(kos['price_perYear'] ?? kos['price_per_year']);

    if (month != null && month > 0) {
      return "${formatRupiah(month)} / Bulan";
    }

    if (night != null && night > 0) {
      return "${formatRupiah(night)} / Malam";
    }

    if (week != null && week > 0) {
      return "${formatRupiah(week)} / Minggu";
    }

    if (year != null && year > 0) {
      return "${formatRupiah(year)} / Tahun";
    }

    return "Harga belum tersedia";
  }

  String getKosTitle(Map<String, dynamic> kos) {
    return kos['title']?.toString() ??
        kos['name']?.toString() ??
        "Nama kos tidak tersedia";
  }

  String getKosAddress(Map<String, dynamic> kos) {
    return kos['address']?.toString() ?? "Alamat belum tersedia";
  }

  String getKosCity(Map<String, dynamic> kos) {
    final city = kos['city'];

    if (city is Map) {
      return city['name']?.toString() ?? "Kota belum tersedia";
    }

    return kos['city_name']?.toString() ?? "Kota belum tersedia";
  }

  double getRatingValue(Map<String, dynamic> kos) {
    return double.tryParse(
          kos['rating_avg']?.toString() ??
              kos['average_rating']?.toString() ??
              kos['avg_rating']?.toString() ??
              kos['rating']?.toString() ??
              "0",
        ) ??
        0;
  }

  int getRatingCount(Map<String, dynamic> kos) {
    return int.tryParse(
          kos['rating_count']?.toString() ??
              kos['total_reviews']?.toString() ??
              kos['review_count']?.toString() ??
              "0",
        ) ??
        0;
  }

  int countFacilityValue(dynamic value) {
    if (value == null) return 0;

    if (value is List) {
      return value.where((item) {
        if (item == null) return false;

        if (item is Map) {
          final name =
              item['name'] ??
              item['title'] ??
              item['facility_name'] ??
              item['nama'] ??
              item['label'];

          if (name != null && name.toString().trim().isNotEmpty) {
            return true;
          }

          return item.isNotEmpty;
        }

        final text = item.toString().trim();

        return text.isNotEmpty && text != "null";
      }).length;
    }

    if (value is Map) {
      final nestedData = value['data'];

      if (nestedData is List) {
        return countFacilityValue(nestedData);
      }

      final values = value.values.where((item) {
        if (item == true) return true;

        if (item is String) {
          final text = item.trim();

          return text.isNotEmpty && text != "null";
        }

        return false;
      }).length;

      return values;
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty || text == "null") return 0;

      if (text.startsWith("[") || text.startsWith("{")) {
        try {
          final decoded = jsonDecode(text);
          return countFacilityValue(decoded);
        } catch (_) {}
      }

      final parts = text
          .split(RegExp(r'[,;|\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item != "null")
          .toList();

      if (parts.isEmpty) return 0;

      return parts.length;
    }

    return 0;
  }

  int getFacilityCount(Map<String, dynamic> kos) {
    final directCount = toInt(
      kos['facilities_count'] ??
          kos['facility_count'] ??
          kos['total_facilities'] ??
          kos['jumlah_fasilitas'] ??
          kos['amenities_count'],
    );

    if (directCount != null && directCount > 0) {
      return directCount;
    }

    final property = toMap(kos['property']);
    final placeProperty = toMap(kos['place_property']);
    final placePropertyCamel = toMap(kos['placeProperty']);
    final placeProperties = toMap(kos['place_properties']);
    final placePropertiesCamel = toMap(kos['placeProperties']);

    final candidates = [
      kos['facilities'],
      kos['facility'],
      kos['fasilitas'],
      kos['amenities'],
      kos['features'],
      kos['property_facilities'],
      kos['propertyFacilities'],
      kos['place_facilities'],
      kos['placeFacilities'],
      kos['kost_facilities'],
      kos['kostFacilities'],
      kos['kos_facilities'],
      kos['kosFacilities'],

      property?['facilities'],
      property?['fasilitas'],
      property?['amenities'],

      placeProperty?['facilities'],
      placeProperty?['fasilitas'],
      placeProperty?['amenities'],

      placePropertyCamel?['facilities'],
      placePropertyCamel?['fasilitas'],
      placePropertyCamel?['amenities'],

      placeProperties?['facilities'],
      placeProperties?['fasilitas'],
      placeProperties?['amenities'],

      placePropertiesCamel?['facilities'],
      placePropertiesCamel?['fasilitas'],
      placePropertiesCamel?['amenities'],
    ];

    int maxCount = 0;

    for (final candidate in candidates) {
      final count = countFacilityValue(candidate);

      if (count > maxCount) {
        maxCount = count;
      }
    }

    return maxCount;
  }

  String? getImageUrlFromValue(dynamic value) {
    if (value == null) return null;

    final baseUrlWithoutApi = ApiService.baseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );

    if (value is String) {
      if (value.isEmpty || value == "null") return null;

      if (value.startsWith("http")) return value;

      if (value.startsWith("/storage")) {
        return "$baseUrlWithoutApi$value";
      }

      if (value.startsWith("storage")) {
        return "$baseUrlWithoutApi/$value";
      }

      return "$baseUrlWithoutApi/storage/$value";
    }

    if (value is Map) {
      final possibleImage =
          value['url'] ??
          value['image'] ??
          value['path'] ??
          value['image_path'] ??
          value['file'];

      return getImageUrlFromValue(possibleImage);
    }

    return null;
  }

  String? getKosImage(Map<String, dynamic> kos) {
    final mainImage = getImageUrlFromValue(kos['main_image']);

    if (mainImage != null) return mainImage;

    final images = kos['images'];

    if (images is List && images.isNotEmpty) {
      return getImageUrlFromValue(images.first);
    }

    return null;
  }

  List<Map<String, dynamic>> get sortedKosList {
    List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
      kosList,
    );

    if (selectedFilter == KosFilter.rekomendasi) {
      result.sort((a, b) {
        final ratingA = getRatingValue(a);
        final ratingB = getRatingValue(b);

        final ratingCompare = ratingB.compareTo(ratingA);

        if (ratingCompare != 0) {
          return ratingCompare;
        }

        final countA = getRatingCount(a);
        final countB = getRatingCount(b);

        final countCompare = countB.compareTo(countA);

        if (countCompare != 0) {
          return countCompare;
        }

        final dateA =
            DateTime.tryParse(a['created_at']?.toString() ?? "") ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['created_at']?.toString() ?? "") ??
            DateTime(2000);

        return dateB.compareTo(dateA);
      });
    }

    if (selectedFilter == KosFilter.termurah) {
      result.sort((a, b) {
        return getMainPriceValue(a).compareTo(getMainPriceValue(b));
      });
    }

    if (selectedFilter == KosFilter.terbaru) {
      result.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at']?.toString() ?? "") ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(b['created_at']?.toString() ?? "") ??
            DateTime(2000);

        return dateB.compareTo(dateA);
      });
    }

    if (selectedFilter == KosFilter.terlengkap) {
      result.sort((a, b) {
        final facilitiesA = getFacilityCount(a);
        final facilitiesB = getFacilityCount(b);

        final facilityCompare = facilitiesB.compareTo(facilitiesA);

        if (facilityCompare != 0) {
          return facilityCompare;
        }

        final imagesA = a['images'] is List ? (a['images'] as List).length : 0;
        final imagesB = b['images'] is List ? (b['images'] as List).length : 0;

        final imageCompare = imagesB.compareTo(imagesA);

        if (imageCompare != 0) {
          return imageCompare;
        }

        final ratingA = getRatingValue(a);
        final ratingB = getRatingValue(b);

        return ratingB.compareTo(ratingA);
      });
    }

    return result;
  }

  Future<void> refreshAllData() async {
    await Future.wait([loadUser(), loadKosFromApi(), loadTunggakanBadge()]);
  }

  Future<void> openSearchPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchResultPage()),
    );

    if (!mounted) return;

    loadKosFromApi();
  }

  void showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$feature segera tersedia"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
      ),
    );
  }

  Future<void> openDetailPage(Map<String, dynamic> kos) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKosPage(kos: Map<String, dynamic>.from(kos)),
      ),
    );

    if (!mounted) return;

    loadKosFromApi();
  }

  Future<void> openQrScanPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
  }

  Future<void> openFamilyUserPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FamilyUser()),
    );

    if (!mounted) return;

    loadTunggakanBadge();
  }

  Future<void> openRiwayatSewaPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RiwayatSewaPage()),
    );

    if (!mounted) return;

    loadTunggakanBadge();
  }

  Future<void> openTunggakanPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Tunggakan()),
    );

    if (!mounted) return;

    loadTunggakanBadge();
  }

  Future<void> showKosPreviewSheet(Map<String, dynamic> kos) async {
    bool isOpeningDetail = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> goToDetail() async {
          if (isOpeningDetail) return;

          isOpeningDetail = true;

          Navigator.of(sheetContext).pop();

          await Future.delayed(const Duration(milliseconds: 180));

          if (!mounted) return;

          await openDetailPage(kos);
        }

        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent >= 0.93) {
              goToDetail();
            }

            return false;
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.52,
            minChildSize: 0.35,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.52, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.10),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: buildPreviewImage(kos),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    getKosTitle(kos),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: darkText,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: softBlue,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        getRatingValue(kos) == 0
                                            ? "Baru"
                                            : getRatingValue(
                                                kos,
                                              ).toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              getKosPrice(kos),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            buildPreviewInfo(
                              icon: Icons.location_on_rounded,
                              title: "Lokasi",
                              value:
                                  "${getKosAddress(kos)}, ${getKosCity(kos)}",
                            ),
                            buildPreviewInfo(
                              icon: Icons.home_work_rounded,
                              title: "Kota",
                              value: getKosCity(kos),
                            ),
                            buildPreviewInfo(
                              icon: Icons.verified_rounded,
                              title: "Status",
                              value:
                                  kos['status']?.toString().toLowerCase() ==
                                      "active"
                                  ? "Tersedia"
                                  : kos['status']?.toString() ?? "Tersedia",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: goToDetail,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryColor, secondaryColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.22),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.swipe_up_rounded, color: Colors.white),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Tarik ke atas untuk membuka detail kos",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          "Atau ketuk area ungu di atas untuk langsung membuka detail.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget buildPreviewImage(Map<String, dynamic> kos) {
    final imageUrl = getKosImage(kos);

    if (imageUrl == null) {
      return Image.asset(
        "assets/cover1.png",
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: 190,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: 190,
          width: double.infinity,
          color: softBlue,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          "assets/cover1.png",
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget buildPreviewInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w800,
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

  Widget buildKosImage(Map<String, dynamic> kos) {
    final imageUrl = getKosImage(kos);

    if (imageUrl == null) {
      return Image.asset(
        "assets/cover1.png",
        height: 132,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: 132,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: 132,
          width: double.infinity,
          color: softBlue,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          "assets/cover1.png",
          height: 132,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget buildUserLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: primaryColor, size: 32),
    );
  }

  Widget buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget buildHeader() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.28),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -18,
              top: -26,
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 38,
              top: 18,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -34,
              bottom: -54,
              child: Container(
                width: 115,
                height: 115,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        );
                      },
                      child: buildUserLogo(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: loadingUser
                          ? const Text(
                              "Memuat data...",
                              style: TextStyle(color: Colors.white),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hai, ${userData?['username'] ?? 'User'} 👋",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "${userData?['email'] ?? '-'}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.82),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    buildHeaderActionButton(
                      tooltip: "Chat",
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatListOwnerPage(),
                          ),
                        );
                      },
                    ),
                    buildHeaderActionButton(
                      tooltip: "Masuk Family",
                      icon: Icons.key_rounded,
                      onTap: openQrScanPage,
                    ),
                    buildHeaderActionButton(
                      tooltip: "Family Saya",
                      icon: Icons.family_restroom_rounded,
                      onTap: openFamilyUserPage,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Temukan kos nyaman\nsesuai kebutuhanmu",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: openSearchPage,
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: primaryColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Cari kos, alamat, atau kota",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.black38,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMenuSection() {
    return Row(
      children: [
        Expanded(
          child: MenuItem(
            icon: Icons.auto_awesome_rounded,
            title: "Rekomendasi",
            active: selectedFilter == KosFilter.rekomendasi,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.rekomendasi;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuItem(
            icon: Icons.payments_rounded,
            title: "Termurah",
            active: selectedFilter == KosFilter.termurah,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.termurah;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuItem(
            icon: Icons.home_work_rounded,
            title: "Terbaru",
            active: selectedFilter == KosFilter.terbaru,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.terbaru;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuItem(
            icon: Icons.grid_view_rounded,
            title: "Lengkap",
            active: selectedFilter == KosFilter.terlengkap,
            onTap: () {
              setState(() {
                selectedFilter = KosFilter.terlengkap;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget buildHistoryCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: openRiwayatSewaPage,
        child: Container(
          height: 138,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const Spacer(),
              const Text(
                "Riwayat",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Status sewa dan pembayaran",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTunggakanCard() {
    final hasTunggakan = totalTunggakan > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: openTunggakanPage,
        child: Container(
          height: 138,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasTunggakan
                  ? Colors.red.withOpacity(0.20)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: hasTunggakan
                    ? Colors.red.withOpacity(0.09)
                    : primaryColor.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: hasTunggakan
                            ? [Colors.red, Colors.redAccent]
                            : [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      hasTunggakan
                          ? Icons.warning_amber_rounded
                          : Icons.receipt_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  if (hasTunggakan)
                    Positioned(
                      right: -7,
                      top: -7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          totalTunggakan > 99 ? "99+" : "$totalTunggakan",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Tunggakan",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: darkText,
                      ),
                    ),
                  ),
                  if (loadingTunggakanBadge)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                loadingTunggakanBadge
                    ? "Mengecek data..."
                    : hasTunggakan
                    ? "${formatRupiah(totalNominalTunggakan)}"
                    : "Tidak ada tunggakan",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: hasTunggakan ? Colors.red : Colors.black54,
                  height: 1.25,
                  fontWeight: hasTunggakan ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildFamilyUserCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: openFamilyUserPage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Family Saya",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: darkText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Lihat family kost yang sedang kamu ikuti",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildKosLoading() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        mainAxisExtent: 280,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget buildKosEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: softBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.home_work_outlined,
              size: 42,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Belum ada kos tersedia",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Kos yang ditambahkan owner akan muncul di sini.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget buildKosGrid() {
    final data = sortedKosList;

    if (data.isEmpty) {
      return buildKosEmpty();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: GridView.builder(
        key: ValueKey("${selectedFilter.name}-${data.length}"),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          mainAxisExtent: 300,
        ),
        itemBuilder: (context, index) {
          final kos = data[index];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 420 + (index * 80)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - value)),
                  child: Transform.scale(
                    scale: 0.96 + (0.04 * value),
                    child: child,
                  ),
                ),
              );
            },
            child: KosCard(
              kos: kos,
              title: getKosTitle(kos),
              address: getKosAddress(kos),
              city: getKosCity(kos),
              price: getKosPrice(kos),
              rating: getRatingValue(kos),
              ratingCount: getRatingCount(kos),
              facilityCount: getFacilityCount(kos),
              showFacilityCount: selectedFilter == KosFilter.terlengkap,
              imageBuilder: buildKosImage,
              onTap: () async {
                await showKosPreviewSheet(Map<String, dynamic>.from(kos));
              },
            ),
          );
        },
      ),
    );
  }

  String getSectionTitle() {
    switch (selectedFilter) {
      case KosFilter.termurah:
        return "Kos Termurah";
      case KosFilter.terbaru:
        return "Kos Terbaru";
      case KosFilter.terlengkap:
        return "Kos Terlengkap";
      case KosFilter.rekomendasi:
        return "Rekomendasi Terbaik";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshAllData,
          color: primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(),
                const SizedBox(height: 22),
                buildMenuSection(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: buildHistoryCard()),
                    const SizedBox(width: 12),
                    Expanded(child: buildTunggakanCard()),
                  ],
                ),
                const SizedBox(height: 12),
                buildFamilyUserCard(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        getSectionTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: darkText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: softBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "${sortedKosList.length} kos",
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (loadingKos)
                  buildKosLoading()
                else if (kosList.isEmpty)
                  buildKosEmpty()
                else
                  buildKosGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.05 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: active
                    ? primaryColor.withOpacity(0.22)
                    : Colors.black.withOpacity(0.05),
                blurRadius: active ? 20 : 14,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : primaryColor, size: 24),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : darkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KosCard extends StatelessWidget {
  final Map<String, dynamic> kos;
  final String title;
  final String address;
  final String city;
  final String price;
  final double rating;
  final int ratingCount;
  final int facilityCount;
  final bool showFacilityCount;
  final Widget Function(Map<String, dynamic>) imageBuilder;
  final VoidCallback onTap;

  const KosCard({
    super.key,
    required this.kos,
    required this.title,
    required this.address,
    required this.city,
    required this.price,
    required this.rating,
    required this.ratingCount,
    required this.facilityCount,
    required this.showFacilityCount,
    required this.imageBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            splashColor: primaryColor.withOpacity(0.08),
            highlightColor: primaryColor.withOpacity(0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: imageBuilder(kos),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.34),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.48),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating == 0 ? "Baru" : rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (showFacilityCount) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF2FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$facilityCount fasilitas",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const Spacer(),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: softBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
