// filepath: lib/core/layouts/property_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';

/// NOTA: Este Layout es el Shell para el módulo de Propiedades.
/// Contiene la lógica de navegación inferior para las rutas de /home, /favorites, /messages, /alerts y /account.
class PropertyLayout extends StatefulWidget {
  final Widget child;

  const PropertyLayout({super.key, required this.child});

  @override
  State<PropertyLayout> createState() => _PropertyLayoutState();
}

class _PropertyLayoutState extends State<PropertyLayout> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final String location = Modular.to.path;
    setState(() {
      _selectedIndex = _getSelectedIndex(location);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: widget.child,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
            icon: _buildNavIcon(Icons.search, false),
            activeIcon: _buildNavIcon(Icons.search, true),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.favorite_border, false),
            activeIcon: _buildNavIcon(Icons.favorite, true),
            label: 'Guardados',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.chat_bubble_outline, false),
            activeIcon: _buildNavIcon(Icons.chat_bubble, true),
            label: 'Buzón',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.notifications_none, false),
            activeIcon: _buildNavIcon(Icons.notifications, true),
            label: 'Avisos',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.person_outline, false),
            activeIcon: _buildNavIcon(Icons.person, true),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
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
    // Normalizar la ruta para comparación
    final normalizedLocation = location.toLowerCase();

    // Verificar rutas específicas primero
    if (normalizedLocation.endsWith('/home') ||
        normalizedLocation.endsWith('/property/home') ||
        normalizedLocation == '/property' ||
        normalizedLocation == '/property/') {
      return 0;
    }
    if (normalizedLocation.contains('/favorites') ||
        normalizedLocation.contains('/collection-detail')) {
      return 1;
    }
    if (normalizedLocation.contains('/messages') ||
        normalizedLocation.contains('/chat-detail')) {
      return 2;
    }
    if (normalizedLocation.contains('/alerts')) {
      return 3;
    }
    if (normalizedLocation.contains('/account') ||
        normalizedLocation.contains('/edit-profile') ||
        normalizedLocation.contains('/agent-management-profile')) {
      return 4;
    }

    // Por defecto, explorar
    return 0;
  }

  // Lógica de navegación. Usamos navigate a la ruta completa
  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // Si ya estamos en la misma tab, no hacer nada o hacer scroll to top
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

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
