import 'package:flutter/material.dart';
import '../../../theme/theme.dart';

class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
      child: Row(
        children: [
          Expanded(child: _buildCategoryButton('Comprar')),
          SizedBox(width: Styles.spacingSmall),
          Expanded(child: _buildCategoryButton('Alquiler')),
          SizedBox(width: Styles.spacingSmall),
          Expanded(child: _buildCategoryButton('Anticrético')),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String title) {
    final isSelected = selectedCategory == title;
    return GestureDetector(
      onTap: () => onCategorySelected(title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Styles.primaryColor : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Styles.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: isSelected ? Colors.white : Styles.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
