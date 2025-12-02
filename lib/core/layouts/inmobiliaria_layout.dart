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
  final List<String> _routes = [
    '/inmobiliaria/home',
    '/inmobiliaria/properties',
    '/inmobiliaria/profile',
  ];

  int get _currentIndex {
    final currentPath = Modular.to.path;
    final index = _routes.indexWhere((route) => currentPath.contains(route));
    return index >= 0 ? index : 0;
  }

  void _onTabTapped(int index) {
    Modular.to.navigate(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Styles.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work),
            label: 'Propiedades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Modular.to.pushNamed('/inmobiliaria/new-property'),
        backgroundColor: Styles.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
