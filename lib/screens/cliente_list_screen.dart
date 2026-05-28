import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math';
import '../models/cliente_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'cliente_form_modal.dart';
import 'pos_screen.dart';
import 'cliente_profile_screen.dart';
import 'package:intl/intl.dart';

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});

  @override
  State<ClienteListScreen> createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  void _mostrarModalAlta(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ClienteFormModal(),
    );
  }

  void _mostrarOpciones(BuildContext context, Cliente cliente) {
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
                leading: const Icon(LucideIcons.wallet, color: Colors.green),
                title: const Text('Nueva Venta (POS)', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); // Cierra modal
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PosScreen(cliente: cliente)),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(LucideIcons.eye, color: AppTheme.accent),
                title: const Text('Consultar Detalles (Cobranza)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClienteProfileScreen(cliente: cliente)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.edit2, color: Colors.blue),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(context);
                  _editarCliente(cliente);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarCliente(cliente);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _consultarCliente(Cliente cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles del Cliente', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nombre Completo:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text('${cliente.nombre} ${cliente.apPaterno} ${cliente.apMaterno}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Text('Celular:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(cliente.celular.isNotEmpty ? cliente.celular : 'N/A', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Text('Teléfono Fijo:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(cliente.telefono.isNotEmpty ? cliente.telefono : 'N/A', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Text('Correo:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(cliente.correo.isNotEmpty ? cliente.correo : 'N/A', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Text('Observaciones:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(cliente.observaciones.isNotEmpty ? cliente.observaciones : 'Ninguna', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          )
        ],
      ),
    );
  }

  void _editarCliente(Cliente cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClienteFormModal(cliente: cliente),
    );
  }

  void _eliminarCliente(Cliente cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text('¿Estás seguro de que deseas eliminar a ${cliente.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context); // close dialog
              try {
                await _firebaseService.deleteCliente(cliente.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cliente eliminado exitosamente.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
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
      drawer: const AppDrawer(),
      appBar: AppBar(
        // Al quitar 'leading', Flutter automáticamente pondrá el botón del Drawer.
        title: const Text('MisPaggos'),
      ),
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
                  'Lista de Clientes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Visualización de clientes registrados y\nsus datos de contacto.',
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
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        hintStyle: TextStyle(fontSize: 14, color: AppTheme.textLight),
                        prefixIcon: Icon(LucideIcons.search, size: 20, color: AppTheme.textLight),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    icon: const Icon(LucideIcons.filter, size: 20, color: AppTheme.textLight),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: StreamBuilder<List<Cliente>>(
              stream: _firebaseService.getClientesStream(),
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

                final clientes = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: clientes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == clientes.length) {
                      return _buildAddCard(context);
                    }
                    return _buildClienteCard(context, clientes[index], index);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_cliente',
        onPressed: () => _mostrarModalAlta(context),
        child: const Icon(LucideIcons.plus, size: 28),
      ),
    );
  }

  Widget _buildClienteCard(BuildContext context, Cliente cliente, int index) {
    final random = Random(cliente.id.hashCode);
    final idFicticio = 'CLT-${random.nextInt(90000) + 10000}';
    
    final bool tieneDeuda = cliente.deudaTotal > 0;
    final String tiempoText = tieneDeuda 
        ? 'Deuda: \$${cliente.deudaTotal.toStringAsFixed(2)}' 
        : 'Sin adeudo (\$0.00)';
    final Color tiempoColor = tieneDeuda ? AppTheme.error : AppTheme.success;
    final IconData tiempoIcon = tieneDeuda ? LucideIcons.alertTriangle : LucideIcons.checkCircle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ClienteProfileScreen(cliente: cliente)),
          );
        },
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cliente.nombre} ${cliente.apPaterno} ${cliente.apMaterno}'.trim(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: $idFicticio',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical, color: AppTheme.textLight, size: 20),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  onPressed: () => _mostrarOpciones(context, cliente),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Detalles reales del cliente (Celular / Correo)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (cliente.celular.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.smartphone, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(cliente.celular, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
                    ],
                  ),
                if (cliente.correo.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.atSign, size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 4),
                      Text(cliente.correo, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                    ],
                  ),
              ]
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),
            
            // Footer
            Row(
              children: [
                Icon(tiempoIcon, size: 14, color: tiempoColor),
                const SizedBox(width: 6),
                Text(
                  tiempoText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tiempoColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ), // Cierra Padding
      ), // Cierra InkWell
    ); // Cierra Card
  }

  Widget _buildAddCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarModalAlta(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 80, top: 10),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.userPlus, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Añadir Nuevo Cliente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Expande tu red de negocios hoy\nmismo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textLight,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
