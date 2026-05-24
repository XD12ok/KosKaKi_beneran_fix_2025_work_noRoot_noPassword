import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/KostPage.dart';
import 'package:koskaki/screens/Owner/Laporan.dart';
import 'package:koskaki/screens/Owner/PengaturanOwner.dart';
import 'package:koskaki/screens/Owner/ListChat.dart';
import 'package:koskaki/screens/Owner/LaporanSewa.dart';
import 'package:koskaki/screens/Owner/TundaPembayaran.dart';
import 'package:koskaki/screens/Owner/OwnerFamily.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  Map<String, dynamic>? userData;

  bool loading = true;
  bool pendingCountLoading = true;
  bool overdueCountLoading = true;
  bool chatCountLoading = true;

  int currentIndex = 0;

  Timer? chatBadgeTimer;

  int chatBadgeCount = 0;
  int? currentUserIdForChatBadge;

  bool chatBadgeHasLoadedOnce = false;
  bool chatBadgeRefreshing = false;

  final Map<int, String> chatLastMessageKeys = {};
  final Map<int, int> localChatUnreadCounts = {};

  List<dynamic> properties = [];

  int totalKos = 0;
  int pendingPaymentCount = 0;
  int overdueInvoiceCount = 0;

  Map<String, dynamic>? latestProperty;

  final Color _barColor = const Color(0xFFEAF5EB);
  final Color _activeColor = const Color(0xFF0A0E50);
  final Color _backgroundColor = const Color(0xFFF6F8FA);

  @override
  void initState() {
    super.initState();
    loadOwnerHomeData();
    loadChatBadge(showLoading: true, notifyNewMessage: false);
    startChatBadgeTimer();
  }

  @override
  void dispose() {
    chatBadgeTimer?.cancel();
    super.dispose();
  }

  void startChatBadgeTimer() {
    chatBadgeTimer?.cancel();

    chatBadgeTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      loadChatBadge(showLoading: false, notifyNewMessage: true);
    });
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

    final data = resultMap["data"];
    final conversationsData = resultMap["conversations"];
    final chatsData = resultMap["chats"];
    final itemsData = resultMap["items"];

    if (data is List) return data;
    if (conversationsData is List) return conversationsData;
    if (chatsData is List) return chatsData;
    if (itemsData is List) return itemsData;

    final dataMap = toMap(data);

    if (dataMap != null) {
      final nestedConversations = dataMap["conversations"];
      final nestedChats = dataMap["chats"];
      final nestedItems = dataMap["items"];

      if (nestedConversations is List) return nestedConversations;
      if (nestedChats is List) return nestedChats;
      if (nestedItems is List) return nestedItems;
    }

    return [];
  }

  DateTime? parseDateTimeForChatBadge(dynamic value) {
    final raw = cleanText(value);

    if (raw.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(raw);

    parsed ??= DateTime.tryParse(raw.replaceFirst(" ", "T"));

    if (parsed == null) return null;

    return parsed.toLocal();
  }

  int getConversationIdForChatBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return 0;

    final conversation = toMap(data["conversation"]);

    return parseIntValue(
      data["id"] ??
          data["conversation_id"] ??
          data["conversationId"] ??
          conversation?["id"],
    );
  }

  Map<String, dynamic>? getLastMessageMapForChatBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final keys = [
      "last_message",
      "lastMessage",
      "latest_message",
      "latestMessage",
      "recent_message",
      "recentMessage",
      "last_chat",
      "lastChat",
      "message",
    ];

    dynamic lastMessage;

    for (final key in keys) {
      final value = data[key];

      if (value != null) {
        if (value is String && value.trim().isEmpty) continue;

        lastMessage = value;
        break;
      }
    }

    final messages = data["messages"];

    if (lastMessage == null && messages is List && messages.isNotEmpty) {
      lastMessage = messages.last;
    }

    final chatMessages = data["chat_messages"];

    if (lastMessage == null &&
        chatMessages is List &&
        chatMessages.isNotEmpty) {
      lastMessage = chatMessages.last;
    }

    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap == null) return null;

    final nestedData = toMap(lastMessageMap["data"]);

    if (nestedData != null) {
      return nestedData;
    }

    return lastMessageMap;
  }

  String getTextFromMessageMapForChatBadge(Map<String, dynamic>? messageMap) {
    if (messageMap == null) return "";

    final keys = [
      "message",
      "body",
      "text",
      "content",
      "pesan",
      "isi_pesan",
      "last_message",
      "lastMessage",
      "latest_message",
      "latestMessage",
    ];

    for (final key in keys) {
      final value = cleanText(messageMap[key]);

      if (value.isNotEmpty) {
        return value;
      }
    }

    final nestedMessage = toMap(messageMap["message"]);
    final nestedData = toMap(messageMap["data"]);

    final nestedMessageText = getTextFromMessageMapForChatBadge(nestedMessage);

    if (nestedMessageText.isNotEmpty) {
      return nestedMessageText;
    }

    final nestedDataText = getTextFromMessageMapForChatBadge(nestedData);

    if (nestedDataText.isNotEmpty) {
      return nestedDataText;
    }

    return "";
  }

  String getRawLastMessageForChatBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessageMap = getLastMessageMapForChatBadge(chat);

    final textFromMap = getTextFromMessageMapForChatBadge(lastMessageMap);

    if (textFromMap.isNotEmpty) {
      return textFromMap;
    }

    final keys = [
      "last_message",
      "lastMessage",
      "latest_message",
      "latestMessage",
      "recent_message",
      "recentMessage",
      "last_chat",
      "lastChat",
      "message",
    ];

    for (final key in keys) {
      final value = cleanText(data[key]);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return "";
  }

  DateTime? getChatDateForBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final lastMessageMap = getLastMessageMapForChatBadge(chat);

    final dateFromMessage =
        parseDateTimeForChatBadge(lastMessageMap?["created_at"]) ??
        parseDateTimeForChatBadge(lastMessageMap?["sent_at"]) ??
        parseDateTimeForChatBadge(lastMessageMap?["time"]) ??
        parseDateTimeForChatBadge(lastMessageMap?["timestamp"]) ??
        parseDateTimeForChatBadge(lastMessageMap?["updated_at"]);

    if (dateFromMessage != null) {
      return dateFromMessage;
    }

    return parseDateTimeForChatBadge(data["last_message_at"]) ??
        parseDateTimeForChatBadge(data["latest_message_at"]) ??
        parseDateTimeForChatBadge(data["last_chat_at"]) ??
        parseDateTimeForChatBadge(data["updated_at"]) ??
        parseDateTimeForChatBadge(data["created_at"]) ??
        parseDateTimeForChatBadge(data["time"]);
  }

  String getLastMessageKeyForChatBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessageMap = getLastMessageMapForChatBadge(chat);
    final chatDate = getChatDateForBadge(chat);
    final rawText = getRawLastMessageForChatBadge(chat);

    final id = cleanText(lastMessageMap?["id"]).isNotEmpty
        ? cleanText(lastMessageMap?["id"])
        : cleanText(data["last_message_id"]).isNotEmpty
        ? cleanText(data["last_message_id"])
        : cleanText(data["latest_message_id"]);

    final dateText = chatDate?.toIso8601String() ?? "";

    return "$id|$dateText|$rawText";
  }

  int? getApiUnreadCountForChatBadge(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final keys = [
      "unread_count",
      "unread",
      "total_unread",
      "unread_messages",
      "unread_messages_count",
      "new_message_count",
      "new_messages_count",
      "owner_unread_count",
      "unread_count_owner",
    ];

    for (final key in keys) {
      if (data.containsKey(key)) {
        return parseIntValue(data[key]);
      }
    }

    final unreadMap = toMap(data["unread_counts"]);

    if (unreadMap != null) {
      return parseIntValue(
        unreadMap["owner"] ??
            unreadMap["owner_count"] ??
            unreadMap["current_user"],
      );
    }

    return null;
  }

  bool isLastMessageMineForChatBadge(dynamic chat) {
    final lastMessageMap = getLastMessageMapForChatBadge(chat);

    if (lastMessageMap == null) return false;

    if (lastMessageMap["is_me"] != null) {
      return lastMessageMap["is_me"] == true;
    }

    final senderId = parseIntValue(
      lastMessageMap["sender_id"] ??
          lastMessageMap["user_id"] ??
          lastMessageMap["from_user_id"] ??
          toMap(lastMessageMap["sender"])?["id"] ??
          toMap(lastMessageMap["user"])?["id"],
    );

    if (currentUserIdForChatBadge != null && senderId > 0) {
      return senderId == currentUserIdForChatBadge;
    }

    final senderType = cleanText(lastMessageMap["sender_type"]).toLowerCase();

    if (senderType == "owner") {
      return true;
    }

    final from = cleanText(lastMessageMap["from"]).toLowerCase();

    if (from == "me" || from == "owner") {
      return true;
    }

    return false;
  }

  void updateChatLastMessageKeys(List<dynamic> chats) {
    for (final chat in chats) {
      final conversationId = getConversationIdForChatBadge(chat);

      if (conversationId <= 0) continue;

      final key = getLastMessageKeyForChatBadge(chat);

      if (key.isNotEmpty) {
        chatLastMessageKeys[conversationId] = key;
      }
    }
  }

  Future<void> loadChatBadge({
    bool showLoading = true,
    bool notifyNewMessage = true,
  }) async {
    if (chatBadgeRefreshing) return;

    chatBadgeRefreshing = true;

    try {
      if (showLoading && mounted) {
        setState(() {
          chatCountLoading = true;
        });
      }

      final api = ApiService();

      final rawToken = await api.getToken();
      final token = cleanToken(rawToken);

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          chatBadgeCount = 0;
          chatCountLoading = false;
        });

        return;
      }

      if (currentUserIdForChatBadge == null) {
        final user = await api.getUser();

        final userMap = toMap(user);
        final dataUserMap = toMap(userMap?["data"]);
        final nestedUserMap = toMap(userMap?["user"]);

        currentUserIdForChatBadge = parseIntValue(
          userMap?["id"] ?? dataUserMap?["id"] ?? nestedUserMap?["id"],
        );
      }

      final result = await api.getConversations();
      final conversations = normalizeConversationResult(result);

      int apiUnreadTotal = 0;
      bool hasApiUnread = false;

      for (final chat in conversations) {
        final conversationId = getConversationIdForChatBadge(chat);

        if (conversationId <= 0) continue;

        final newKey = getLastMessageKeyForChatBadge(chat);
        final oldKey = chatLastMessageKeys[conversationId];

        final apiUnread = getApiUnreadCountForChatBadge(chat);

        if (apiUnread != null) {
          hasApiUnread = true;
          apiUnreadTotal += apiUnread;
        } else {
          final isNewMessage =
              chatBadgeHasLoadedOnce &&
              notifyNewMessage &&
              oldKey != null &&
              oldKey.isNotEmpty &&
              newKey.isNotEmpty &&
              oldKey != newKey;

          final lastMessageMine = isLastMessageMineForChatBadge(chat);

          if (isNewMessage && !lastMessageMine) {
            localChatUnreadCounts[conversationId] =
                (localChatUnreadCounts[conversationId] ?? 0) + 1;
          }
        }

        if (newKey.isNotEmpty) {
          chatLastMessageKeys[conversationId] = newKey;
        }
      }

      final localUnreadTotal = localChatUnreadCounts.values.fold<int>(
        0,
        (previous, value) => previous + value,
      );

      if (!mounted) return;

      setState(() {
        chatBadgeCount = hasApiUnread ? apiUnreadTotal : localUnreadTotal;
        chatCountLoading = false;
        chatBadgeHasLoadedOnce = true;
      });
    } catch (e) {
      debugPrint("LOAD OWNER CHAT BADGE ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        chatBadgeCount = 0;
        chatCountLoading = false;
      });
    } finally {
      chatBadgeRefreshing = false;
    }
  }

  Future<void> openChatOwnerPage() async {
    setState(() {
      chatBadgeCount = 0;
      localChatUnreadCounts.clear();
    });

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListOwnerPage()),
    );

    await loadChatBadge(showLoading: false, notifyNewMessage: false);
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

  Map<String, String> ownerAuthHeaders(String token) {
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
      if (value["invoices"] is List) return value["invoices"];
      if (value["payments"] is List) return value["payments"];
    }

    return [];
  }

  String cleanLower(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
  }

  int parseIntValue(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return 0;

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

    final cleaned = text.replaceAll(RegExp(r"[^0-9]"), "");

    if (cleaned.isEmpty) return 0;

    return int.tryParse(cleaned) ?? 0;
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

  int getRentalBookingId(Map<String, dynamic> booking) {
    return parseIntValue(
      booking["rental_booking_id"] ??
          booking["rentalBookingId"] ??
          booking["booking_id"] ??
          booking["id"],
    );
  }

  Map<String, dynamic> getInvoiceFromBookingForBadge(
    Map<String, dynamic> booking,
  ) {
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

  int getInvoiceRemainingAmount(Map<String, dynamic> invoice) {
    final remaining = parseIntValue(invoice["remaining_amount"]);

    if (remaining > 0) return remaining;

    final total = parseIntValue(
      invoice["total_amount"] ?? invoice["amount"] ?? invoice["grand_total"],
    );

    final paid = parseIntValue(invoice["paid_amount"]);

    final result = total - paid;

    return result > 0 ? result : 0;
  }

  bool isOverdueInvoice(Map<String, dynamic> invoice) {
    final status = cleanLower(invoice["status"]);

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

  Map<String, dynamic>? getPendingPaymentFromBookingForBadge(
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

    final invoice = getInvoiceFromBookingForBadge(booking);

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

      debugPrint("BADGE CHECK RENTAL PAYMENT:");
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

    final bookingStatus = cleanLower(
      booking["status"] ??
          booking["rental_status"] ??
          booking["booking_status"] ??
          booking["payment_status"],
    );

    final fallbackPaymentId = parseIntValue(
      booking["rental_payment_id"] ??
          booking["rentalPaymentId"] ??
          booking["payment_id"] ??
          booking["paymentId"] ??
          booking["latest_payment_id"] ??
          booking["latestPaymentId"],
    );

    final hasFallbackPayment = fallbackPaymentId > 0;

    final isBookingWaiting =
        bookingStatus == "pending" ||
        bookingStatus == "pending_payment" ||
        bookingStatus == "waiting_payment" ||
        bookingStatus == "waiting_confirmation" ||
        bookingStatus == "unverified" ||
        bookingStatus == "waiting_verification" ||
        bookingStatus == "menunggu";

    if (isBookingWaiting && hasFallbackPayment) {
      debugPrint("BADGE CHECK FALLBACK BOOKING PAYMENT:");
      debugPrint(
        {
          "booking_id": booking["id"],
          "fallback_payment_id": fallbackPaymentId,
          "booking_status": bookingStatus,
        }.toString(),
      );

      return {"id": fallbackPaymentId, "status": "pending"};
    }

    return null;
  }

  Map<String, dynamic>? getPendingPaymentFromInvoiceForBadge(
    Map<String, dynamic> invoice,
  ) {
    final List<dynamic> candidates = [];

    void addIfExists(dynamic value) {
      if (value == null) return;

      if (value is List) {
        candidates.addAll(value);
      } else {
        candidates.add(value);
      }
    }

    addIfExists(invoice["payments"]);
    addIfExists(invoice["rental_payments"]);
    addIfExists(invoice["rentalPayments"]);
    addIfExists(invoice["payment"]);
    addIfExists(invoice["latest_payment"]);
    addIfExists(invoice["latestPayment"]);

    for (final item in candidates) {
      final payment = toMap(item);

      if (payment == null) continue;

      final status = cleanLower(payment["status"] ?? payment["payment_status"]);

      final isPending =
          status == "pending" ||
          status == "waiting_confirmation" ||
          status == "waiting" ||
          status == "unverified" ||
          status == "waiting_verification" ||
          status == "menunggu";

      if (isPending) {
        return payment;
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesForBookingForBadge({
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
            .get(Uri.parse(url), headers: ownerAuthHeaders(token))
            .timeout(const Duration(seconds: 15));

        debugPrint("GET BADGE OVERDUE INVOICES URL:");
        debugPrint(url);

        debugPrint("GET BADGE OVERDUE INVOICES STATUS:");
        debugPrint(response.statusCode.toString());

        debugPrint("GET BADGE OVERDUE INVOICES BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final invoices = parseDynamicList(decoded);

          return invoices
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((invoice) {
                final id = parseIntValue(invoice["rental_booking_id"]);

                if (id <= 0) return true;

                return id == rentalBookingId;
              })
              .toList();
        }

        if (response.statusCode != 404 && response.statusCode != 405) {
          return [];
        }
      } catch (e) {
        debugPrint("GET BADGE OVERDUE INVOICES ERROR:");
        debugPrint(e.toString());
      }
    }

    return [];
  }

  Future<void> loadOwnerHomeData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      pendingCountLoading = true;
      overdueCountLoading = true;
    });

    await Future.wait([
      loadUserAndProperties(),
      loadPendingPaymentCount(),
      loadOverdueInvoiceCount(),
      loadChatBadge(showLoading: false, notifyNewMessage: false),
    ]);

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> refreshOwnerHomeData() async {
    await Future.wait([
      loadUserAndProperties(),
      loadPendingPaymentCount(),
      loadOverdueInvoiceCount(),
      loadChatBadge(showLoading: false, notifyNewMessage: true),
    ]);
  }

  Future<void> loadUserAndProperties() async {
    try {
      final api = ApiService();

      final response = await api.getUser();

      final rawToken = await api.getToken();
      final token = cleanToken(rawToken);

      debugPrint("OWNER HOME TOKEN:");
      debugPrint(
        token.isEmpty ? "TOKEN KOSONG" : "TOKEN ADA LENGTH: ${token.length}",
      );

      final propertyResponse = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/my-properties"),
            headers: ownerAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint("GET MY PROPERTIES STATUS:");
      debugPrint(propertyResponse.statusCode.toString());

      debugPrint("GET MY PROPERTIES BODY:");
      debugPrint(propertyResponse.body);

      List<dynamic> propertyList = [];

      if (propertyResponse.statusCode == 200) {
        final decoded = jsonDecode(propertyResponse.body);

        if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          propertyList = decoded['data']['data'];
        } else if (decoded is Map && decoded['data'] is List) {
          propertyList = decoded['data'];
        } else if (decoded is List) {
          propertyList = decoded;
        }
      }

      final List<Map<String, dynamic>> sortedProperties = propertyList
          .map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          })
          .toList();

      sortedProperties.sort((a, b) {
        final aCreated = a['created_at']?.toString();
        final bCreated = b['created_at']?.toString();

        if (aCreated != null && bCreated != null) {
          final aDate = DateTime.tryParse(aCreated);
          final bDate = DateTime.tryParse(bCreated);

          if (aDate != null && bDate != null) {
            return bDate.compareTo(aDate);
          }
        }

        final aId = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final bId = int.tryParse(b['id']?.toString() ?? '0') ?? 0;

        return bId.compareTo(aId);
      });

      if (!mounted) return;

      setState(() {
        userData = {
          "id": response?['id'],
          "role": response?['role'],
          "username": response?['name'] ?? "Owner",
        };

        properties = sortedProperties;

        totalKos = sortedProperties.length;

        latestProperty = sortedProperties.isNotEmpty
            ? sortedProperties.first
            : null;
      });
    } catch (e) {
      debugPrint("ERROR LOAD USER API:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        userData = {"username": "Owner"};

        properties = [];

        totalKos = 0;

        latestProperty = null;
      });
    }
  }

  Future<void> loadPendingPaymentCount() async {
    if (!mounted) return;

    setState(() {
      pendingCountLoading = true;
    });

    try {
      final api = ApiService();

      final rawToken = await api.getToken();
      final token = cleanToken(rawToken);

      debugPrint("BADGE TOKEN STATUS:");
      debugPrint(
        token.isEmpty ? "TOKEN KOSONG" : "TOKEN ADA LENGTH: ${token.length}",
      );

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          pendingPaymentCount = 0;
          pendingCountLoading = false;
        });

        return;
      }

      final response = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/rental-bookings"),
            headers: ownerAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint("GET BADGE RENTAL BOOKINGS STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET BADGE RENTAL BOOKINGS BODY:");
      debugPrint(response.body);

      int totalPending = 0;
      final Set<int> countedPaymentIds = {};

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final bookings = parseDynamicList(decoded);

        debugPrint("BADGE TOTAL RENTAL BOOKINGS:");
        debugPrint(bookings.length.toString());

        for (final item in bookings) {
          final booking = toMap(item);

          if (booking == null) continue;

          final payment = getPendingPaymentFromBookingForBadge(booking);

          if (payment != null) {
            final paymentId = parseIntValue(payment["id"]);

            if (paymentId > 0) {
              if (!countedPaymentIds.contains(paymentId)) {
                countedPaymentIds.add(paymentId);
                totalPending++;
              }
            } else {
              totalPending++;
            }
          }
        }
      }

      debugPrint("FINAL BADGE PENDING COUNT:");
      debugPrint(totalPending.toString());

      if (!mounted) return;

      setState(() {
        pendingPaymentCount = totalPending;
        pendingCountLoading = false;
      });
    } catch (e) {
      debugPrint("GET PENDING PAYMENT COUNT ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        pendingPaymentCount = 0;
        pendingCountLoading = false;
      });
    }
  }

  Future<void> loadOverdueInvoiceCount() async {
    if (!mounted) return;

    setState(() {
      overdueCountLoading = true;
    });

    try {
      final api = ApiService();

      final rawToken = await api.getToken();
      final token = cleanToken(rawToken);

      debugPrint("OVERDUE BADGE TOKEN STATUS:");
      debugPrint(
        token.isEmpty ? "TOKEN KOSONG" : "TOKEN ADA LENGTH: ${token.length}",
      );

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          overdueInvoiceCount = 0;
          overdueCountLoading = false;
        });

        return;
      }

      final response = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/rental-bookings"),
            headers: ownerAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint("GET OVERDUE BADGE RENTAL BOOKINGS STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET OVERDUE BADGE RENTAL BOOKINGS BODY:");
      debugPrint(response.body);

      int totalOverdue = 0;
      final Set<int> countedInvoiceIds = {};

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final bookings = parseDynamicList(decoded);

        for (final item in bookings) {
          final booking = toMap(item);

          if (booking == null) continue;

          final rentalBookingId = getRentalBookingId(booking);

          if (rentalBookingId <= 0) continue;

          final invoices = await fetchInvoicesForBookingForBadge(
            rentalBookingId: rentalBookingId,
            token: token,
          );

          for (final invoice in invoices) {
            final invoiceId = parseIntValue(invoice["id"]);

            if (!isOverdueInvoice(invoice)) continue;

            if (invoiceId > 0) {
              if (!countedInvoiceIds.contains(invoiceId)) {
                countedInvoiceIds.add(invoiceId);
                totalOverdue++;
              }
            } else {
              totalOverdue++;
            }
          }
        }
      }

      debugPrint("FINAL OVERDUE BADGE COUNT:");
      debugPrint(totalOverdue.toString());

      if (!mounted) return;

      setState(() {
        overdueInvoiceCount = totalOverdue;
        overdueCountLoading = false;
      });
    } catch (e) {
      debugPrint("GET OVERDUE BADGE COUNT ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        overdueInvoiceCount = 0;
        overdueCountLoading = false;
      });
    }
  }

  Future<void> openLaporanSewaPage() async {
    debugPrint("CARD PEMBAYARAN DIKLIK");

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LaporanSewa()),
    );

    await refreshOwnerHomeData();
  }

  Future<void> openTundaPembayaranPage() async {
    debugPrint("CARD PENGAJUAN SEWA / TUNDA PEMBAYARAN DIKLIK");

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TundaPembayaran()),
    );

    await refreshOwnerHomeData();
  }

  Future<void> openOwnerFamilyPage() async {
    debugPrint("CARD KELOLA DATA KOS / FAMILY OWNER DIKLIK");

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OwnerFamily()),
    );

    await refreshOwnerHomeData();
  }

  void goToKostPage() {
    setState(() {
      currentIndex = 1;
    });
  }

  void goToLaporanPage() {
    setState(() {
      currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loading ? "Hai, ..." : "Hai, ${userData?['username'] ?? 'Owner'}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A0E50),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Kelola kos kamu hari ini",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.message_outlined,
                    color: Color(0xFF0A0E50),
                  ),
                  onPressed: openChatOwnerPage,
                ),
              ),

              if (chatBadgeCount > 0)
                Positioned(
                  right: 2,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        chatBadgeCount > 99 ? "99+" : "$chatBadgeCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          BerandaPage(
            userData: userData,
            loading: loading,
            properties: properties,
            totalKos: totalKos,
            latestProperty: latestProperty,
            pendingPaymentCount: pendingPaymentCount,
            pendingCountLoading: pendingCountLoading,
            overdueInvoiceCount: overdueInvoiceCount,
            overdueCountLoading: overdueCountLoading,
            onOpenPembayaran: openLaporanSewaPage,
            onOpenKelolaKos: openOwnerFamilyPage,
            onOpenPengajuanSewa: openTundaPembayaranPage,
            onRefresh: refreshOwnerHomeData,
          ),
          const KostPage(),
          const LaporanPage(),
          PengaturanOwnerPage(userData: userData, loading: loading),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 65,
        color: _barColor,
        buttonBackgroundColor: _activeColor,
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) async {
          setState(() {
            currentIndex = index;
          });

          if (index == 0) {
            await refreshOwnerHomeData();
          }
        },
        items: [
          Icon(
            Icons.home_outlined,
            size: 30,
            color: currentIndex == 0 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.business_outlined,
            size: 30,
            color: currentIndex == 1 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.assessment_outlined,
            size: 30,
            color: currentIndex == 2 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.settings_outlined,
            size: 30,
            color: currentIndex == 3 ? Colors.white : _activeColor,
          ),
        ],
      ),
    );
  }
}

