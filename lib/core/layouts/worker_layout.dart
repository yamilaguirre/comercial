// filepath: lib/core/layouts/worker_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/theme/theme.dart';

class WorkerLayout extends StatelessWidget {
  final Widget child;

  const WorkerLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
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
    IconData icon;
    switch (iconName) {
      case 'inicio':
        icon = Icons.home_work;
        break;
      case 'mensajes':
        icon = Icons.message;
        break;
      case 'trabajos':
        icon = Icons.construction;
        break;
      case 'regresar':
        icon = Icons.arrow_back;
        break;
      case 'cuenta':
        icon = Icons.person;
        break;
      default:
        icon = Icons.circle;
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

  int _getSelectedIndex(String location) {
    if (location.endsWith('/home')) return 0;
    if (location.contains('/messages')) return 1;
    // Usa 'trabajos' como la ruta del módulo /worker/trabajos (asumo)
    if (location.contains('/trabajos')) return 2;
    // Regresar siempre va a la selección de rol (que está en /auth/select-role)
    if (location.contains('/select-role')) return 3;
    if (location.contains('/account')) return 4;
    return 0;
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Modular.to.navigate('/worker/home');
        break;
      case 1:
        Modular.to.navigate('/worker/messages');
        break;
      case 2:
        Modular.to.navigate('/worker/trabajos');
        break;
      case 3:
        // Navega a la ruta absoluta en el AuthModule
        Modular.to.navigate('/auth/select-role');
        break;
      case 4:
        Modular.to.navigate('/worker/account');
        break;
    }
  }
}
