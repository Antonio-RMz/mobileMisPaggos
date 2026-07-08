import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import 'cliente_list_screen.dart';
import 'productos_main_screen.dart';
import 'corte_caja_screen.dart';

import 'inicio_operativo_screen.dart';
class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  int _corteCajaKeyCounter = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Lista de pantallas para cada tab
  List<Widget> get _screens => [
    const InicioOperativoScreen(),
    const ClienteListScreen(),
    const ProductosMainScreen(),
    CorteCajaScreen(key: ValueKey('corte_caja_$_corteCajaKeyCounter')),
  ];

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    if (userProvider.loginError.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de Autenticación: ${userProvider.loginError}'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 8),
          ),
        );
        userProvider.clearLoginError();
      });
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= AppTheme.tabletBreakpoint;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  if (_currentIndex == 3 && index != 3) {
                    // Al salir de la sección de reportes, reiniciamos su llave
                    // para que vuelva a pedir el PIN la próxima vez.
                    _corteCajaKeyCounter++;
                  }
                  _currentIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              indicatorColor: AppTheme.primary.withOpacity(0.15),
              selectedLabelTextStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.slateBlue,
              ),
              unselectedLabelTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(LucideIcons.layoutDashboard, size: 24),
                  selectedIcon: Icon(LucideIcons.layoutDashboard, color: AppTheme.accent, size: 24),
                  label: Text('Inicio'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.users, size: 24),
                  selectedIcon: Icon(LucideIcons.users, color: AppTheme.accent, size: 24),
                  label: Text('Clientes'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.package, size: 24),
                  selectedIcon: Icon(LucideIcons.package, color: AppTheme.accent, size: 24),
                  label: Text('Productos'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.fileText, size: 24),
                  selectedIcon: Icon(LucideIcons.fileText, color: AppTheme.accent, size: 24),
                  label: Text('Reportes'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppTheme.cardHighlight),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateBlue);
            }
            return const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textLight);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            setState(() {
              if (_currentIndex == 3 && index != 3) {
                // Al salir de la sección de reportes, reiniciamos su llave 
                // para que vuelva a pedir el PIN la próxima vez.
                _corteCajaKeyCounter++;
              }
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppTheme.primary.withOpacity(0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.layoutDashboard, size: 24),
              selectedIcon: Icon(LucideIcons.layoutDashboard, color: AppTheme.accent, size: 24),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.users, size: 24),
              selectedIcon: Icon(LucideIcons.users, color: AppTheme.accent, size: 24),
              label: 'Clientes',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.package, size: 24),
              selectedIcon: Icon(LucideIcons.package, color: AppTheme.accent, size: 24),
              label: 'Productos',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.fileText, size: 24),
              selectedIcon: Icon(LucideIcons.fileText, color: AppTheme.accent, size: 24),
              label: 'Reportes',
            ),
          ],
        ),
      ),
    );
  }
}
