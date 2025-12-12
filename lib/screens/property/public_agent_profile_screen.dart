import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chaski_comercial/services/ad_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../models/property.dart';
import '../../services/agent_stats_service.dart';

class PublicAgentProfileScreen extends StatefulWidget {
  final String userId;

  const PublicAgentProfileScreen({super.key, required this.userId});

  @override
  State<PublicAgentProfileScreen> createState() =>
      _PublicAgentProfileScreenState();
}

class _PublicAgentProfileScreenState extends State<PublicAgentProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _userData;
  List<Property> _userProperties = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  final AgentStatsService _statsService = AgentStatsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // 1. Cargar datos del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data();
      }

      // 2. Cargar propiedades del usuario (usando query directa para ser más seguro con IDs ajenos)
      final propertiesSnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('owner_id', isEqualTo: widget.userId)
          .where('is_active', isEqualTo: true) // Solo activas
          .orderBy('created_at', descending: true)
          .get();

      _userProperties = propertiesSnapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();

      // 3. Cargar estadísticas
      _stats = await _statsService.getAgentStats(widget.userId);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading agent profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo lanzar $uri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la aplicación: $e')),
        );
      }
    }
  }

  Future<void> _contactAgent(String type) async {
    if (_userData == null) return;
    final phone = _userData?['phoneNumber'] as String? ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final finalPhone = (cleanPhone.length == 8 && !cleanPhone.startsWith('591'))
        ? '591$cleanPhone'
        : cleanPhone;

    if (type == 'call') {
      if (finalPhone.isNotEmpty) {
        await _launchUrl(Uri.parse('tel:$finalPhone'));
      }
    } else if (type == 'whatsapp') {
      if (finalPhone.isNotEmpty) {
        final message = Uri.encodeComponent(
          'Hola ${_userData?['displayName'] ?? ''}, vi tu perfil en Comercial y me gustaría consultarte.',
        );
        await AdService.instance.showInterstitialThen(() async {
          await _launchUrl(Uri.parse('https://wa.me/$finalPhone?text=$message'));
        });
      }
    } else if (type == 'email') {
      final email = _userData?['email'] as String? ?? '';
      if (email.isNotEmpty) {
        await _launchUrl(Uri.parse('mailto:$email'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Styles.primaryColor),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil no encontrado')),
        body: const Center(
          child: Text('Lo sentimos, no pudimos cargar el perfil.'),
        ),
      );
    }

    final displayName = _userData?['displayName'] ?? 'Usuario';
    final photoUrl = _userData?['photoURL'] ?? _userData?['photoUrl'];
    final role = _userData?['role'] == 'inmobiliaria'
        ? 'Agente Inmobiliario'
        : 'Propietario';
    final about = _userData?['about'] ?? 'Sin descripción disponible.';

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300.0,
              floating: false,
              pinned: true,
              backgroundColor: Styles.primaryColor,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Modular.to.pop(),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fondo con gradiente o imagen de portada si existiera
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Styles.primaryColor,
                            Styles.primaryColor.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    // Patrón decorativo (opcional)
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center, // Align vertically
                        children: [
                          // 1. Avatar (Hero)
                          Hero(
                            tag: 'profile_${widget.userId}',
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? Text(
                                        displayName[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Styles.primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // 2. Info & Stats (Column)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre + Verificado
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Rol
                                Text(
                                  role,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Estadísticas (Alineadas a la izquierda, en fila)
                                Row(
                                  children: [
                                    _buildHeaderStatCompact(
                                      _userProperties.length.toString(),
                                      'Propiedades',
                                    ),
                                    Container(
                                      height: 24,
                                      width: 1,
                                      color: Colors.white.withOpacity(0.3),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    _buildHeaderStatCompact(
                                      _formatNumber(_stats['totalViews'] ?? 0),
                                      'Vistas',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                tabs: const [
                  Tab(text: 'Sobre mí'),
                  Tab(text: 'Propiedades'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Sobre mí
            _buildAboutTab(about),
            // Tab 2: Propiedades
            _buildPropertiesTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomContactBar(),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHeaderStatCompact(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAboutTab(String description) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Biografía'),
          const SizedBox(height: 12),
          Text(
            description.isEmpty || description == 'null'
                ? 'Sin información adicional.'
                : description,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Información de Contacto'),
          const SizedBox(height: 16),
          _buildContactTile(
            Icons.email_outlined,
            'Correo Electrónico',
            _userData?['email'] ?? 'No disponible',
            () => _contactAgent('email'),
          ),
          const SizedBox(height: 16),
          _buildContactTile(
            Icons.phone_outlined,
            'Teléfono',
            _userData?['phoneNumber'] ?? 'No disponible',
            () => _contactAgent('call'),
          ),
          const SizedBox(height: 80), // Espacio para el bottom bar
        ],
      ),
    );
  }

  Widget _buildContactTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Styles.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Styles.primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesTab() {
    if (_userProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.house_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay propiedades publicadas',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: _userProperties.length,
      itemBuilder: (context, index) {
        return _buildPropertyCard(_userProperties[index]);
      },
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Modular.to.pushNamed('/property/detail/${property.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Imagen
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        property.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Styles.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            property.price,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Contenido
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFeature(
                          Icons.bed_outlined,
                          '${property.bedrooms}',
                        ),
                        _buildFeature(
                          Icons.bathtub_outlined,
                          '${property.bathrooms}',
                        ),
                        _buildFeature(
                          Icons.square_foot,
                          '${property.area.round()} m²',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBottomContactBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Llamar',
                Icons.phone,
                Colors.white,
                Colors.black87,
                Colors.grey.shade300,
                () => _contactAgent('call'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'WhatsApp',
                FontAwesomeIcons.whatsapp,
                Colors.white,
                const Color(0xFF25D366),
                const Color(0xFF25D366),
                () => _contactAgent('whatsapp'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color bgColor,
    Color contentColor,
    Color borderColor,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: contentColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: contentColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: contentColor),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
