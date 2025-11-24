class TaskModel {
  final String id;
  String title;
  String description;
  bool isCompleted;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
  });

  // Convert map (from Firestore/API) to object
  factory TaskModel.fromMap(Map<String, dynamic> data) {
    return TaskModel(
      id: data['id'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      isCompleted: data['isCompleted'] as bool,
    );
  }

  // Convert object to map (for Firestore/API)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
    };
  }
}
