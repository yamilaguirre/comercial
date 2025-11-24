import 'package:flutter/material.dart';
import 'package:my_first_app/theme/theme.dart';
import '../../models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;

  const TaskCard({super.key, required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        vertical: Styles.spacingSmall,
        horizontal: Styles.spacingXSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Styles.radiusSmall),
        side: BorderSide(
          color: task.isCompleted
              ? Styles.successColor.withOpacity(0.3)
              : Styles.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(
          task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: task.isCompleted ? Styles.successColor : Styles.textSecondary,
        ),
        title: Text(
          task.title,
          style: TextStyles.body.copyWith(
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.refresh, size: 20, color: Styles.primaryColor),
          onPressed: onToggle,
        ),
        onTap: onToggle,
      ),
    );
  }
}
