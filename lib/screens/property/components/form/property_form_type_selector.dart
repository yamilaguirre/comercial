import 'package:flutter/material.dart';
import '../../../../theme/theme.dart';
import '../../../../core/utils/property_constants.dart';

class PropertyFormTypeSelector extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String> onTypeChanged;

  const PropertyFormTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: '¿Qué tipo de propiedad es?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: PropertyConstants.propertyTypes.length,
          itemBuilder: (context, index) {
            final type = PropertyConstants.propertyTypes[index];
            final isSelected = selectedType == type;
            IconData icon;

            switch (type) {
              case 'casa':
                icon = Icons.home_outlined;
                break;
              case 'departamento':
                icon = Icons.apartment_outlined;
                break;
              case 'terreno':
                icon = Icons.landscape_outlined;
                break;
              case 'oficina':
                icon = Icons.business_outlined;
                break;
              case 'local_comercial':
                icon = Icons.storefront_outlined;
                break;
              default:
                icon = Icons.home_work_outlined;
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTypeChanged(type),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Styles.primaryColor.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Styles.primaryColor
                              : Colors.grey.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        PropertyConstants.getPropertyTitle(type),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Styles.primaryColor
                              : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
