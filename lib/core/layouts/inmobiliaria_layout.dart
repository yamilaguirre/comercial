import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';

class InmobiliariaLayout extends StatefulWidget {
  final Widget child;

  const InmobiliariaLayout({super.key, required this.child});

  @override
  State<InmobiliariaLayout> createState() => _InmobiliariaLayoutState();
}

class _InmobiliariaLayoutState extends State<InmobiliariaLayout> {
  int _currentIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(
      route: '/inmobiliaria/home',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Inicio',
    ),
    _NavItem(
      route: '/inmobiliaria/properties',
      icon: Icons.home_work_outlined,
      activeIcon: Icons.home_work,
      label: 'Propiedades',
    ),
    _NavItem(
      route: '/inmobiliaria/chats',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Chats',
    ),
    _NavItem(
      route: '/inmobiliaria/profile',
      icon: Icons.business_outlined,
      activeIcon: Icons.business,
      label: 'Perfil',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    final currentPath = Modular.to.path;
    for (int i = 0; i < _navItems.length; i++) {
      if (currentPath.startsWith(_navItems[i].route)) {
        if (_currentIndex != i) {
          setState(() => _currentIndex = i);
        }
        break;
      }
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      Modular.to.navigate(_navItems[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isActive = _currentIndex == index;
                return _NavButton(
                  item: item,
                  isActive: isActive,
                  onTap: () => _onTabTapped(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItem({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Styles.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? Styles.primaryColor : Colors.grey[600],
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? Styles.primaryColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
