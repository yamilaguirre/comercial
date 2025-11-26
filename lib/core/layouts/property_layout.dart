// filepath: lib/core/layouts/property_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';

/// NOTA: Este Layout es el Shell para el módulo de Propiedades.
/// Contiene la lógica de navegación inferior para las rutas de /home, /favorites, /messages, /alerts y /account.
class PropertyLayout extends StatelessWidget {
  final Widget child;

  const PropertyLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    // Usamos Modular.to.path para obtener la ruta actual (ej: '/property/home')
    final String location = Modular.to.path;
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
        onTap: (index) => _onItemTapped(index),
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
    IconData icon;
    switch (iconName) {
      case 'explorar':
        icon = Icons.search;
        break;
      case 'guardados':
        icon = Icons.bookmark_border;
        break;
      case 'buzon':
        icon = Icons.message_outlined;
        break;
      case 'avisos':
        icon = Icons.notifications_none;
        break;
      case 'cuenta':
        icon = Icons.person_outline;
        break;
      default:
        icon = Icons.question_mark;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? Styles.primaryColor : Colors.grey,
          size: 24,
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

  // Lógica para determinar el índice de la pestaña basado en la ruta (location)
  int _getSelectedIndex(String location) {
    // Usamos contains para manejar la ruta dentro del módulo /property
    if (location.contains('home')) return 0;
    if (location.contains('favorites')) return 1;
    if (location.contains('messages')) return 2;
    if (location.contains('alerts')) return 3;
    if (location.contains('account')) return 4;
    return 0;
  }

  // Lógica de navegación. Usamos navigate a la ruta completa
  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Modular.to.navigate('/property/home');
        break;
      case 1:
        Modular.to.navigate('/property/favorites');
        break;
      case 2:
        Modular.to.navigate('/property/messages');
        break;
      case 3:
        Modular.to.navigate('/property/alerts');
        break;
      case 4:
        Modular.to.navigate('/property/account');
        break;
    }
  }
}
