import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import 'catalogo_view.dart';
import 'carniceria_view.dart';

class ProductosMainScreen extends StatelessWidget {
  const ProductosMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Inventario y Precios'),
          actions: const [
            NotificationBell(),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textLight,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(
                icon: Icon(Icons.set_meal_outlined),
                text: 'Carnicería',
              ),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Catálogo',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CarniceriaView(),
            CatalogoView(),
          ],
        ),
      ),
    );
  }
}
