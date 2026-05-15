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

  List<dynamic> messages = [];
  bool isLoading = true;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    final result = await ApiService().getConversationMessages(
      widget.conversationId,
    );

    setState(() {
      messages = result;
      isLoading = false;
    });

    scrollToBottom();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      isSending = true;
    });

    final result = await ApiService().sendConversationMessage(
      conversationId: widget.conversationId,
      message: text,
    );

    if (result != null) {
      messageController.clear();
      await loadMessages();
    }

    setState(() {
      isSending = false;
    });
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  String getMessageText(dynamic message) {
    if (message['message'] != null) {
      return message['message'].toString();
    }

    if (message['body'] != null) {
      return message['body'].toString();
    }

    if (message['text'] != null) {
      return message['text'].toString();
    }

    return '';
  }

  String getMessageTime(dynamic message) {
    if (message['time'] != null) {
      return message['time'].toString();
    }

    if (message['created_at'] != null) {
      return message['created_at'].toString();
    }

    return '';
  }

  bool isMyMessage(dynamic message) {
    if (message['is_me'] != null) {
      return message['is_me'] == true;
    }

    if (message['sender_type'] != null) {
      return message['sender_type'].toString().toLowerCase() == 'owner';
    }

    if (message['from'] != null) {
      return message['from'].toString().toLowerCase() == 'owner';
    }

    return false;
  }

  Widget buildMessageBubble(dynamic message) {
    final mine = isMyMessage(message);

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine ? Colors.green.shade100 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: mine ? null : Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  getMessageText(message),
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  getMessageTime(message),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffECE5DD),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, color: Colors.black54),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                const Text(
                  'Online',
                  style: TextStyle(color: Colors.green, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada pesan',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadMessages,
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return buildMessageBubble(messages[index]);
                      },
                    ),
                  ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isSending ? null : sendMessage,
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
