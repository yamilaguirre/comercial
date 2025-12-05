import 'package:flutter/material.dart';
import '../../../../theme/theme.dart';

class PropertyFormProgressBar extends StatelessWidget {
  final double progress;

  const PropertyFormProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: 0, end: progress),
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Styles.primaryColor),
          minHeight: 4,
        );
      },
    );
  }
}
