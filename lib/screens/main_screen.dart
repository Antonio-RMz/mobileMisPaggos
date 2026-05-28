import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'cliente_list_screen.dart';
import 'productos_main_screen.dart';
import 'corte_caja_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Lista de pantallas para cada tab
  final List<Widget> _screens = [
    const DashboardScreen(),
    const ClienteListScreen(),
    const ProductosMainScreen(),
    const CorteCajaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: AppTheme.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutDashboard),
            selectedIcon: Icon(LucideIcons.layoutDashboard, color: AppTheme.accent),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.users),
            selectedIcon: Icon(LucideIcons.users, color: AppTheme.accent),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.package),
            selectedIcon: Icon(LucideIcons.package, color: AppTheme.accent),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.fileText),
            selectedIcon: Icon(LucideIcons.fileText, color: AppTheme.accent),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}
