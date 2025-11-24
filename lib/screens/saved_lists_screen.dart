// screens/saved_lists_screen.dart
import 'package:flutter/material.dart';
import '../services/saved_list_service.dart';
import '../services/property_service.dart';
import '../models/saved_list_model.dart';
import '../models/property_model.dart';

class SavedListsScreen extends StatefulWidget {
  final String userId;

  const SavedListsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<SavedListsScreen> createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen> {
  final SavedListService _savedListService = SavedListService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listas Guardadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateListDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<SavedList>>(
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
                  Text('No tienes listas guardadas'),
                  Text('Crea tu primera lista para organizar tus propiedades favoritas'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: savedLists.length,
            itemBuilder: (context, index) {
              final savedList = savedLists[index];
              return SavedListCard(
                savedList: savedList,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavedListDetailScreen(savedList: savedList),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateListDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Lista'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la lista',
            hintText: 'Ej: Mis Favoritos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
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
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class SavedListCard extends StatelessWidget {
  final SavedList savedList;
  final VoidCallback onTap;

  const SavedListCard({
    Key? key,
    required this.savedList,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.blue),
        title: Text(savedList.listName),
        subtitle: Text('${savedList.propertyIds.length} propiedades'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

class SavedListDetailScreen extends StatelessWidget {
  final SavedList savedList;

  const SavedListDetailScreen({Key? key, required this.savedList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SavedListService savedListService = SavedListService();

    return Scaffold(
      appBar: AppBar(
        title: Text(savedList.listName),
      ),
      body: FutureBuilder<List<Property>>(
        future: savedListService.getPropertiesFromSavedList(savedList.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final properties = snapshot.data ?? [];

          if (properties.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Esta lista está vacía'),
                  Text('Agrega propiedades desde la pantalla principal'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final property = properties[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(property.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${property.price} ${property.currency}'),
                      Text('${property.areaSqm} m² - ${property.rooms} hab'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () async {
                      await savedListService.removePropertyFromList(
                        savedList.id,
                        property.id,
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/property-detail', arguments: property.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}