import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/ticket_model.dart';
import '../theme/app_theme.dart';
import '../providers/printer_provider.dart';
import '../services/firebase_service.dart';
import '../providers/user_provider.dart';
import 'nuevo_pedido_screen.dart';

class VentasListScreen extends StatefulWidget {
  const VentasListScreen({super.key});

  @override
  State<VentasListScreen> createState() => _VentasListScreenState();
}

class _VentasListScreenState extends State<VentasListScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final dateFormat = DateFormat('dd MMM, HH:mm');
  final soloFechaFormat = DateFormat('dd MMM yyyy');
  String _searchQuery = '';

  DateTime _fechaInicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _fechaFin = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);

  Future<void> _seleccionarRango(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  Stream<List<Ticket>> _getTicketsStream() {
    final empresaId = Provider.of<UserProvider>(context, listen: false).empresaId;
    return FirebaseFirestore.instance
        .collection('tickets')
        .where('empresaId', isEqualTo: empresaId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data())).toList();
      
      final filtrados = list.where((t) {
        if (t.fecha == null) return false;
        final f = t.fecha!.toDate();
        if (f.isBefore(_fechaInicio) || f.isAfter(_fechaFin)) return false;
        return true;
      }).toList();

      filtrados.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return filtrados;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Ventas'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130), // Altura ajustada para el buscador y fecha
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Filtrar por cliente, folio...',
                      prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: InkWell(
                    onTap: () => _seleccionarRango(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${soloFechaFormat.format(_fechaInicio)} - ${soloFechaFormat.format(_fechaFin)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Ticket>>(
        stream: _getTicketsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay ventas registradas.'));
          }

          var allTickets = snapshot.data!;
          if (_searchQuery.isNotEmpty) {
            allTickets = allTickets.where((t) =>
                t.clienteNombre.toLowerCase().contains(_searchQuery) ||
                (t.folio?.toLowerCase().contains(_searchQuery) ?? false)).toList();
          }

          return _buildList(allTickets);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NuevoPedidoScreen()));
        },
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('NUEVA VENTA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.accent,
      ),
    );
  }

  Widget _buildList(List<Ticket> tickets) {
    if (tickets.isEmpty) return const Center(child: Text('No hay resultados.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final t = tickets[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _mostrarDetallesTicket(context, t),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '#${t.folio ?? "S/F"}   ${t.clienteNombre}', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              currencyFormat.format(t.totalVenta), 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.fecha != null ? dateFormat.format(t.fecha!.toDate()) : 'Sin fecha', 
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarDetallesTicket(BuildContext context, Ticket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Detalles del Pedido', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  Text('#${ticket.folio}', style: const TextStyle(fontSize: 16, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Cliente: ${ticket.clienteNombre}', style: const TextStyle(fontSize: 16)),
              Text('Fecha: ${ticket.fecha != null ? dateFormat.format(ticket.fecha!.toDate()) : 'S/F'}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              if (ticket.tipoEntrega == 'Domicilio' && ticket.repartidorNombre != null) ...[
                const SizedBox(height: 4),
                Text('Repartidor: ${ticket.repartidorNombre}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              ],
              const Divider(height: 32),
              const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: ticket.productos.length,
                  itemBuilder: (context, i) {
                    final p = ticket.productos[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ${p.descripcionAmigable}', style: const TextStyle(fontSize: 14)),
                                if (p.observaciones.isNotEmpty)
                                  Text('  * ${p.observaciones}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(currencyFormat.format(p.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Venta:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(currencyFormat.format(ticket.totalVenta), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final printer = Provider.of<PrinterProvider>(context, listen: false);
                    if (printer.isConnected) {
                      printer.printDeliveryTicket(ticket);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Imprimiendo ticket...')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impresora no conectada.'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.printer, color: Colors.white),
                  label: const Text('Imprimir Ticket', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (ticket.estadoEntrega != 'Cancelado') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmarCancelacion(context, ticket),
                    icon: const Icon(LucideIcons.xCircle, color: AppTheme.error),
                    label: const Text('Cancelar Venta', style: TextStyle(color: AppTheme.error, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmarCancelacion(BuildContext context, Ticket ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Venta', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas cancelar la venta #${ticket.folio}? Esta acción no se puede deshacer y se revertirá la deuda del cliente si la hubiera.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Atrás', style: TextStyle(color: AppTheme.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Cierra dialog
              Navigator.pop(context); // Cierra modal
              try {
                await Provider.of<FirebaseService>(context, listen: false).cancelarTicket(ticket, 'Cancelado por el usuario desde la app');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Venta cancelada exitosamente')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sí, Cancelar Venta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
