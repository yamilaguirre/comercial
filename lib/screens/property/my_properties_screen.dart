import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/mobiliaria_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/property.dart';
import '../../theme/theme.dart';
import '../../core/utils/property_constants.dart';

enum PropertyFilter { all, active, paused, expired }

class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  PropertyFilter _currentFilter = PropertyFilter.all;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }



  void _editProperty(Property property) {
    Modular.to.pushNamed('/property/new', arguments: property);
  }

  void _deleteProperty(String propertyId) async {
    await Modular.get<MobiliariaProvider>().deleteProperty(propertyId);
  }

  void _toggleAvailability(String propertyId, bool currentAvailability) async {
    await Modular.get<MobiliariaProvider>()
        .togglePropertyAvailability(propertyId, !currentAvailability);
  }

  void _renewProperty(String propertyId) async {
    await Modular.get<MobiliariaProvider>().renewProperty(propertyId);
  }

  String _getTimeAgo(DateTime? publishedAt) {
    if (publishedAt == null) return 'Hace tiempo';
    
    final now = DateTime.now();
    final difference = now.difference(publishedAt);
    
    if (difference.inMinutes < 1) return 'Hace un momento';
    if (difference.inMinutes < 5) return 'Hace ${difference.inMinutes} minutos';
    if (difference.inMinutes < 15) return 'Hace 15 minutos';
    if (difference.inMinutes < 30) return 'Hace media hora';
    if (difference.inHours < 1) return 'Hace una hora';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} horas';
    if (difference.inDays == 1) return 'Hace 1 día';
    if (difference.inDays < 7) return 'Hace ${difference.inDays} días';
    return 'Hace ${difference.inDays} días';
  }

  List<Property> _filterProperties(List<Property> properties) {
    List<Property> filtered;
    switch (_currentFilter) {
      case PropertyFilter.active:
        filtered = properties.where((p) => p.available).toList();
        break;
      case PropertyFilter.paused:
        filtered = properties.where((p) => !p.available).toList();
        break;
      case PropertyFilter.expired:
        final now = DateTime.now();
        filtered = properties.where((p) {
          if (p.lastPublishedAt == null) return false;
          return now.difference(p.lastPublishedAt!).inDays > 7;
        }).toList();
        break;
      case PropertyFilter.all:
      default:
        filtered = properties;
    }
    
    // Ordenar por fecha de publicación (más reciente primero)
    filtered.sort((a, b) {
      final aDate = a.lastPublishedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.lastPublishedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Mis Publicaciones',
          style: TextStyle(
            color: Styles.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Styles.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Modular.to.navigate('/property/account'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 26),
            onPressed: () => Modular.to.pushNamed('/property/new'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .where('owner_id', isEqualTo: _auth.currentUser?.uid ?? '')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(child: _buildErrorWidget(snapshot.error.toString()));
          }

          final properties = snapshot.data?.docs
                  .map((doc) => Property.fromFirestore(doc))
                  .toList() ??
              [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildStatsDashboard(properties)),
              SliverToBoxAdapter(child: _buildFilterTabs()),
              _buildPropertiesList(properties),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPropertiesList(List<Property> properties) {
    final filteredProperties = _filterProperties(properties);

    if (filteredProperties.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final property = filteredProperties[index];
            return _buildPropertyCard(property, index);
          },
          childCount: filteredProperties.length,
        ),
      ),
    );
  }

  Widget _buildStatsDashboard(List<Property> properties) {
    final activeCount = properties.where((p) => p.available).length;
    final pausedCount = properties.where((p) => !p.available).length;
    final now = DateTime.now();
    final expiredCount = properties.where((p) {
      if (p.lastPublishedAt == null) return false;
      return now.difference(p.lastPublishedAt!).inDays > 7;
    }).length;
    final totalViews = properties.fold<int>(0, (sum, p) => sum + p.views);
    final totalInquiries = properties.fold<int>(
      0,
      (sum, p) => sum + p.inquiries,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Styles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: Styles.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Resumen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Styles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Activas',
                  activeCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Pausadas',
                  pausedCount.toString(),
                  Icons.pause_circle_outline,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Expiradas',
                  expiredCount.toString(),
                  Icons.hourglass_disabled,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(Icons.visibility, '$totalViews', 'Vistas'),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _buildMetric(
                  Icons.chat_bubble_outline,
                  '$totalInquiries',
                  'Consultas',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildMetric(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Styles.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  // Filter Tabs
  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterChip('Todas', PropertyFilter.all),
            _buildFilterChip('Activas', PropertyFilter.active),
            _buildFilterChip('Pausadas', PropertyFilter.paused),
            _buildFilterChip('Expiradas', PropertyFilter.expired),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, PropertyFilter filter) {
    final isSelected = _currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _currentFilter = filter);
        },
        backgroundColor: Colors.white,
        selectedColor: Styles.primaryColor,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Styles.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        elevation: isSelected ? 4 : 1,
        shadowColor: Styles.primaryColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Styles.primaryColor : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Property property, int index) {
    final timeAgo = _getTimeAgo(property.lastPublishedAt);
    final isOld = property.lastPublishedAt != null &&
        DateTime.now().difference(property.lastPublishedAt!).inDays > 7;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: property.available ? Colors.white : Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildStatusBar(isOld, timeAgo, property.id),

            // Property Content
            InkWell(
              onTap: () => Modular.to.pushNamed(
                '/property/detail/${property.id}',
                arguments: property,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image with Hero Animation and Switch
                    Stack(
                      children: [
                        Hero(
                          tag: 'property_${property.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              property.imageUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey.shade300,
                              ),
                            );
                          },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: property.available,
                                onChanged: (value) =>
                                    _toggleAvailability(property.id, property.available),
                                activeColor: Styles.primaryColor,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Styles.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            property.price,
                            style: const TextStyle(
                              color: Styles.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  property.location,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Analytics
                          Row(
                            children: [
                              _buildAnalyticBadge(
                                Icons.visibility,
                                property.views,
                              ),
                              const SizedBox(width: 12),
                              _buildAnalyticBadge(
                                Icons.chat_bubble_outline,
                                property.inquiries,
                              ),
                              const SizedBox(width: 12),
                              _buildAnalyticBadge(
                                Icons.favorite_border,
                                property.favorite,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Actions Column
                    _buildActionButtons(property),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(bool isOld, String timeAgo, String propertyId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isOld ? Colors.orange.shade400 : Colors.green.shade400,
            isOld ? Colors.orange.shade300 : Colors.green.shade300,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            isOld ? Icons.access_time : Icons.check_circle_outline,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOld ? 'Tu publicación es antigua' : timeAgo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () => _renewProperty(propertyId),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: Styles.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'Renovar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Styles.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticBadge(IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Property property) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.edit_outlined,
          color: Colors.blue,
          onTap: () => _editProperty(property),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.delete_outline,
          color: Colors.red,
          onTap: () =>
              _showDeleteConfirmation(context, property.id, property.name),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // Shimmer Loaders
  Widget _buildStatsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildPropertyShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    String message = 'No tienes propiedades';
    IconData icon = Icons.house_siding;

    switch (_currentFilter) {
      case PropertyFilter.active:
        message = 'No tienes propiedades activas';
        icon = Icons.do_not_disturb_alt;
        break;
      case PropertyFilter.paused:
        message = 'No tienes propiedades pausadas';
        icon = Icons.play_circle_outline;
        break;
      case PropertyFilter.expired:
        message = 'No tienes propiedades expiradas';
        icon = Icons.celebration;
        break;
      default:
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          if (_currentFilter == PropertyFilter.all)
            ElevatedButton.icon(
              onPressed: () => Modular.to.pushNamed('/property/new'),
              icon: const Icon(Icons.add_home_work),
              label: const Text('Publicar Ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
        ],
      ),
    );
  }

  // Error Widget
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Confirmation
  void _showDeleteConfirmation(
    BuildContext context,
    String propertyId,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber, color: Colors.red.shade400),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar Publicación'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar "$name"?\nEsta acción no se puede deshacer.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProperty(propertyId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
