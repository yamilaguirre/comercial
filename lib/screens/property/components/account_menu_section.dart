import 'package:flutter/material.dart';
import '../../../theme/theme.dart';

class AccountMenuSection extends StatelessWidget {
  final String? title;
  final List<Widget> items;
  final bool hasTitle;

  const AccountMenuSection({
    super.key,
    this.title,
    required this.items,
    this.hasTitle = true,
  });

  // Encabezado para la sección de opciones
  Widget _buildTitle() {
    if (!hasTitle || title == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Styles.spacingMedium,
        Styles.spacingMedium,
        Styles.spacingMedium,
        Styles.spacingXSmall,
      ),
      child: Text(
        title!,
        style: TextStyles.subtitle.copyWith(
          color: Styles.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Divisor entre items
  static Widget buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: Styles.spacingMedium,
      endIndent: Styles.spacingMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildTitle(), ...items],
      ),
    );
  }
}

// Widget individual de la opción de menú
class AccountMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AccountMenuItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(Styles.spacingMedium),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: Styles.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyles.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Styles.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyles.caption.copyWith(
                        fontSize: 13,
                        color: Styles.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Styles.textSecondary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
