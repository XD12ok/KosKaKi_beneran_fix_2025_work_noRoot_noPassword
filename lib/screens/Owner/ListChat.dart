import 'package:flutter/material.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/LiveChatOwner.dart';

class ChatListOwnerPage extends StatefulWidget {
  const ChatListOwnerPage({super.key});

  @override
  State<ChatListOwnerPage> createState() => _ChatListOwnerPageState();
}

class _ChatListOwnerPageState extends State<ChatListOwnerPage> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color backgroundColor = const Color(0xFFF7F8FF);

  List<dynamic> conversations = [];

  bool isLoading = true;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    loadConversations();
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

  String getNameFromMap(Map<String, dynamic>? data) {
    if (data == null) return "";

    return data['name']?.toString() ??
        data['username']?.toString() ??
        data['full_name']?.toString() ??
        "";
  }

  Future<void> loadConversations() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = await ApiService().getUser();
      final result = await ApiService().getConversations();

      final userMap = toMap(user);
      final dataUserMap = toMap(userMap?['data']);
      final nestedUserMap = toMap(userMap?['user']);

      final id =
          toInt(userMap?['id']) ??
          toInt(dataUserMap?['id']) ??
          toInt(nestedUserMap?['id']);

      if (!mounted) return;

      setState(() {
        currentUserId = id;
        conversations = result;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("LOAD CONVERSATIONS ERROR: $e");

      if (!mounted) return;

      setState(() {
        conversations = [];
        isLoading = false;
      });
    }
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

    return data['name']?.toString() ??
        data['username']?.toString() ??
        data['title']?.toString() ??
        "User";
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

  String getPropertyName(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final property = toMap(data['property']);
    final placeProperty = toMap(data['place_property']);

    return property?['title']?.toString() ??
        property?['name']?.toString() ??
        placeProperty?['title']?.toString() ??
        placeProperty?['name']?.toString() ??
        data['property_name']?.toString() ??
        data['place_property_name']?.toString() ??
        "";
  }

  String getLastMessage(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "Belum ada pesan";

    final lastMessage =
        data['last_message'] ??
        data['lastMessage'] ??
        data['latest_message'] ??
        data['message'];

    final lastMessageMap = toMap(lastMessage);

    if (lastMessageMap != null) {
      return lastMessageMap['message']?.toString() ??
          lastMessageMap['body']?.toString() ??
          lastMessageMap['text']?.toString() ??
          lastMessageMap['content']?.toString() ??
          "Belum ada pesan";
    }

    if (lastMessage != null && lastMessage.toString().trim().isNotEmpty) {
      return lastMessage.toString();
    }

    return "Belum ada pesan";
  }

  String formatTime(String rawTime) {
    if (rawTime.trim().isEmpty) return "";

    final parsed = DateTime.tryParse(rawTime);

    if (parsed == null) return rawTime;

    final local = parsed.toLocal();
    final now = DateTime.now();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (isToday) {
      return "$hour:$minute";
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return "$day/$month";
  }

  String getTime(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return "";

    final lastMessage =
        data['last_message'] ?? data['lastMessage'] ?? data['latest_message'];

    final lastMessageMap = toMap(lastMessage);

    final rawTime =
        lastMessageMap?['created_at']?.toString() ??
        data['updated_at']?.toString() ??
        data['created_at']?.toString() ??
        data['time']?.toString() ??
        "";

    return formatTime(rawTime);
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

    final property = toMap(data['property']);
    final placeProperty = toMap(data['place_property']);

    return toInt(data['place_property_id']) ??
        toInt(data['property_id']) ??
        toInt(property?['id']) ??
        toInt(placeProperty?['id']) ??
        0;
  }

  int getUnreadCount(dynamic chat) {
    final data = toMap(chat);

    if (data == null) return 0;

    return toInt(data['unread_count']) ??
        toInt(data['unread']) ??
        toInt(data['total_unread']) ??
        0;
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Livechatowner(
          conversationId: conversationId,
          username: partnerName,
        ),
      ),
    ).then((_) {
      loadConversations();
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
            onPressed: loadConversations,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.055),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF161A33),
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
                        propertyName.isEmpty ? role : "$role • $propertyName",
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
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? "99+"
                                    : unreadCount.toString(),
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
      onRefresh: loadConversations,
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
                      onRefresh: loadConversations,
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
