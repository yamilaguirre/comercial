import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/property.dart';
import '../../theme/theme.dart';

class InmobiliariaPropertiesScreen extends StatefulWidget {
  const InmobiliariaPropertiesScreen({super.key});

  @override
  State<InmobiliariaPropertiesScreen> createState() => _InmobiliariaPropertiesScreenState();
}

class _InmobiliariaPropertiesScreenState extends State<InmobiliariaPropertiesScreen> {
  final AuthService _authService = Modular.get<AuthService>();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mis Propiedades'),
        backgroundColor: Styles.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Todas')),
              const PopupMenuItem(value: 'active', child: Text('Activas')),
              const PopupMenuItem(value: 'paused', child: Text('Pausadas')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPropertiesStream(user?.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 80, color: Colors.grey[400]),
                  SizedBox(height: Styles.spacingMedium),
                  Text(
                    'No tienes propiedades publicadas',
                    style: TextStyles.subtitle.copyWith(color: Styles.textSecondary),
                  ),
                  SizedBox(height: Styles.spacingLarge),
                  ElevatedButton.icon(
                    onPressed: () => Modular.to.pushNamed('/inmobiliaria/new-property'),
                    icon: const Icon(Icons.add),
                    label: const Text('Publicar Propiedad'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: Styles.spacingLarge,
                        vertical: Styles.spacingMedium,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final properties = snapshot.data!.docs
              .map((doc) => Property.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: EdgeInsets.all(Styles.spacingMedium),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final property = properties[index];
              return _buildPropertyCard(property);
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getPropertiesStream(String? userId) {
    if (userId == null) return const Stream.empty();

    var query = FirebaseFirestore.instance
        .collection('properties')
        .where('userId', isEqualTo: userId);

    if (_filter == 'active') {
      query = query.where('status', isEqualTo: 'active');
    } else if (_filter == 'paused') {
      query = query.where('status', isEqualTo: 'paused');
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: EdgeInsets.only(bottom: Styles.spacingMedium),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Modular.to.pushNamed('/property/detail/${property.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(Styles.spacingMedium),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: property.imageUrl.isNotEmpty
                      ? Image.network(
                          property.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.home, size: 40, color: Colors.grey),
                        )
                      : const Icon(Icons.home, size: 40, color: Colors.grey),
                ),
              ),
              SizedBox(width: Styles.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: TextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location,
                      style: TextStyles.caption.copyWith(
                        color: Styles.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          property.price,
                          style: TextStyles.body.copyWith(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: property.status == 'active'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            property.status == 'active' ? 'Activa' : 'Pausada',
                            style: TextStyles.caption.copyWith(
                              color: property.status == 'active'
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showPropertyOptions(property),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPropertyOptions(Property property) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(context);
                Modular.to.pushNamed('/property/new', arguments: property);
              },
            ),
            ListTile(
              leading: Icon(
                property.status == 'active' ? Icons.pause : Icons.play_arrow,
              ),
              title: Text(property.status == 'active' ? 'Pausar' : 'Activar'),
              onTap: () {
                Navigator.pop(context);
                _togglePropertyStatus(property);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteProperty(property);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePropertyStatus(Property property) async {
    final newStatus = property.status == 'active' ? 'paused' : 'active';
    await FirebaseFirestore.instance
        .collection('properties')
        .doc(property.id)
        .update({'status': newStatus});
  }

  Future<void> _deleteProperty(Property property) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar propiedad'),
        content: const Text('¿Estás seguro de eliminar esta propiedad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .delete();
    }
  }
}
