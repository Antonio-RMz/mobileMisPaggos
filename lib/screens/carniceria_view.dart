import 'package:flutter/material.dart';
import '../models/producto_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'carniceria_form_modal.dart';
import 'package:intl/intl.dart';

class CarniceriaView extends StatefulWidget {
  const CarniceriaView({super.key});

  @override
  State<CarniceriaView> createState() => _CarniceriaViewState();
}

class _CarniceriaViewState extends State<CarniceriaView> {
  final FirebaseService _firebaseService = FirebaseService();
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  void _mostrarModalAlta(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CarniceriaFormModal(),
    );
  }

  void _mostrarOpciones(BuildContext context, Producto producto) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar Producto'),
                onTap: () {
                  Navigator.pop(context);
                  _editarProducto(producto);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarProducto(producto);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _editarProducto(Producto producto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CarniceriaFormModal(producto: producto),
    );
  }

  void _eliminarProducto(Producto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text('¿Estás seguro de que deseas eliminar el producto "${producto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firebaseService.deleteProducto(producto.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Producto eliminado exitosamente.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Carnicería',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Gestiona los cortes de carne y cremería.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textLight,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Buscar producto...',
                        hintStyle: TextStyle(fontSize: 14, color: AppTheme.textLight),
                        prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textLight),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Productos
          Expanded(
            child: StreamBuilder<List<Producto>>(
              stream: _firebaseService.getProductosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar la información.', style: Theme.of(context).textTheme.bodyLarge),
                  );
                }

                final todos = snapshot.data ?? [];
                // Filtrar localmente por búsqueda y SOLO 'carniceria'
                final productos = todos.where((p) {
                  final esCarniceria = p.seccion == 'carniceria';
                  final matchBusqueda = p.nombre.toLowerCase().contains(_searchQuery);
                  return esCarniceria && matchBusqueda;
                }).toList();

                if (productos.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.set_meal_outlined, size: 48, color: AppTheme.textLight),
                        const SizedBox(height: 16),
                        Text('No se encontró "${_searchQuery}"', style: const TextStyle(color: AppTheme.textLight)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _mostrarModalAlta(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Alta Carnicería'),
                        ),
                      ],
                    ),
                  );
                }

                if (productos.isEmpty && _searchQuery.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.set_meal_outlined, size: 48, color: AppTheme.textLight),
                        const SizedBox(height: 16),
                        const Text('No hay productos de carnicería', style: TextStyle(color: AppTheme.textLight)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final producto = productos[index];
                    return _buildProductoCard(context, producto);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_carniceria',
        onPressed: () => _mostrarModalAlta(context),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildProductoCard(BuildContext context, Producto producto) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.set_meal, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Precio: ${_currencyFormat.format(producto.precio)} / ${producto.unidadVenta}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  if (producto.observaciones.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      producto.observaciones,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppTheme.textLight),
              onPressed: () => _mostrarOpciones(context, producto),
            ),
          ],
        ),
      ),
    );
  }
}
