import 'package:flutter/material.dart';
import '../../../theme/theme.dart';

// Definición de un widget funcional para los botones de categoría.
class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final bool isDetailedView;
  final Function(bool) onToggleView;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.isDetailedView,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCategoryButton('Comprar')),
                SizedBox(width: Styles.spacingSmall),
                Expanded(child: _buildCategoryButton('Alquiler')),
                SizedBox(width: Styles.spacingSmall),
                Expanded(child: _buildCategoryButton('Anticrético')),
              ],
            ),
          ),
          SizedBox(width: Styles.spacingSmall),
          // Botón de vista detallada/simple
          GestureDetector(
            onTap: () => onToggleView(!isDetailedView),
            child: Container(
              padding: EdgeInsets.all(Styles.spacingSmall),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDetailedView ? Icons.view_agenda : Icons.grid_view,
                color: Styles.primaryColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String title) {
    final isSelected = selectedCategory == title;
    return GestureDetector(
      onTap: () => onCategorySelected(title),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Styles.spacingSmall),
        decoration: BoxDecoration(
          color: isSelected ? Styles.primaryColor : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: isSelected ? Colors.white : Styles.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
