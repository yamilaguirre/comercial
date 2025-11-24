// screens/voicemail_screen.dart
import 'package:flutter/material.dart';
import '../services/voicemail_service.dart';
import '../models/voicemail_model.dart';

class VoicemailScreen extends StatefulWidget {
  final String userId;

  const VoicemailScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<VoicemailScreen> createState() => _VoicemailScreenState();
}

class _VoicemailScreenState extends State<VoicemailScreen> {
  final VoicemailService _voicemailService = VoicemailService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buzón de Voz'),
        actions: [
          StreamBuilder<int>(
            stream: _voicemailService.getUnreadCount(widget.userId),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count > 0) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '$count nuevos',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Voicemail>>(
        stream: _voicemailService.getUserVoicemails(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final voicemails = snapshot.data ?? [];

          if (voicemails.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.voicemail, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tienes mensajes de voz'),
                  Text('Los mensajes de voz de tus clientes aparecerán aquí'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: voicemails.length,
            itemBuilder: (context, index) {
              final voicemail = voicemails[index];
              return VoicemailCard(
                voicemail: voicemail,
                onTap: () => _openVoicemail(voicemail),
              );
            },
          );
        },
      ),
    );
  }

  void _openVoicemail(Voicemail voicemail) {
    if (!voicemail.isRead) {
      _voicemailService.markAsRead(voicemail.id);
    }

    showDialog(
      context: context,
      builder: (context) => VoicemailDialog(voicemail: voicemail),
    );
  }
}

class VoicemailCard extends StatelessWidget {
  final Voicemail voicemail;
  final VoidCallback onTap;

  const VoicemailCard({
    Key? key,
    required this.voicemail,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: voicemail.isRead ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: voicemail.isRead ? Colors.grey : Colors.blue,
          child: Icon(
            Icons.voicemail,
            color: Colors.white,
          ),
        ),
        title: Text(
          voicemail.fromName,
          style: TextStyle(
            fontWeight: voicemail.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              voicemail.transcript,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${voicemail.durationSeconds}s',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatDate(voicemail.createdAt),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: !voicemail.isRead
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}

class VoicemailDialog extends StatelessWidget {
  final Voicemail voicemail;

  const VoicemailDialog({Key? key, required this.voicemail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mensaje de ${voicemail.fromName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 8),
              Text('Duración: ${voicemail.durationSeconds} segundos'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Transcripción:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(voicemail.transcript),
          const SizedBox(height: 16),
          // Aquí iría el reproductor de audio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    // Implementar reproducción de audio
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reproduciendo audio...')),
                    );
                  },
                ),
                const Text('Reproducir mensaje'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (voicemail.propertyId != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/property-detail', arguments: voicemail.propertyId);
            },
            child: const Text('Ver Propiedad'),
          ),
      ],
    );
  }
}