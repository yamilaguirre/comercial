import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../services/saved_list_service.dart';
import '../models/saved_list_model.dart';

class FavoritesScreen extends StatefulWidget {
  final String userId;
  
  const FavoritesScreen({super.key, required this.userId});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String selectedTab = 'Todo Guardado';
  int selectedFilter = 0;
  final SavedListService _savedListService = SavedListService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Guardados',
          style: TextStyles.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Styles.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs: Todo Guardado / Mis Colecciones
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Styles.spacingMedium,
              vertical: Styles.spacingSmall,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Todo Guardado'),
                ),
                SizedBox(width: Styles.spacingSmall),
                Expanded(
                  child: _buildTabButton('Mis Colecciones'),
                ),
              ],
            ),
          ),

          // Filtros: Guardados, Contactados, Por contactar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
            child: Row(
              children: [
                _buildFilterChip(Icons.favorite, 'Guardados', 0, 0),
                SizedBox(width: Styles.spacingSmall),
                _buildFilterChip(Icons.check_circle_outline, 'Contactados', 1, 0),
                SizedBox(width: Styles.spacingSmall),
                _buildFilterChip(Icons.phone_outlined, 'P...', 2, 0),
              ],
            ),
          ),

          SizedBox(height: Styles.spacingMedium),

          // Botón Crear nueva colección
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
            child: GestureDetector(
              onTap: () {
                _showCreateCollectionDialog();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: Styles.spacingMedium,
                  horizontal: Styles.spacingMedium,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Styles.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: Styles.primaryColor,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: Styles.spacingSmall),
                    Text(
                      'Crear nueva colección',
                      style: TextStyle(
                        color: const Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: Styles.spacingMedium),

          // Lista de colecciones desde Firebase
          Expanded(
            child: StreamBuilder<List<SavedList>>(
              stream: _savedListService.getUserSavedLists(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final savedLists = snapshot.data ?? [];
                
                if (savedLists.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No tienes colecciones guardadas'),
                        Text('Crea tu primera colección'),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
                  itemCount: savedLists.length,
                  itemBuilder: (context, index) {
                    return _buildCollectionCard(savedLists[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title) {
    final isSelected = selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = title),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Styles.spacingSmall),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: isSelected ? Styles.textPrimary : Styles.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(IconData icon, String label, int index, int count) {
    final isSelected = selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = index),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Styles.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Styles.primaryColor : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (count > 0) ...[
                SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.25) : Styles.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Styles.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(SavedList savedList) {
    return Container(
      margin: EdgeInsets.only(bottom: Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen de la colección
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Container(
              width: 120,
              height: 120,
              color: const Color(0xFFF3F4F6),
              child: Icon(Icons.collections_outlined, size: 48, color: const Color(0xFF9CA3AF)),
            ),
          ),

          // Información de la colección
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(Styles.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savedList.listName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${savedList.propertyIds.length} ${savedList.propertyIds.length == 1 ? 'propiedad' : 'propiedades'}',
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _showEditCollectionDialog(savedList);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: const Color(0xFF6B7280)),
                              SizedBox(width: 4),
                              Text(
                                'Editar',
                                style: TextStyle(
                                  color: const Color(0xFF374151),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: Styles.spacingSmall),
                      GestureDetector(
                        onTap: () {
                          _showDeleteCollectionDialog(savedList);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear nueva colección'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Nombre de la colección',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _savedListService.createSavedList(
                  widget.userId,
                  nameController.text,
                  [],
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Styles.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showEditCollectionDialog(SavedList savedList) {
    final nameController = TextEditingController(text: savedList.listName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar colección'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Nombre de la colección',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implementar edición en Firebase
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Styles.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCollectionDialog(SavedList savedList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar colección'),
        content: Text('¿Estás seguro de que quieres eliminar "${savedList.listName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implementar eliminación en Firebase
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
