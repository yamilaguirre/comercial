import 'package:flutter/material.dart';
import '../../../../theme/theme.dart';
import '../../../../core/utils/property_constants.dart';
import '../../../../core/utils/amenity_helper.dart';

class PropertyFormAmenities extends StatelessWidget {
  final Map<String, bool> amenityState;
  final Function(String, bool) onAmenityChanged;

  const PropertyFormAmenities({
    super.key,
    required this.amenityState,
    required this.onAmenityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = amenityState.values.where((v) => v).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Styles.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Styles.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$selectedCount seleccionada${selectedCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Styles.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...AmenityHelper.amenityCategories.entries.map((entry) {
          final category = entry.key;
          final amenities = entry.value;

          // Filter amenities that exist in our constants
          final validAmenities = amenities
              .where((key) => PropertyConstants.amenityLabels.containsKey(key))
              .toList();

          if (validAmenities.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 8),
                child: Row(
                  children: [
                    Icon(
                      AmenityHelper.getCategoryIcon(category),
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: validAmenities.length,
                itemBuilder: (context, index) {
                  final key = validAmenities[index];
                  final isSelected = amenityState[key] ?? false;
                  final label = PropertyConstants.amenityLabels[key] ?? key;
                  final icon = AmenityHelper.getIcon(key);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onAmenityChanged(key, !isSelected),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Styles.primaryColor.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Styles.primaryColor
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 28,
                              color: isSelected
                                  ? Styles.primaryColor
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Styles.primaryColor
                                      : Colors.grey.shade700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }
}
