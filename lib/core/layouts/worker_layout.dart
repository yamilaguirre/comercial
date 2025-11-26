import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:my_first_app/theme/theme.dart';

class WorkerLayout extends StatefulWidget {
  final Widget child;

  const WorkerLayout({super.key, required this.child});

  @override
  State<WorkerLayout> createState() => _WorkerLayoutState();
}

class _WorkerLayoutState extends State<WorkerLayout> {
  @override
  void initState() {
    super.initState();
    Modular.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    Modular.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: widget.child,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
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
              _getFallbackIcon(iconName),
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

  IconData _getFallbackIcon(String iconName) {
    switch (iconName) {
      case 'inicio':
        return Icons.home_work;
      case 'mensajes':
        return Icons.message;
      case 'regresar':
        return Icons.arrow_back;
      case 'cuenta':
        return Icons.person;
      default:
        return Icons.circle;
    }
  }

  int _getSelectedIndex(String location) {
    if (location.contains('home-worker')) return 0;
    if (location.contains('messages')) return 1;
    // Regresar (index 2) no mantiene estado activo ya que sale del módulo
    if (location.contains('account')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Modular.to.navigate('/worker/home-worker');
        break;
      case 1:
        Modular.to.navigate('/worker/messages');
        break;
      case 2:
        // Resetear rol y navegar a selección
        final authService = Provider.of<AuthService>(context, listen: false);
        authService.resetRole().then((_) {
          Modular.to.navigate('/select-role');
        });
        break;
      case 3:
        Modular.to.navigate('/worker/account');
        break;
    }
  }
}
