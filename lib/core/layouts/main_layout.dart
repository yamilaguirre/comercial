import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    // Obtener la ruta actual para determinar el índice seleccionado
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
            icon: _buildNavIcon('explorar', false),
            activeIcon: _buildNavIcon('explorar', true),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('guardados', false),
            activeIcon: _buildNavIcon('guardados', true),
            label: 'Guardados',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('buzon', false),
            activeIcon: _buildNavIcon('buzon', true),
            label: 'Buzón',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('avisos', false),
            activeIcon: _buildNavIcon('avisos', true),
            label: 'Avisos',
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
    // Aceptamos property-home y work-home como índice 0
    if (location.startsWith('/property-home') ||
        location.startsWith('/work-home')) {
      return 0;
    }
    if (location.startsWith('/favorites')) return 1;
    if (location.startsWith('/messages')) return 2;
    if (location.startsWith('/alerts')) return 3;
    if (location.startsWith('/account')) return 4;

    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Lógica de rol para saber a cuál Home ir al pulsar "Explorar"
        final authService = context.read<AuthService>();
        // Leemos el rol del provider (si no tiene, asumimos cliente -> property-home por defecto)
        // NOTA: Como pediste no guardar en RAM, esto podría dar null si authService no tiene el rol cacheado.
        // Pero para navegación rápida dentro del layout, asumimos la ruta actual o property-home.

        // Si ya estamos en una ruta de trabajo, mantenemos trabajo. Si no, default a propiedades.
        final currentLocation = GoRouterState.of(context).uri.toString();
        if (currentLocation.startsWith('/work-home')) {
          context.go('/work-home');
        } else {
          context.go('/property-home');
        }
        break;
      case 1:
        context.go('/favorites');
        break;
      case 2:
        context.go('/messages');
        break;
      case 3:
        context.go('/alerts');
        break;
      case 4:
        context.go('/account');
        break;
    }
  }
}
