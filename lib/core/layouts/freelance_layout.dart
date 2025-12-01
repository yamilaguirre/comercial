import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:my_first_app/theme/theme.dart';
import '../../services/chat_service.dart';

class FreelanceLayout extends StatefulWidget {
  final Widget child;

  const FreelanceLayout({super.key, required this.child});

  @override
  State<FreelanceLayout> createState() => _FreelanceLayoutState();
}

class _FreelanceLayoutState extends State<FreelanceLayout> {
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
            icon: _buildNavIconWithBadge(context, 'mensajes', false),
            activeIcon: _buildNavIconWithBadge(context, 'mensajes', true),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('ubicacion', false),
            activeIcon: _buildNavIcon('ubicacion', true),
            label: 'Ubicación',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon('regresar', false),
            activeIcon: _buildNavIcon('regresar', true),
            label: 'Regresar',
          ),
        ],
      ),
    );
  }

  Widget _buildNavIconWithBadge(
    BuildContext context,
    String iconName,
    bool isActive,
  ) {
    if (iconName != 'mensajes') {
      return _buildNavIcon(iconName, isActive);
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      return _buildNavIcon(iconName, isActive);
    }

    final chatService = ChatService();

    return StreamBuilder<int>(
      stream: chatService.getTotalUnreadCount(currentUserId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildNavIcon(iconName, isActive),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
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
        return Icons.person;
      case 'mensajes':
        return Icons.message;
      case 'ubicacion':
        return Icons.location_on;
      case 'regresar':
        return Icons.arrow_back;
      default:
        return Icons.circle;
    }
  }

  int _getSelectedIndex(String location) {
    if (location.contains('home')) return 0;
    if (location.contains('messages')) return 1;
    if (location.contains('location-config')) return 2;
    // Regresar (index 3) no mantiene estado activo ya que sale del módulo
    return 0; // Default to Inicio
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Inicio -> worker_profile_screen
        Modular.to.navigate('home');
        break;
      case 1:
        // Chat -> messages
        Modular.to.navigate('messages');
        break;
      case 2:
        // Ubicación -> location-config
        Modular.to.navigate('location-config');
        break;
      case 3:
        // Regresar - Resetear rol y navegar a selección
        final authService = Provider.of<AuthService>(context, listen: false);
        authService.resetRole().then((_) {
          Modular.to.navigate('/select-role');
        });
        break;
    }
  }
}
