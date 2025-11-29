import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme.dart';
import '../../../services/chat_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/chat_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: Styles.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Buzón',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar conversaciones...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Lista de conversaciones
          Expanded(
            child: StreamBuilder<List<Chat>>(
              stream: _chatService.getUserChats(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes conversaciones',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filtrar chats por búsqueda
                final filteredChats = chats.where((chat) {
                  if (_searchQuery.isEmpty) return true;
                  return chat.lastMessage.toLowerCase().contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final otherUserId = chat.userIds.firstWhere(
                      (id) => id != currentUserId,
                      orElse: () => '',
                    );

                    // Validar que hay otro usuario en el chat
                    if (otherUserId.isEmpty) {
                      return const SizedBox.shrink(); // No mostrar si es chat inválido
                    }

                    return _ChatListItem(
                      chat: chat,
                      otherUserId: otherUserId,
                      currentUserId: currentUserId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final Chat chat;
  final String otherUserId;
  final String currentUserId;

  const _ChatListItem({
    required this.chat,
    required this.otherUserId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['displayName'] ?? 'Usuario';
        final userPhoto = userData?['photoURL'];

        // Calcular tiempo transcurrido
        final now = DateTime.now();
        final difference = now.difference(chat.lastUpdated);
        String timeAgo;
        if (difference.inMinutes < 1) {
          timeAgo = 'Ahora';
        } else if (difference.inHours < 1) {
          timeAgo = '${difference.inMinutes}m';
        } else if (difference.inDays < 1) {
          timeAgo = '${difference.inHours}h';
        } else if (difference.inDays < 7) {
          timeAgo = 'Hace ${difference.inDays}d';
        } else {
          timeAgo = 'Hace ${(difference.inDays / 7).floor()}sem';
        }

        return InkWell(
          onTap: () {
            Modular.to.pushNamed(
              '/worker/chat-detail',
              arguments: {
                'chatId': chat.id,
                'otherUserId': otherUserId,
                'otherUserName': userName,
                'otherUserPhoto': userPhoto,
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Styles.primaryColor.withOpacity(0.1),
                  backgroundImage: userPhoto != null
                      ? NetworkImage(userPhoto)
                      : null,
                  child: userPhoto == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: TextStyle(
                            color: Styles.primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Información del chat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Indicador de mensaje no leído - solo si hay no leídos
                              if (chat.getUnreadCount(currentUserId) > 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Styles.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
