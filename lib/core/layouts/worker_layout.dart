import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';

class WorkerLayout extends StatelessWidget {
  final Widget child;

  const WorkerLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final int selectedIndex = _getSelectedIndex(location);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Styles.primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavIcon('inicio', false),
            activeIcon: _buildNavIcon('inicio', true),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('mensajes', false),
            activeIcon: _buildNavIcon('mensajes', true),
            label: 'Mensajes',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('trabajos', false),
            activeIcon: _buildNavIcon('trabajos', true),
            label: 'Trabajos',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('regresar', false),
            activeIcon: _buildNavIcon('regresar', true),
            label: 'Regresar',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('cuenta', false),
            activeIcon: _buildNavIcon('cuenta', true),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(String iconName, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorFiltered(
          colorFilter: isActive
              ? ColorFilter.mode(Styles.primaryColor, BlendMode.srcIn)
              : const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
          child: Image.asset(
            'assets/images/icon/$iconName.png',
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.circle,
              color: isActive ? Styles.primaryColor : Colors.grey,
              size: 24,
            ),
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Styles.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/work-home')) return 0;
    if (location.startsWith('/messages')) return 1;
    if (location.startsWith('/freelance-work')) return 2;
    if (location.startsWith('/select-role')) return 3;
    if (location.startsWith('/account')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/work-home');
        break;
      case 1:
        context.go('/messages');
        break;
      case 2:
        context.go('/freelance-work');
        break;
      case 3:
        context.go('/select-role');
        break;
      case 4:
        context.go('/account');
        break;
    }
  }
}
