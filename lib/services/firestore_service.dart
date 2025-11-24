import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<TaskModel>> getTasksForUser(
    String userId,
    String accessToken,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('tasks')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TaskModel(
          id: doc.id,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          isCompleted: data['is_completed'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  Future<TaskModel> addTask(
    String userId,
    TaskModel task,
    String accessToken,
  ) async {
    try {
      final docRef = await _firestore.collection('tasks').add({
        'user_id': userId,
        'title': task.title,
        'description': task.description,
        'is_completed': task.isCompleted,
        'created_at': FieldValue.serverTimestamp(),
      });
      
      return TaskModel(
        id: docRef.id,
        title: task.title,
        description: task.description,
        isCompleted: task.isCompleted,
      );
    } catch (e) {
      print('Error adding task: $e');
      throw e;
    }
  }

  Future<void> updateTask(
    String userId,
    TaskModel task,
    String accessToken,
  ) async {
    try {
      await _firestore.collection('tasks').doc(task.id).update({
        'title': task.title,
        'description': task.description,
        'is_completed': task.isCompleted,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating task: $e');
      throw e;
    }
  }
}
