import 'package:flutter/material.dart';
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

  List<dynamic> messages = [];

  bool isLoading = true;
  bool isSending = false;

  int? currentUserId;

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
      });
    } catch (e) {
      debugPrint("LOAD CURRENT USER ERROR: $e");
    }
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
        messages = result;
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
      messages.add(tempMessage);
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

  void showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryColor,
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
      return true;
    }

    final from = message['from']?.toString().toLowerCase() ?? "";

    if (from == "me" || from == "resident" || from == "user") {
      return true;
    }

    return false;
  }

  bool isSendingMessage(dynamic message) {
    if (message is! Map) return false;

    return message['sending'] == true;
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
              "Mulai percakapan dengan pemilik kos untuk menanyakan ketersediaan, fasilitas, atau aturan kos.",
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
                      "Pemilik kos",
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
