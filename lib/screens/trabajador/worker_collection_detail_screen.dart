import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/saved_collection_model.dart';
import '../../services/worker_saved_service.dart';
import 'components/worker_card_compact.dart';
import 'components/edit_worker_collection_dialog.dart';
import 'worker_location_search_screen.dart'; // Para WorkerData

class WorkerCollectionDetailScreen extends StatefulWidget {
  final SavedCollection collection;

  const WorkerCollectionDetailScreen({super.key, required this.collection});

  @override
  State<WorkerCollectionDetailScreen> createState() =>
      _WorkerCollectionDetailScreenState();
}

class _WorkerCollectionDetailScreenState
    extends State<WorkerCollectionDetailScreen> {
  final WorkerSavedService _savedService = WorkerSavedService();
  late SavedCollection _collection;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
  }

  Future<void> _refreshCollection() async {
    final updatedCollection = await _savedService.getCollection(_collection.id);
    if (updatedCollection != null && mounted) {
      setState(() {
        _collection = updatedCollection;
      });
    }
  }

  Future<void> _editCollection() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) =>
          EditWorkerCollectionDialog(currentName: _collection.name),
    );

    if (newName == null || newName.isEmpty || newName == _collection.name) {
      return;
    }

    final success = await _savedService.updateCollectionName(
      _collection.id,
      newName,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Colección actualizada')));
      _refreshCollection();
    }
  }

  Future<void> _removeWorker(String workerId) async {
    final success = await _savedService.removeWorkerFromCollection(
      _collection.id,
      workerId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trabajador eliminado de la colección')),
      );
      _refreshCollection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Modular.to.pop(),
        ),
        title: Text(
          _collection.name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: _editCollection,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _savedService.getWorkersFromCollection(_collection.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final workers = snapshot.data ?? [];

          if (workers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Esta colección está vacía',
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];
              return Stack(
                children: [
                  WorkerCardCompact(
                    worker: worker,
                    onTap: () {
                      final workerData = WorkerData(
                        id: worker['id'],
                        name: worker['name'] ?? 'Usuario',
                        profession: worker['profession'] ?? 'Profesional',
                        categories: [],
                        latitude: 0,
                        longitude: 0,
                        photoUrl: worker['photoUrl'],
                        rating: (worker['rating'] ?? 0.0).toDouble(),
                        phone: worker['phoneNumber'] ?? '',
                        price: (worker['price']?.toString() ?? '').trim(),
                      );

                      Modular.to.pushNamed(
                        '/worker/public-profile',
                        arguments: workerData,
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => _removeWorker(worker['id']),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
