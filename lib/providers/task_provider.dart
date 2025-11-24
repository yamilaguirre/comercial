import 'package:flutter/material.dart';
import 'dart:math';

import '../models/task_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  List<TaskModel> _tasks = [];
  bool _isLoadingTasks = false;

  List<TaskModel> get tasks => _tasks;
  bool get isLoadingTasks => _isLoadingTasks;

  TaskProvider(this._firestoreService, this._authService) {
    _authService.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    if (_authService.isAuthenticated) {
      fetchTasks();
    } else {
      _tasks = [];
      notifyListeners();
    }
  }

  Future<void> fetchTasks() async {
    if (!_authService.isAuthenticated) return;

    _isLoadingTasks = true;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userId = user.uid;
      final accessToken = await user.getIdToken();

      if (accessToken == null) {
        throw Exception('Access token is null. Cannot fetch tasks.');
      }

      _tasks = await _firestoreService.getTasksForUser(userId, accessToken);
    } catch (e) {
      _tasks = [];
    } finally {
      _isLoadingTasks = false;
      notifyListeners();
    }
  }

  Future<void> addTask(String title) async {
    if (!_authService.isAuthenticated) return;

    final user = _authService.currentUser;
    if (user == null) return;

    final newTask = TaskModel(
      id: Random().nextInt(10000).toString(),
      title: title,
      description: 'Added from the app.',
    );

    _tasks.insert(0, newTask);
    notifyListeners();

    try {
      final accessToken = await user.getIdToken();

      if (accessToken == null) {
        throw Exception('Access token is null. Cannot add task.');
      }

      await _firestoreService.addTask(user.uid, newTask, accessToken);
    } catch (e) {
      _tasks.remove(newTask);
      notifyListeners();
    }
  }

  void toggleTaskCompletion(TaskModel task) {
    if (!_authService.isAuthenticated) return;

    final user = _authService.currentUser;
    if (user == null) return;

    task.isCompleted = !task.isCompleted;
    notifyListeners();

    user
        .getIdToken()
        .then((accessToken) {
          if (accessToken != null) {
            _firestoreService.updateTask(user.uid, task, accessToken);
          } else {
            // Manejo de error si no se puede obtener el token
          }
        })
        .catchError((e) {
          // Manejo de error
        });
  }
}
