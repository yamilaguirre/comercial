import 'package:flutter/material.dart';
import 'package:my_first_app/theme/theme.dart';
import '../../../core/data/professions_data.dart';

class ProfessionSelector extends StatefulWidget {
  final Map<String, List<String>> selectedProfessions;
  final void Function(String category, String subcategory) onToggleSubcategory;

  const ProfessionSelector({
    Key? key,
    required this.selectedProfessions,
    required this.onToggleSubcategory,
  }) : super(key: key);

  @override
  State<ProfessionSelector> createState() => _ProfessionSelectorState();
}

class _ProfessionSelectorState extends State<ProfessionSelector> {
  final Set<String> _expandedCategories = {};

  int _getSelectedCount(String category) {
    return widget.selectedProfessions[category]?.length ?? 0;
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Mano de obra':
        return Icons.build;
      case 'Técnicos':
        return Icons.settings;
      case 'Profesionales':
        return Icons.business_center;
      case 'Otros':
        return Icons.more_horiz;
      default:
        return Icons.work;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: professionsData.map((pc) {
            final category = pc.category;
            final count = _getSelectedCount(category);
            final isExpanded = _expandedCategories.contains(category);

            return GestureDetector(
              onTap: () => _toggleCategory(category),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: count > 0
                      ? Styles.primaryColor.withOpacity(0.1)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: count > 0 ? Styles.primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      size: 18,
                      color: count > 0 ? Styles.primaryColor : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      count > 0 ? '$category ($count)' : category,
                      style: TextStyle(
                        color: count > 0 ? Styles.primaryColor : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: count > 0 ? Styles.primaryColor : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Expandibles de subcategorías
        const SizedBox(height: 8),
        ...professionsData
            .where((pc) => _expandedCategories.contains(pc.category))
            .map((pc) {
          final category = pc.category;
          final subcategories = pc.subcategories;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: subcategories.map((subcategory) {
                    final selected = (widget.selectedProfessions[category] ?? []).contains(subcategory);
                    return InkWell(
                      onTap: () => widget.onToggleSubcategory(category, subcategory),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (_) => widget.onToggleSubcategory(category, subcategory),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(subcategory)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}
