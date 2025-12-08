import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class InmobiliariaLayout extends StatefulWidget {
  final Widget child;

  const InmobiliariaLayout({super.key, required this.child});

  @override
  State<InmobiliariaLayout> createState() => _InmobiliariaLayoutState();
}

class _InmobiliariaLayoutState extends State<InmobiliariaLayout> {
  int _currentIndex = 0;
  bool _isCheckingSubscription = true;

  final List<_NavItem> _navItems = [
    _NavItem(
      route: '/inmobiliaria/home',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Inicio',
    ),
    _NavItem(
      route: '/inmobiliaria/market',
      icon: Icons.search,
      activeIcon: Icons.search,
      label: 'Explorar',
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
  void initState() {
    super.initState();
    _checkSubscription();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  Future<void> _checkSubscription() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null && authService.userRole == 'inmobiliaria_empresa') {
      try {
        final premiumDoc = await FirebaseFirestore.instance
            .collection('premium_users')
            .doc(user.uid)
            .get();

        final hasPremium =
            premiumDoc.exists && premiumDoc.data()?['status'] == 'active';

        if (!hasPremium) {
          if (mounted) {
            Modular.to.navigate('/inmobiliaria/onboarding');
          }
          return;
        }
      } catch (e) {
        print('Error checking subscription: $e');
      }
    }

    if (mounted) {
      setState(() => _isCheckingSubscription = false);
    }
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
    if (_isCheckingSubscription) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
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
            icon: _buildNavIcon(_navItems[0].icon, false),
            activeIcon: _buildNavIcon(_navItems[0].activeIcon, true),
            label: _navItems[0].label,
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(_navItems[1].icon, false),
            activeIcon: _buildNavIcon(_navItems[1].activeIcon, true),
            label: _navItems[1].label,
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(_navItems[2].icon, false),
            activeIcon: _buildNavIcon(_navItems[2].activeIcon, true),
            label: _navItems[2].label,
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(_navItems[3].icon, false),
            activeIcon: _buildNavIcon(_navItems[3].activeIcon, true),
            label: _navItems[3].label,
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(_navItems[4].icon, false),
            activeIcon: _buildNavIcon(_navItems[4].activeIcon, true),
            label: _navItems[4].label,
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
    return Icon(
      icon,
      color: isActive ? Styles.primaryColor : Colors.grey,
      size: 24,
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
