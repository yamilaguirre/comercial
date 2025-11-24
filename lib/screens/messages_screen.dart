import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Lista de conversaciones
  final List<Map<String, dynamic>> conversations = [
    {
      'name': 'María González',
      'status': 'En línea',
      'avatar': 'https://i.pravatar.cc/150?img=1',
      'propertyImage': 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=100&h=100&fit=crop',
      'propertyName': 'Departamento',
      'propertyPrice': '890,000 Bs',
      'propertyDetails': '2 hab • 1 baño • 75 m²',
      'propertyLocation': 'San Miguel, La Paz',
      'lastMessage': 'Sí, aún está disponible 🏠 ¿Quieres agendar una visita?',
      'timestamp': '10:32',
      'unreadCount': 2,
      'isOnline': true,
    },
    {
      'name': 'Carlos Ramírez',
      'status': 'Desconectado',
      'avatar': 'https://i.pravatar.cc/150?img=12',
      'propertyImage': 'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=100&h=100&fit=crop',
      'propertyName': 'Casa',
      'propertyPrice': '1,500,000 Bs',
      'propertyDetails': '4 hab • 3 baños • 180 m²',
      'propertyLocation': 'Zona Sur, La Paz',
      'lastMessage': 'Perfecto, nos vemos el viernes',
      'timestamp': 'Ayer',
      'unreadCount': 0,
      'isOnline': false,
    },
    {
      'name': 'Ana Martínez',
      'status': 'En línea',
      'avatar': 'https://i.pravatar.cc/150?img=5',
      'propertyImage': 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=100&h=100&fit=crop',
      'propertyName': 'Departamento',
      'propertyPrice': '650,000 Bs',
      'propertyDetails': '1 hab • 1 baño • 55 m²',
      'propertyLocation': 'Sopocachi, La Paz',
      'lastMessage': 'Gracias por la información',
      'timestamp': '12/11',
      'unreadCount': 0,
      'isOnline': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Buzón',
          style: TextStyles.title.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Styles.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: Styles.spacingMedium),
                  Text(
                    'No tienes mensajes',
                    style: TextStyles.subtitle.copyWith(
                      color: Styles.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                return _buildConversationCard(conversations[index]);
              },
            ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    return InkWell(
      onTap: () {
        // TODO: Implementar navegación a chat real con Firebase
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat con ${conversation['name']}'),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(Styles.spacingMedium),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar con indicador de online
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(conversation['avatar']),
                ),
                if (conversation['isOnline'])
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: Styles.spacingMedium),

            // Información de la conversación
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        conversation['name'],
                        style: TextStyles.body.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Styles.textPrimary,
                        ),
                      ),
                      Text(
                        conversation['timestamp'],
                        style: TextStyles.caption.copyWith(
                          fontSize: 12,
                          color: Styles.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    conversation['status'],
                    style: TextStyles.caption.copyWith(
                      fontSize: 12,
                      color: conversation['isOnline'] ? Colors.green : Styles.textSecondary,
                    ),
                  ),
                  SizedBox(height: Styles.spacingSmall),
                  
                  // Tarjeta de propiedad mini
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            conversation['propertyImage'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: Styles.spacingSmall),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conversation['propertyName'],
                                style: TextStyles.caption.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                conversation['propertyPrice'],
                                style: TextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: Styles.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                conversation['propertyDetails'],
                                style: TextStyles.caption.copyWith(
                                  fontSize: 10,
                                  color: Styles.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Styles.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_red_eye, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              const Icon(Icons.share, size: 10, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: Styles.spacingSmall),
                  
                  // Último mensaje
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation['lastMessage'],
                          style: TextStyles.caption.copyWith(
                            fontSize: 13,
                            color: conversation['unreadCount'] > 0
                                ? Styles.textPrimary
                                : Styles.textSecondary,
                            fontWeight: conversation['unreadCount'] > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation['unreadCount'] > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Styles.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            conversation['unreadCount'].toString(),
                            style: TextStyles.caption.copyWith(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