class BerandaPage extends StatelessWidget {
  final Map<String, dynamic>? userData;

  final bool loading;

  final List<dynamic> properties;

  final int totalKos;

  final Map<String, dynamic>? latestProperty;

  final int pendingPaymentCount;

  final bool pendingCountLoading;

  final int overdueInvoiceCount;

  final bool overdueCountLoading;

  final VoidCallback onOpenPembayaran;

  final VoidCallback onOpenKelolaKos;

  final VoidCallback onOpenPengajuanSewa;

  final Future<void> Function() onRefresh;

  const BerandaPage({
    super.key,
    required this.userData,
    required this.loading,
    required this.properties,
    required this.totalKos,
    required this.latestProperty,
    required this.pendingPaymentCount,
    required this.pendingCountLoading,
    required this.overdueInvoiceCount,
    required this.overdueCountLoading,
    required this.onOpenPembayaran,
    required this.onOpenKelolaKos,
    required this.onOpenPengajuanSewa,
    required this.onRefresh,
  });

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 22),
            _buildStatCard(
              icon: Icons.home_work_outlined,
              title: "$totalKos",
              subtitle: "Total Kos",
              color: primaryColor,
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.payments_outlined,
                    iconColor: Colors.blue,
                    title: 'Pembayaran',
                    subtitle: 'Accept atau reject bukti bayar',
                    showBadge: true,
                    badgeCount: pendingPaymentCount,
                    badgeLoading: pendingCountLoading,
                    badgeType: BadgeType.payment,
                    onTap: onOpenPembayaran,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.description_outlined,
                    iconColor: Colors.orange,
                    title: 'Pengajuan Sewa',
                    subtitle: 'Overdue dan pengajuan aktif',
                    showBadge: true,
                    badgeCount: overdueInvoiceCount,
                    badgeLoading: overdueCountLoading,
                    badgeType: BadgeType.overdue,
                    onTap: onOpenPengajuanSewa,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWideActionCard(
              icon: Icons.home_repair_service_outlined,
              iconColor: Colors.green,
              title: 'Kelola Data Kos',
              subtitle: 'Lihat dan atur data kos yang kamu miliki',
              onTap: onOpenKelolaKos,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Kos Saya",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: softGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    latestProperty == null ? "0 Kos" : "Terbaru",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (latestProperty == null)
              _buildEmptyKosCard()
            else
              _buildPropertyCard(
                context: context,
                property: latestProperty!,
                onTap: onOpenKelolaKos,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E50), Color(0xFF18227A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "Dashboard Owner",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Pantau Kos Lebih Mudah",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Kelola data kos, pembayaran, dan pengajuan sewa dalam satu tempat.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 74,
            width: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "Aktif",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required int count,
    required bool loading,
    required BadgeType type,
  }) {
    final bool hasCount = count > 0;

    Color backgroundColor;

    if (type == BadgeType.overdue) {
      backgroundColor = hasCount
          ? const Color(0xFFEF4444)
          : const Color(0xFF16A34A);
    } else {
      backgroundColor = hasCount
          ? const Color(0xFF2563EB)
          : const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: loading
          ? const SizedBox(
              height: 10,
              width: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              count > 99 ? "99+" : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showBadge,
    required int badgeCount,
    required bool badgeLoading,
    required BadgeType badgeType,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 145,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: showBadge && badgeCount > 0
                ? const Color(0xFFFFD1D1)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor, size: 25),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showBadge) ...[
                  const SizedBox(width: 6),
                  _buildBadge(
                    count: badgeCount,
                    loading: badgeLoading,
                    type: badgeType,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyKosCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenKelolaKos,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 82,
              width: 82,
              decoration: BoxDecoration(
                color: softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 42,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Belum Ada Kos",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Kos yang kamu tambahkan akan muncul di bagian ini.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard({
    required BuildContext context,
    required Map<String, dynamic> property,
    required VoidCallback onTap,
  }) {
    final propertyName =
        property['title'] ??
        property['name'] ??
        property['nama'] ??
        property['property_name'] ??
        'Kos Saya';

    final address =
        property['address'] ??
        property['alamat'] ??
        property['city']?['name'] ??
        'Alamat belum tersedia';

    final status = property['status']?.toString() ?? 'active';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFF18227A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    propertyName.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          address.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status == "active"
                          ? Colors.green.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      status == "active" ? "Aktif" : status,
                      style: TextStyle(
                        color: status == "active"
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BadgeType { payment, overdue }
