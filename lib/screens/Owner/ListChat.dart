import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/LiveChatOwner.dart';
import 'package:koskaki/service/api_service.dart';

class ChatListOwnerPage extends StatefulWidget {
  const ChatListOwnerPage({super.key});

  @override
  State<ChatListOwnerPage> createState() => _ChatListOwnerPageState();
}

class _ChatListOwnerPageState extends State<ChatListOwnerPage> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color backgroundColor = const Color(0xFFF7F8FF);

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String surveyBookingPrefix = "KOSKAKI_SURVEY_BOOKING_CARD::";
  static const String surveyReschedulePrefix =
      "KOSKAKI_SURVEY_RESCHEDULE_CARD::";

  List<dynamic> conversations = [];

  bool isLoading = true;
  bool isRefreshing = false;
  bool hasLoadedOnce = false;

  int? currentUserId;

  Timer? refreshTimer;

  final Map<int, String> lastMessageKeys = {};
  final Map<int, int> localUnreadCounts = {};
  final Map<int, String> propertyNameCache = {};

  @override
  void initState() {
    super.initState();
    initNotification();
    loadConversations(showLoading: true, notifyNewMessage: false);
    startAutoRefresh();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> initNotification() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(settings: initSettings);

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  void startAutoRefresh() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      loadConversations(showLoading: false, notifyNewMessage: true);
    });
  }

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  int? toInt(dynamic value) {
    if (value == null) return null;

    return int.tryParse(value.toString());
  }

  String cleanText(dynamic value) {
    if (value == null) return "";

    if (value is Map || value is List) return "";

    return value.toString().trim();
  }

  Map<String, dynamic>? decodeSpecialCardPayload(String text, String prefix) {
    final clean = text.trim();

    if (clean.isEmpty) return null;

    final cleanLower = clean.toLowerCase();
    final prefixLower = prefix.toLowerCase();

    if (!cleanLower.startsWith(prefixLower)) return null;

    final rawJson = clean.substring(prefix.length).trim();

    if (rawJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawJson);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (e) {
      debugPrint("DECODE CHAT LIST CARD ERROR:");
      debugPrint(e.toString());
      return null;
    }
  }

  String normalizeCardStatus(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
  }

  String surveyBookingPreview(Map<String, dynamic> payload) {
    final status = normalizeCardStatus(payload['status']);

    final title = cleanText(payload['title']).isEmpty
        ? "kos"
        : cleanText(payload['title']);

    if (status == "accepted" || status == "approved") {
      return "Survey diterima • $title";
    }

    if (status == "rejected") {
      return "Survey ditolak • $title";
    }

    if (status == "cancelled" || status == "canceled") {
      return "Survey dibatalkan • $title";
    }

    if (status == "completed" || status == "complete") {
      return "Survey selesai • $title";
    }

    if (status == "reschedule_requested") {
      return "Reschedule survey diajukan • $title";
    }

    if (status == "reschedule_approved") {
      return "Reschedule survey diterima • $title";
    }

    if (status == "reschedule_rejected") {
      return "Reschedule survey ditolak • $title";
    }

    if (status == "reschedule_cancelled" || status == "reschedule_canceled") {
      return "Reschedule survey dibatalkan • $title";
    }

    return "Mengajukan survey kost • $title";
  }

  String surveyReschedulePreview(Map<String, dynamic> payload) {
    final status = normalizeCardStatus(payload['status']);

    final title = cleanText(payload['title']).isEmpty
        ? "kos"
        : cleanText(payload['title']);

    if (status == "approved" || status == "accepted") {
      return "Reschedule survey diterima • $title";
    }

    if (status == "rejected") {
      return "Reschedule survey ditolak • $title";
    }

    if (status == "cancelled" || status == "canceled") {
      return "Reschedule survey dibatalkan • $title";
    }

    return "Pemilik mengajukan reschedule survey • $title";
  }

  String getReadableLastMessage(String text) {
    final clean = text.trim();

    if (clean.isEmpty) return "";

    final surveyPayload = decodeSpecialCardPayload(clean, surveyBookingPrefix);

    if (surveyPayload != null) {
      return surveyBookingPreview(surveyPayload);
    }

    final reschedulePayload = decodeSpecialCardPayload(
      clean,
      surveyReschedulePrefix,
    );

    if (reschedulePayload != null) {
      return surveyReschedulePreview(reschedulePayload);
    }

    return clean;
  }

  DateTime? parseDateTime(dynamic value) {
    final raw = cleanText(value);

    if (raw.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(raw);

    parsed ??= DateTime.tryParse(raw.replaceFirst(" ", "T"));

    if (parsed == null) return null;

    return parsed.toLocal();
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

  Future<void> loadConversations({
    bool showLoading = true,
    bool notifyNewMessage = false,
  }) async {
    if (isRefreshing) return;

    isRefreshing = true;

    try {
      if (showLoading && mounted) {
        setState(() {
          isLoading = true;
        });
      }

      if (currentUserId == null) {
        final user = await ApiService().getUser();

        final userMap = toMap(user);
        final dataUserMap = toMap(userMap?['data']);
        final nestedUserMap = toMap(userMap?['user']);

        currentUserId =
            toInt(userMap?['id']) ??
            toInt(dataUserMap?['id']) ??
            toInt(nestedUserMap?['id']);
      }

      final result = await ApiService().getConversations();

      final loadedConversations = normalizeConversationResult(result);

      await enrichPropertyNames(loadedConversations);

      loadedConversations.sort((a, b) {
        final dateA = getChatDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = getChatDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);

        return dateB.compareTo(dateA);
      });

      if (notifyNewMessage && hasLoadedOnce) {
        await checkNewMessageNotifications(loadedConversations);
      }

      updateLastMessageKeys(loadedConversations);

      if (!mounted) return;

      setState(() {
        conversations = loadedConversations;
        isLoading = false;
        hasLoadedOnce = true;
      });
    } catch (e) {
      debugPrint("LOAD CONVERSATIONS ERROR: $e");

      if (!mounted) return;

      if (showLoading) {
        setState(() {
          conversations = [];
          isLoading = false;
        });
      }
    } finally {
      isRefreshing = false;
    }
  }

  void updateLastMessageKeys(List<dynamic> chats) {
    for (final chat in chats) {
      final conversationId = getConversationId(chat);

      if (conversationId <= 0) continue;

      lastMessageKeys[conversationId] = getLastMessageKey(chat);
    }
  }

  Future<void> checkNewMessageNotifications(List<dynamic> chats) async {
    for (final chat in chats) {
      final conversationId = getConversationId(chat);

      if (conversationId <= 0) continue;

      final newKey = getLastMessageKey(chat);
      final oldKey = lastMessageKeys[conversationId];

      if (newKey.isEmpty) continue;

      final apiUnreadCount = getApiUnreadCount(chat);
      final unreadCount = apiUnreadCount ?? getUnreadCount(chat);

      final lastMessageFromMe = isLastMessageMine(chat);

      final isNewMessage = oldKey != null && oldKey != newKey;
      final isNewConversation = oldKey == null && hasLoadedOnce;

      if ((isNewMessage || isNewConversation) && !lastMessageFromMe) {
        if (apiUnreadCount == null) {
          localUnreadCounts[conversationId] =
              (localUnreadCounts[conversationId] ?? 0) + 1;
        }

        final partnerName = getChatPartnerName(chat);
        final lastMessage = getLastMessage(chat);

        if (unreadCount > 0 || apiUnreadCount == null) {
          await showNewChatNotification(
            title: partnerName,
            body: lastMessage == "Belum ada pesan"
                ? "Ada pesan baru"
                : lastMessage,
          );
        }
      }
    }
  }

  Future<void> showNewChatNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'koskaki_chat_channel',
          'Koskaki Chat',
          channelDescription: 'Notifikasi pesan chat terbaru',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  String getNameFromMap(Map<String, dynamic>? data) {
    if (data == null) return "";

    return cleanText(data['name']).isNotEmpty
        ? cleanText(data['name'])
        : cleanText(data['username']).isNotEmpty
        ? cleanText(data['username'])
        : cleanText(data['full_name']).isNotEmpty
        ? cleanText(data['full_name'])
        : "";
  }

  dynamic getLastMessageValue(Map<String, dynamic> data) {
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

    final nestedData = toMap(data['data']);

    if (nestedData != null) {
      for (final key in keys) {
        final value = nestedData[key];

        if (value != null) {
          if (value is String && value.trim().isEmpty) continue;

          return value;
        }
      }

      final nestedMessages = nestedData['messages'];

      if (nestedMessages is List && nestedMessages.isNotEmpty) {
        return nestedMessages.last;
      }
    }

    return null;
  }

  Map<String, dynamic>? getLastMessageMap(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final lastMessage = getLastMessageValue(data);
    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap == null) return null;

    final nestedData = toMap(lastMessageMap['data']);

    if (nestedData != null) {
      return nestedData;
    }

    return lastMessageMap;
  }

  String getTextFromMessageMap(Map<String, dynamic>? messageMap) {
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

    final nestedMessageText = getTextFromMessageMap(nestedMessage);

    if (nestedMessageText.isNotEmpty) {
      return nestedMessageText;
    }

    final nestedDataText = getTextFromMessageMap(nestedData);

    if (nestedDataText.isNotEmpty) {
      return nestedDataText;
    }

    return "";
  }

  String getLastMessage(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "Belum ada pesan";

    final lastMessage = getLastMessageValue(data);
    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap != null) {
      final textFromMap = getTextFromMessageMap(lastMessageMap);

      if (textFromMap.isNotEmpty) {
        return getReadableLastMessage(textFromMap);
      }
    }

    final textFromDirectValue = cleanText(lastMessage);

    if (textFromDirectValue.isNotEmpty) {
      return getReadableLastMessage(textFromDirectValue);
    }

    final topLevelText = getTextFromMessageMap(data);

    if (topLevelText.isNotEmpty) {
      return getReadableLastMessage(topLevelText);
    }

    return "Belum ada pesan";
  }

  DateTime? getChatDate(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return null;

    final lastMessageMap = getLastMessageMap(chat);

    final dateFromMessage =
        parseDateTime(lastMessageMap?['created_at']) ??
        parseDateTime(lastMessageMap?['sent_at']) ??
        parseDateTime(lastMessageMap?['time']) ??
        parseDateTime(lastMessageMap?['timestamp']) ??
        parseDateTime(lastMessageMap?['updated_at']);

    if (dateFromMessage != null) {
      return dateFromMessage;
    }

    return parseDateTime(data['last_message_at']) ??
        parseDateTime(data['latest_message_at']) ??
        parseDateTime(data['last_chat_at']) ??
        parseDateTime(data['updated_at']) ??
        parseDateTime(data['created_at']) ??
        parseDateTime(data['time']);
  }

  String getRawLastMessage(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessage = getLastMessageValue(data);
    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap != null) {
      final textFromMap = getTextFromMessageMap(lastMessageMap);

      if (textFromMap.isNotEmpty) {
        return textFromMap;
      }
    }

    final textFromDirectValue = cleanText(lastMessage);

    if (textFromDirectValue.isNotEmpty) {
      return textFromDirectValue;
    }

    final topLevelText = getTextFromMessageMap(data);

    if (topLevelText.isNotEmpty) {
      return topLevelText;
    }

    return "";
  }

  String getLastMessageKey(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessageMap = getLastMessageMap(chat);
    final chatDate = getChatDate(chat);
    final rawText = getRawLastMessage(chat);

    final id = cleanText(lastMessageMap?['id']).isNotEmpty
        ? cleanText(lastMessageMap?['id'])
        : cleanText(data['last_message_id']).isNotEmpty
        ? cleanText(data['last_message_id'])
        : cleanText(data['latest_message_id']);

    final dateText = chatDate?.toIso8601String() ?? "";

    return "$id|$dateText|$rawText";
  }

  bool isLastMessageMine(dynamic chat) {
    final lastMessageMap = getLastMessageMap(chat);

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

    if (currentUserId != null && senderId != null) {
      return senderId == currentUserId;
    }

    final senderType = cleanText(lastMessageMap['sender_type']).toLowerCase();

    if (senderType == "owner") {
      return true;
    }

    final from = cleanText(lastMessageMap['from']).toLowerCase();

    if (from == "me" || from == "owner") {
      return true;
    }

    return false;
  }

  String formatTimeFromDate(DateTime date) {
    final now = DateTime.now();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday) {
      return "$hour:$minute";
    }

    final yesterday = now.subtract(const Duration(days: 1));

    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    if (isYesterday) {
      return "Kemarin";
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return "$day/$month";
  }

  String getTime(dynamic chat) {
    final date = getChatDate(chat);

    if (date == null) return "";

    return formatTimeFromDate(date);
  }

  String getChatPartnerName(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "User";

    final List<Map<String, dynamic>> candidates = [];

    void addCandidate(dynamic value) {
      final map = toMap(value);

      if (map != null) {
        candidates.add(map);
      }
    }

    addCandidate(data['other_user']);
    addCandidate(data['otherUser']);
    addCandidate(data['participant']);
    addCandidate(data['receiver']);
    addCandidate(data['sender']);
    addCandidate(data['resident']);
    addCandidate(data['customer']);
    addCandidate(data['user']);
    addCandidate(data['owner']);

    if (currentUserId != null) {
      for (final candidate in candidates) {
        final candidateId = toInt(
          candidate['id'] ??
              candidate['user_id'] ??
              candidate['sender_id'] ??
              candidate['receiver_id'],
        );

        final candidateName = getNameFromMap(candidate);

        if (candidateId != null &&
            candidateId != currentUserId &&
            candidateName.isNotEmpty) {
          return candidateName;
        }
      }
    }

    for (final candidate in candidates) {
      final candidateName = getNameFromMap(candidate);

      if (candidateName.isNotEmpty) {
        return candidateName;
      }
    }

    return cleanText(data['name']).isNotEmpty
        ? cleanText(data['name'])
        : cleanText(data['username']).isNotEmpty
        ? cleanText(data['username'])
        : cleanText(data['title']).isNotEmpty
        ? cleanText(data['title'])
        : "User";
  }

  String getPartnerRole(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "Pengguna";

    final owner = toMap(data['owner']);
    final resident = toMap(data['resident']);
    final user = toMap(data['user']);
    final customer = toMap(data['customer']);

    if (currentUserId != null) {
      final ownerId = toInt(owner?['id']);
      final residentId = toInt(resident?['id']);
      final userId = toInt(user?['id']);
      final customerId = toInt(customer?['id']);

      if (ownerId != null && ownerId != currentUserId) {
        return "Pemilik kos";
      }

      if (residentId != null && residentId != currentUserId) {
        return "Penghuni";
      }

      if (customerId != null && customerId != currentUserId) {
        return "Pengguna";
      }

      if (userId != null && userId != currentUserId) {
        return "Pengguna";
      }
    }

    return "Kontak chat";
  }

  String pickPropertyTitleFromMap(Map<String, dynamic>? map) {
    if (map == null) return "";

    final directTitle = cleanText(map['title']).isNotEmpty
        ? cleanText(map['title'])
        : cleanText(map['name']).isNotEmpty
        ? cleanText(map['name'])
        : cleanText(map['property_name']).isNotEmpty
        ? cleanText(map['property_name'])
        : cleanText(map['property_title']).isNotEmpty
        ? cleanText(map['property_title'])
        : cleanText(map['place_property_name']).isNotEmpty
        ? cleanText(map['place_property_name'])
        : cleanText(map['place_property_title']).isNotEmpty
        ? cleanText(map['place_property_title'])
        : cleanText(map['kos_name']).isNotEmpty
        ? cleanText(map['kos_name'])
        : cleanText(map['kos_title']).isNotEmpty
        ? cleanText(map['kos_title'])
        : cleanText(map['kost_name']).isNotEmpty
        ? cleanText(map['kost_name'])
        : cleanText(map['kost_title']);

    if (directTitle.isNotEmpty) return directTitle;

    final property = toMap(map['property']);
    final properties = toMap(map['properties']);
    final placeProperty = toMap(map['place_property']);
    final placePropertyCamel = toMap(map['placeProperty']);
    final placeProperties = toMap(map['place_properties']);
    final placePropertiesCamel = toMap(map['placeProperties']);
    final kos = toMap(map['kos']);
    final kost = toMap(map['kost']);
    final room = toMap(map['room']);
    final place = toMap(map['place']);

    final candidates = [
      property,
      properties,
      placeProperty,
      placePropertyCamel,
      placeProperties,
      placePropertiesCamel,
      kos,
      kost,
      room,
      place,
    ];

    for (final candidate in candidates) {
      final result = pickPropertyTitleFromMap(candidate);

      if (result.isNotEmpty) {
        return result;
      }
    }

    return "";
  }

  String getPropertyName(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final cachedName = cleanText(data['_cached_property_name']);

    if (cachedName.isNotEmpty) {
      return cachedName;
    }

    final dataNested = toMap(data['data']);
    final conversation = toMap(data['conversation']);
    final conversationData = toMap(conversation?['data']);
    final lastMessageMap = getLastMessageMap(chat);
    final lastMessageData = toMap(lastMessageMap?['data']);

    final candidates = [
      data,
      dataNested,
      conversation,
      conversationData,
      lastMessageMap,
      lastMessageData,
    ];

    for (final candidate in candidates) {
      final result = pickPropertyTitleFromMap(candidate);

      if (result.isNotEmpty) {
        return result;
      }
    }

    return "";
  }

  Future<String> fetchPropertyNameById(int propertyId) async {
    if (propertyId <= 0) return "";

    if (propertyNameCache.containsKey(propertyId)) {
      return propertyNameCache[propertyId] ?? "";
    }

    try {
      final token = await ApiService().getToken();

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/properties/$propertyId"),
        headers: {
          "Accept": "application/json",
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
      );

      debugPrint("FETCH PROPERTY NAME STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("FETCH PROPERTY NAME BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final decodedMap = toMap(decoded);
        final data = toMap(decodedMap?['data']) ?? decodedMap;

        final title = pickPropertyTitleFromMap(data);

        if (title.isNotEmpty) {
          propertyNameCache[propertyId] = title;
          return title;
        }
      }
    } catch (e) {
      debugPrint("FETCH PROPERTY NAME ERROR:");
      debugPrint(e.toString());
    }

    propertyNameCache[propertyId] = "";
    return "";
  }

  Future<void> enrichPropertyNames(List<dynamic> chats) async {
    for (final chat in chats) {
      final data = toMap(chat);

      if (data == null) continue;

      final currentName = getPropertyName(chat);

      if (currentName.isNotEmpty) continue;

      final propertyId = getPropertyId(chat);

      if (propertyId <= 0) continue;

      final propertyName = await fetchPropertyNameById(propertyId);

      if (propertyName.isEmpty) continue;

      data['_cached_property_name'] = propertyName;
    }
  }

  int getConversationId(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return 0;

    final conversation = toMap(data['conversation']);

    return toInt(data['id']) ??
        toInt(data['conversation_id']) ??
        toInt(data['conversationId']) ??
        toInt(conversation?['id']) ??
        0;
  }

  int getOwnerId(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return 0;

    final owner = toMap(data['owner']);

    return toInt(data['owner_id']) ?? toInt(owner?['id']) ?? 0;
  }

  int getPropertyId(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return 0;

    int pickIdFromMap(Map<String, dynamic>? map) {
      if (map == null) return 0;

      final property = toMap(map['property']);
      final properties = toMap(map['properties']);
      final placeProperty = toMap(map['place_property']);
      final placePropertyCamel = toMap(map['placeProperty']);
      final placeProperties = toMap(map['place_properties']);
      final placePropertiesCamel = toMap(map['placeProperties']);
      final kos = toMap(map['kos']);
      final kost = toMap(map['kost']);
      final conversation = toMap(map['conversation']);

      return toInt(map['property_id']) ??
          toInt(map['properties_id']) ??
          toInt(map['place_properties_id']) ??
          toInt(map['place_property_id']) ??
          toInt(map['placePropertyId']) ??
          toInt(map['kos_id']) ??
          toInt(map['kost_id']) ??
          toInt(property?['id']) ??
          toInt(properties?['id']) ??
          toInt(placeProperty?['id']) ??
          toInt(placePropertyCamel?['id']) ??
          toInt(placeProperties?['id']) ??
          toInt(placePropertiesCamel?['id']) ??
          toInt(kos?['id']) ??
          toInt(kost?['id']) ??
          toInt(conversation?['property_id']) ??
          toInt(conversation?['place_properties_id']) ??
          toInt(conversation?['place_property_id']) ??
          0;
    }

    final dataNested = toMap(data['data']);
    final conversation = toMap(data['conversation']);
    final conversationData = toMap(conversation?['data']);
    final lastMessageMap = getLastMessageMap(chat);
    final lastMessageData = toMap(lastMessageMap?['data']);

    final candidates = [
      data,
      dataNested,
      conversation,
      conversationData,
      lastMessageMap,
      lastMessageData,
    ];

    for (final candidate in candidates) {
      final id = pickIdFromMap(candidate);

      if (id > 0) {
        return id;
      }
    }

    return 0;
  }

  int? getApiUnreadCount(dynamic chat) {
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
      'owner_unread_count',
      'unread_count_owner',
    ];

    for (final key in keys) {
      if (data.containsKey(key)) {
        return toInt(data[key]) ?? 0;
      }
    }

    final unreadMap = toMap(data['unread_counts']);

    if (unreadMap != null) {
      final ownerUnread =
          toInt(unreadMap['owner']) ??
          toInt(unreadMap['owner_count']) ??
          toInt(unreadMap['current_user']);

      if (ownerUnread != null) {
        return ownerUnread;
      }
    }

    return null;
  }

  int getUnreadCount(dynamic chat) {
    final apiUnread = getApiUnreadCount(chat);

    if (apiUnread != null) return apiUnread;

    final conversationId = getConversationId(chat);

    if (conversationId <= 0) return 0;

    return localUnreadCounts[conversationId] ?? 0;
  }

  String getInitial(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) return "U";

    return cleanName[0].toUpperCase();
  }

  Future<void> openConversation(dynamic chat) async {
    final partnerName = getChatPartnerName(chat);

    int conversationId = getConversationId(chat);

    if (conversationId <= 0) {
      final ownerId = getOwnerId(chat);
      final propertyId = getPropertyId(chat);

      if (ownerId <= 0 || propertyId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Conversation ID, Owner ID, atau Property ID tidak ditemukan.",
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: primaryColor,
          ),
        );

        return;
      }

      final conversation = await ApiService().createOrGetConversation(
        ownerId: ownerId,
        placePropertyId: propertyId,
      );

      if (conversation == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Gagal membuka chat."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: primaryColor,
          ),
        );

        return;
      }

      conversationId =
          toInt(conversation['id']) ??
          toInt(conversation['conversation_id']) ??
          toInt(conversation['conversationId']) ??
          toInt(toMap(conversation['data'])?['id']) ??
          0;
    }

    if (!mounted) return;

    setState(() {
      localUnreadCounts[conversationId] = 0;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Livechatowner(
          conversationId: conversationId,
          username: partnerName,
        ),
      ),
    ).then((_) {
      loadConversations(showLoading: false, notifyNewMessage: false);
    });
  }

  Widget buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.24),
            blurRadius: 24,
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
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Live Chat",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Kelola semua percakapan kos",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              loadConversations(showLoading: true, notifyNewMessage: false);
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.66,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 46,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Chat masih kosong",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF161A33),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Belum ada percakapan yang masuk. Jika ada pengguna yang menghubungi, chat akan muncul di sini.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildChatCard(dynamic chat) {
    final partnerName = getChatPartnerName(chat);
    final role = getPartnerRole(chat);
    final propertyName = getPropertyName(chat);
    final lastMessage = getLastMessage(chat);
    final time = getTime(chat);
    final unreadCount = getUnreadCount(chat);

    final subtitleText = propertyName.isEmpty ? role : "$role • $propertyName";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            openConversation(chat);
          },
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: unreadCount > 0
                  ? Border.all(
                      color: primaryColor.withOpacity(0.22),
                      width: 1.2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: unreadCount > 0
                      ? primaryColor.withOpacity(0.13)
                      : Colors.black.withOpacity(0.055),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          getInitial(partnerName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              partnerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                color: const Color(0xFF161A33),
                              ),
                            ),
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? primaryColor
                                    : Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                unreadCount > 99 ? "99+" : "+$unreadCount",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChatList() {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () {
        return loadConversations(showLoading: false, notifyNewMessage: false);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + (index * 60)),
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
            child: buildChatCard(conversations[index]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : conversations.isEmpty
                  ? RefreshIndicator(
                      color: primaryColor,
                      onRefresh: () {
                        return loadConversations(
                          showLoading: false,
                          notifyNewMessage: false,
                        );
                      },
                      child: buildEmptyState(),
                    )
                  : buildChatList(),
            ),
          ],
        ),
      ),
    );
  }
}
