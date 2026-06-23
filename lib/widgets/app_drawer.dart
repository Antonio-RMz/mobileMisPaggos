import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/user_provider.dart';
import '../screens/main_screen.dart';
import '../screens/support_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/personal_list_screen.dart';

import '../screens/ventas_list_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../providers/printer_provider.dart';
import '../screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Drawer(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          // Cabecera del Drawer con diseño Premium
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
            child: Container(
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: userProvider.imagePath.isNotEmpty
                      ? CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.backgroundLight,
                          backgroundImage: FileImage(File(userProvider.imagePath)),
                        )
                      : const CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.backgroundLight,
                          child: Icon(LucideIcons.user, size: 32, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProvider.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Administración',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),
          
          // Opciones del Menú
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [

                _buildDrawerItem(
                  context: context,
                  icon: LucideIcons.users,
                  title: 'Directorio de Clientes',
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
                      (route) => false,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: LucideIcons.package,
                  title: 'Catálogo de Productos',
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 2)),
                      (route) => false,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: LucideIcons.shoppingCart,
                  title: 'Ventas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VentasListScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: LucideIcons.barChart2,
                  title: 'Reportes',
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 3)),
                      (route) => false,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: LucideIcons.bike,
                  title: 'Repartidores',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PersonalListScreen()),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
                ),
                Consumer<PrinterProvider>(
                  builder: (context, printerProvider, child) {
                    return _buildDrawerItem(
                      context: context,
                      icon: Icons.print,
                      title: 'Impresora Térmica',
                      trailing: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: printerProvider.isConnected ? Colors.green : Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: (printerProvider.isConnected ? Colors.green : Colors.red).withOpacity(0.5),
                              blurRadius: 4,
                            )
                          ]
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                        );
                      },
                    );
                  }
                ),
                _buildDrawerItem(
                  context: context,
                  icon: LucideIcons.helpCircle,
                  title: 'Soporte Técnico',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDrawerItem(
              context: context,
              icon: LucideIcons.logOut,
              title: 'Cerrar Sesión',
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_logged_in', false);
                
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isActive = false,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.cardHighlight : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          icon,
          color: isActive ? AppTheme.accent : AppTheme.textLight,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? AppTheme.accent : AppTheme.textDark,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        trailing: trailing,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}
