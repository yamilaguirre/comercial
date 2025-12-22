import 'package:flutter/material.dart';
import 'package:chaski_comercial/theme/theme.dart';
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
  final TextEditingController _customProfessionController =
      TextEditingController();

  @override
  void dispose() {
    _customProfessionController.dispose();
    super.dispose();
  }

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

  void _addCustomProfession() {
    final text = _customProfessionController.text.trim();
    if (text.isNotEmpty) {
      widget.onToggleSubcategory('Otros', text);
      _customProfessionController.clear();
      setState(() {});
    }
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
                    Flexible(
                      child: Text(
                        count > 0 ? '$category ($count)' : category,
                        style: TextStyle(
                          color: count > 0
                              ? Styles.primaryColor
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
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
              final isOtherCategory = category == 'Otros';

              // Obtener profesiones seleccionadas para esta categoría
              final selectedInCat = widget.selectedProfessions[category] ?? [];

              // Identificar profesiones personalizadas (están seleccionadas pero no en subcategories de data)
              final customProfessions = selectedInCat
                  .where((s) => !subcategories.contains(s))
                  .toList();

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecciona de la lista:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...subcategories.map((subcategory) {
                          final selected = selectedInCat.contains(subcategory);
                          return InkWell(
                            onTap: () => widget.onToggleSubcategory(
                              category,
                              subcategory,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Checkbox(
                                    value: selected,
                                    activeColor: Styles.primaryColor,
                                    onChanged: (_) =>
                                        widget.onToggleSubcategory(
                                          category,
                                          subcategory,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(subcategory)),
                              ],
                            ),
                          );
                        }).toList(),

                        if (isOtherCategory) ...[
                          const Divider(height: 24),
                          Text(
                            'O escribe tu profesión:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customProfessionController,
                                  decoration: InputDecoration(
                                    hintText: 'Ej: Especialista en Mascotas',
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addCustomProfession(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _addCustomProfession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Styles.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Agregar'),
                              ),
                            ],
                          ),
                          if (customProfessions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Profesiones agregadas:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: customProfessions.map((custom) {
                                return Chip(
                                  label: Text(
                                    custom,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Styles.primaryColor
                                      .withOpacity(0.1),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => widget.onToggleSubcategory(
                                    category,
                                    custom,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: Styles.primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              );
            })
            .toList(),
      ],
    );
  }
}
