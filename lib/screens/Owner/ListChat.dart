import 'package:flutter/material.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/LiveChatOwner.dart';

class ChatListOwnerPage extends StatefulWidget {
  const ChatListOwnerPage({super.key});

  @override
  State<ChatListOwnerPage> createState() => _ChatListOwnerPageState();
}

class _ChatListOwnerPageState extends State<ChatListOwnerPage> {
  List<dynamic> conversations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadConversations();
  }

  Future<void> loadConversations() async {
    final result = await ApiService().getConversations();

    setState(() {
      conversations = result;
      isLoading = false;
    });
  }

  String getUserName(dynamic chat) {
    if (chat['user'] != null) {
      return chat['user']['name'] ?? 'User';
    }

    if (chat['resident'] != null) {
      return chat['resident']['name'] ?? 'User';
    }

    if (chat['customer'] != null) {
      return chat['customer']['name'] ?? 'User';
    }

    return chat['name'] ?? 'User';
  }

  String getLastMessage(dynamic chat) {
    if (chat['last_message'] != null) {
      return chat['last_message'].toString();
    }

    if (chat['lastMessage'] != null) {
      return chat['lastMessage'].toString();
    }

    return 'Belum ada pesan';
  }

  String getTime(dynamic chat) {
    if (chat['time'] != null) {
      return chat['time'].toString();
    }

    if (chat['updated_at'] != null) {
      return chat['updated_at'].toString();
    }

    return '';
  }

  int getConversationId(dynamic chat) {
    return int.parse(chat['id'].toString());
  }

  int getOwnerId(dynamic chat) {
    if (chat['owner_id'] != null) {
      return int.parse(chat['owner_id'].toString());
    }

    if (chat['owner'] != null && chat['owner']['id'] != null) {
      return int.parse(chat['owner']['id'].toString());
    }

    return 0;
  }

  int getPropertyId(dynamic chat) {
    if (chat['place_property_id'] != null) {
      return int.parse(chat['place_property_id'].toString());
    }

    if (chat['property_id'] != null) {
      return int.parse(chat['property_id'].toString());
    }

    if (chat['property'] != null && chat['property']['id'] != null) {
      return int.parse(chat['property']['id'].toString());
    }

    return 0;
  }

  Future<void> openConversation(dynamic chat) async {
    final ownerId = getOwnerId(chat);
    final propertyId = getPropertyId(chat);

    if (ownerId == 0 || propertyId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owner ID atau Property ID tidak ditemukan'),
        ),
      );
      return;
    }

    final conversation = await ApiService().createOrGetConversation(
      ownerId: ownerId,
      placePropertyId: propertyId,
    );

    if (conversation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuka chat')));
      return;
    }

    final conversationId = int.parse(conversation['id'].toString());

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Livechatowner(
          conversationId: conversationId,
          username: getUserName(chat),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Live Chat',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chat masih kosong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada user yang menghubungi anda',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadConversations,
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final chat = conversations[index];

                  return InkWell(
                    onTap: () {
                      openConversation(chat);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey.shade300,
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getUserName(chat),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  getLastMessage(chat),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            getTime(chat),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
