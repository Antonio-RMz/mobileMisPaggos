import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/ticket_model.dart';
import '../theme/app_theme.dart';
import '../providers/printer_provider.dart';
import '../utils/string_utils.dart';
import '../services/firebase_service.dart';
import '../providers/user_provider.dart';
import '../utils/overlay_helper.dart';
import 'nuevo_pedido_screen.dart';

class VentasListScreen extends StatefulWidget {
  final String? filtroEstadoInicial;
  const VentasListScreen({super.key, this.filtroEstadoInicial});

  @override
  State<VentasListScreen> createState() => _VentasListScreenState();
}

class _VentasListScreenState extends State<VentasListScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final dateFormat = DateFormat('dd MMM, HH:mm');
  final soloFechaFormat = DateFormat('dd MMM yyyy');
  String _searchQuery = '';
  
  String _filtroRepartidor = 'Todos';

  DateTime _fechaInicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _fechaFin = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);

  @override
  void initState() {
    super.initState();
  }

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
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary, // This makes the "Guardar/Save" button text visible
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
        
        if (_filtroRepartidor != 'Todos' && (t.repartidorNombre ?? '') != _filtroRepartidor) return false;
        
        return true;
      }).toList();

      filtrados.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return filtrados;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ticket>>(
      stream: _getTicketsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var allTickets = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          final queryNorm = StringUtils.removeDiacritics(_searchQuery.toLowerCase().trim());
          allTickets = allTickets.where((t) {
            final nombreNorm = StringUtils.removeDiacritics(t.clienteNombre.toLowerCase());
            final folioNorm = t.folio != null ? StringUtils.removeDiacritics(t.folio!.toLowerCase()) : '';
            return nombreNorm.contains(queryNorm) || folioNorm.contains(queryNorm);
          }).toList();
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          appBar: AppBar(
            title: const Text('Ventas'),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppTheme.textDark),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(130), // Altura ajustada para filtros
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
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
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: InkWell(
                                onTap: () => _seleccionarRango(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${soloFechaFormat.format(_fechaInicio)} - ${soloFechaFormat.format(_fechaFin)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Row(
                                  children: [
                                    _buildBotonFiltroRepartidor(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: allTickets.isEmpty 
              ? const Center(child: Text('No hay ventas registradas.'))
              : _buildList(allTickets),
          bottomNavigationBar: _buildBottomFloatingWidget(allTickets),
        );
      },
    );
  }

  Widget _buildList(List<Ticket> tickets) {
    if (tickets.isEmpty) return const Center(child: Text('No hay resultados.'));
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.builder(
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
                        Row(
                          children: [
                            Text(
                              t.fecha != null ? dateFormat.format(t.fecha!.toDate()) : 'Sin fecha', 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            if (t.estadoEntrega == 'Cancelado') ...[
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                 child: const Text('Cancelado', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                               )
                            ]
                          ],
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
        ),
      ),
    );
  }


  void _mostrarDetallesTicket(BuildContext context, Ticket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool esCatalogoConDeuda = ticket.productos.any((p) => p.seccion != 'carniceria') && ticket.estado == 'Con Deuda';
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
              if (ticket.estado != 'Pagado' && ticket.estadoEntrega != 'Cancelado' && !esCatalogoConDeuda) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _liquidarPorTransferencia(ticket);
                    },
                    icon: const Icon(LucideIcons.banknote, color: Colors.blue),
                    label: const Text('Cobrado por Transferencia', style: TextStyle(color: Colors.blue, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              if (ticket.estado != 'Pagado' && ticket.estadoEntrega != 'Cancelado' && !ticket.deudaManualAsignada && !esCatalogoConDeuda) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _marcarComoPendienteDePago(ticket);
                    },
                    icon: const Icon(LucideIcons.clock, color: Colors.orange),
                    label: const Text('Marcar como Pendiente de Pago', style: TextStyle(color: Colors.orange, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
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

  void _marcarComoPendienteDePago(Ticket ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pendiente de Pago', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: const Text('¿Confirmas que este pedido será marcado como pendiente de pago?\n\nAl confirmar, se sumará a la deuda del cliente (Atención Prioritaria) y el repartidor quedará liberado de este cobro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              final safeContext = this.context;
              if (!safeContext.mounted) return;
              
              showDialog(context: safeContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              try {
                await Provider.of<FirebaseService>(safeContext, listen: false).marcarTicketComoDeudaCliente(ticket);
                if (safeContext.mounted) {
                  Navigator.pop(safeContext); // cerrar loading
                  OverlayHelper.showSuccess(safeContext, message: 'Enviado a Deuda del Cliente');
                }
              } catch(e) {
                if (safeContext.mounted) {
                  Navigator.pop(safeContext);
                  OverlayHelper.showError(safeContext, message: 'Error: $e');
                }
              }
            },
            child: const Text('Sí, Confirmar', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _confirmarCancelacion(BuildContext context, Ticket ticket) {
    final TextEditingController pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Venta', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('¿Estás seguro de que deseas cancelar la venta #${ticket.folio}? Esta acción no se puede deshacer y se revertirá la deuda del cliente si la hubiera.'),
             const SizedBox(height: 16),
             TextField(
               controller: pinCtrl,
               obscureText: true,
               keyboardType: TextInputType.number,
               decoration: const InputDecoration(labelText: 'PIN de autorización', border: OutlineInputBorder()),
               autofocus: true,
             ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Atrás', style: TextStyle(color: AppTheme.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinCtrl.text != '1234') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrecto'), backgroundColor: AppTheme.error));
                return;
              }
              Navigator.pop(ctx); // Cierra dialog
              Navigator.pop(context); // Cierra modal
              final safeContext = this.context;
              if (!safeContext.mounted) return;
              
              try {
                await Provider.of<FirebaseService>(safeContext, listen: false).cancelarTicket(ticket, 'Cancelado por el usuario desde la app');
                if (safeContext.mounted) {
                  OverlayHelper.showSuccess(safeContext, message: 'Venta Cancelada Exitosamente');
                }
              } catch (e) {
                if (safeContext.mounted) {
                  OverlayHelper.showError(safeContext, message: 'Error al cancelar: $e');
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

  void _liquidarPorTransferencia(Ticket ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cobro por Transferencia', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        content: const Text('¿Confirmas que este pedido ya fue liquidado vía transferencia bancaria?\n\nAl confirmar, este saldo no se le cobrará físicamente al repartidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, volver', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              Navigator.pop(ctx);
              final safeContext = this.context;
              if (!safeContext.mounted) return;
              
              showDialog(context: safeContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              try {
                await Provider.of<FirebaseService>(safeContext, listen: false).marcarTicketComoTransferencia(ticket);
                if (safeContext.mounted) {
                  Navigator.pop(safeContext); // cerrar loading
                  OverlayHelper.showSuccess(safeContext, message: 'Transferencia Registrada');
                }
              } catch(e) {
                if (safeContext.mounted) {
                  Navigator.pop(safeContext);
                  OverlayHelper.showError(safeContext, message: 'Error: $e');
                }
              }
            },
            child: const Text('Sí, Confirmar', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  Widget _buildDropdownFiltro(String label, List<String> opciones, String valor, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: valor != 'Todos' ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: valor != 'Todos' ? AppTheme.primary.withOpacity(0.5) : Colors.transparent),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: valor != 'Todos' ? AppTheme.primary : Colors.grey),
          isDense: true,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valor != 'Todos' ? AppTheme.primary : AppTheme.textDark),
          onChanged: onChanged,
          items: opciones.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'Todos' ? label : value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBotonFiltroRepartidor() {
    return InkWell(
      onTap: () async {
        final firebaseService = Provider.of<FirebaseService>(context, listen: false);
        final list = await firebaseService.getPersonalStream().first;
        final nombres = list.where((p) => p.rol.toLowerCase() == 'repartidor').map((p) => p.nombre).toList();
        
        if (!mounted) return;
        
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) {
            return ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Filtrar por Repartidor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: const Text('Todos'),
                  trailing: _filtroRepartidor == 'Todos' ? const Icon(Icons.check, color: AppTheme.primary) : null,
                  onTap: () {
                    setState(() => _filtroRepartidor = 'Todos');
                    Navigator.pop(ctx);
                  },
                ),
                ...nombres.map((n) => ListTile(
                  title: Text(n),
                  trailing: _filtroRepartidor == n ? const Icon(Icons.check, color: AppTheme.primary) : null,
                  onTap: () {
                    setState(() => _filtroRepartidor = n);
                    Navigator.pop(ctx);
                  },
                )),
              ],
            );
          }
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _filtroRepartidor != 'Todos' ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _filtroRepartidor != 'Todos' ? AppTheme.primary.withOpacity(0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.bike, size: 16, color: _filtroRepartidor != 'Todos' ? AppTheme.primary : AppTheme.textDark),
            const SizedBox(width: 8),
            Text(
              _filtroRepartidor == 'Todos' ? 'Repartidor' : _filtroRepartidor,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _filtroRepartidor != 'Todos' ? AppTheme.primary : AppTheme.textDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomFloatingWidget(List<Ticket> tickets) {
    double totalVentas = 0;
    double totalAbonado = 0;
    double totalPendiente = 0;
    
    List<String> ticketIds = [];
    
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') {
        totalVentas += t.totalVenta;
        totalAbonado += t.totalAbonado;
        if (!t.pagoRepartidorConfirmado && t.saldoRestante > 0) {
          totalPendiente += t.saldoRestante;
          ticketIds.add(t.id);
        }
      }
    }

    bool hasRepartidor = _filtroRepartidor != 'Todos';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16).copyWith(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(currencyFormat.format(totalVentas), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Abonado', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(currencyFormat.format(totalAbonado), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Pendiente', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(currencyFormat.format(totalPendiente), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                        ],
                      ),
                      if (hasRepartidor) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _mostrarDialogoAbonoRepartidor(context, _filtroRepartidor, totalPendiente, ticketIds),
                            icon: const Icon(LucideIcons.banknote, color: Colors.white, size: 20),
                            label: const Text('Abonar Dinero', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoAbonoRepartidor(BuildContext contextOriginal, String repartidorNombre, double totalDeuda, List<String> ticketIds) {
    final TextEditingController abonoCtrl = TextEditingController();
    showDialog(
      context: contextOriginal,
      builder: (ctxAbono) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Abono - $repartidorNombre', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deuda actual: ${currencyFormat.format(totalDeuda)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 16),
              TextField(
                controller: abonoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto a entregar (\$)', prefixText: '\$ ', border: OutlineInputBorder()),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctxAbono), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final double monto = double.tryParse(abonoCtrl.text) ?? 0.0;
                
                if (monto > totalDeuda) {
                  OverlayHelper.showError(contextOriginal, message: 'El abono no puede ser mayor a la deuda de ${currencyFormat.format(totalDeuda)}');
                  return;
                }
                
                if (monto > 0) {
                  Navigator.pop(ctxAbono); // cierra modal del monto
                  
                  // Confirmacion
                  showDialog(
                    context: contextOriginal,
                    builder: (ctxConfirm) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Confirmar Abono', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      content: Text('¿Confirmas un abono de ${currencyFormat.format(monto)} por parte de $repartidorNombre?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctxConfirm),
                          child: const Text('No, corregir', style: TextStyle(color: Colors.redAccent)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                          onPressed: () async {
                            Navigator.pop(ctxConfirm);
                            
                            final safeContext = this.context;
                            if (!safeContext.mounted) return;
                            
                            showDialog(context: safeContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                            
                            try {
                              final firebaseService = Provider.of<FirebaseService>(safeContext, listen: false);
                              await firebaseService.registrarAbonoRepartidor(repartidorNombre, monto, ticketIdsToPay: ticketIds);
                              if (safeContext.mounted) {
                                Navigator.pop(safeContext); // cerrar loading
                                OverlayHelper.showSuccess(safeContext, message: 'Abono registrado exitosamente');
                              }
                            } catch (e) {
                              if (safeContext.mounted) {
                                Navigator.pop(safeContext); // cerrar loading
                                OverlayHelper.showError(safeContext, message: 'Error: $e');
                              }
                            }
                          },
                          child: const Text('Sí, Confirmar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Siguiente'),
            ),
          ],
        );
      },
    );
  }
}
