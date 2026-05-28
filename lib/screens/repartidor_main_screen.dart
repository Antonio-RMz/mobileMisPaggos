import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/overlay_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'login_screen.dart';

class RepartidorMainScreen extends StatefulWidget {
  const RepartidorMainScreen({super.key});

  @override
  State<RepartidorMainScreen> createState() => _RepartidorMainScreenState();
}

class _RepartidorMainScreenState extends State<RepartidorMainScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final DateFormat _dateFormatShort = DateFormat('dd MMM yyyy');

  String _filtroHistorial = 'Hoy';
  DateTime _historialStart = DateTime.now();
  DateTime _historialEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setHistorialDates('Hoy');
  }

  void _setHistorialDates(String filtro) {
    final now = DateTime.now();
    setState(() {
      _filtroHistorial = filtro;
      if (filtro == 'Hoy') {
        _historialStart = DateTime(now.year, now.month, now.day);
        _historialEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (filtro == 'Esta Semana') {
        _historialStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
        _historialEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (filtro == 'Este Mes') {
        _historialStart = DateTime(now.year, now.month, 1);
        _historialEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
    });
  }

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _filtroHistorial = 'Personalizado';
        _historialStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _historialEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final repartidorId = authProvider.repartidorId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Panel de Repartidor', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: AppTheme.error),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                await authProvider.logout();
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textLight,
            tabs: [
              Tab(text: 'Pendientes', icon: Icon(Icons.two_wheeler)),
              Tab(text: 'Historial', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildDashboard(repartidorId),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPendientes(repartidorId),
                  _buildHistorial(repartidorId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(String repartidorId) {
    // Para las ventas de hoy
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return StreamBuilder<List<Ticket>>(
      stream: _firebaseService.getTicketsByDateRange(startOfDay, endOfDay),
      builder: (context, snapshot) {
        double totalHoy = 0.0;
        int entregasHoy = 0;

        if (snapshot.hasData) {
          final ticketsHoy = snapshot.data!.where((t) => t.repartidorId == repartidorId && t.estadoEntrega == 'Entregado').toList();
          entregasHoy = ticketsHoy.length;
          totalHoy = ticketsHoy.fold(0.0, (sum, t) => sum + t.totalVenta);
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Cobrado Hoy', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_currencyFormat.format(totalHoy), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                    const SizedBox(height: 4),
                    Text('$entregasHoy entregas', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendientes(String repartidorId) {
    // Usamos getTicketsByDateRange desde hace 7 días para no cargar toda la BD
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    
    return StreamBuilder<List<Ticket>>(
      stream: _firebaseService.getTicketsByDateRange(start, now.add(const Duration(days: 1))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final pendientes = snapshot.data!.where((t) => t.repartidorId == repartidorId && t.estadoEntrega == 'Pendiente').toList();

        if (pendientes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.thumb_up_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('¡No tienes entregas pendientes!', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendientes.length,
          itemBuilder: (context, index) {
            final ticket = pendientes[index];
            return _buildTicketCard(ticket, isPendiente: true);
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filtroHistorial == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) _setHistorialDates(label);
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accent : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildHistorial(String repartidorId) {
    return Column(
      children: [
        // Selectores de fecha
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterChip('Hoy'),
                  _buildFilterChip('Esta Semana'),
                  _buildFilterChip('Este Mes'),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _seleccionarRangoFechas,
                icon: const Icon(LucideIcons.calendar),
                label: Text(_filtroHistorial == 'Personalizado' ? '${_dateFormatShort.format(_historialStart)} - ${_dateFormatShort.format(_historialEnd)}' : 'Rango Personalizado'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)),
              )
            ],
          ),
        ),
        
        Expanded(
          child: StreamBuilder<List<Ticket>>(
            stream: _firebaseService.getTicketsEntregadosByRepartidor(repartidorId, _historialStart, _historialEnd),
            builder: (context, ticketsSnapshot) {
              return StreamBuilder<List<Abono>>(
                stream: _firebaseService.getAbonosByRepartidor(repartidorId, _historialStart, _historialEnd),
                builder: (context, abonosSnapshot) {
                  if (ticketsSnapshot.connectionState == ConnectionState.waiting || abonosSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final historial = ticketsSnapshot.data ?? [];
                  final abonos = abonosSnapshot.data ?? [];

                  return Stack(
                    children: [
                      if (historial.isEmpty)
                        const Center(child: Text('No hay entregas en este periodo.', style: TextStyle(color: AppTheme.textLight)))
                      else
                        ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                          itemCount: historial.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(historial[index], isPendiente: false);
                          },
                        ),
                      
                      if (historial.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                              try {
                                final authProvider = context.read<AuthProvider>();
                                final repartidorNombre = 'Repartidor';
                                await PdfService.generarCorteRepartidorPdf(repartidorNombre, _historialStart, _historialEnd, historial, abonos);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  OverlayHelper.showSuccess(context, message: 'Reporte Generado');
                                }
                              } catch(e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  OverlayHelper.showError(context, message: 'Error: $e');
                                }
                              }
                            },
                            icon: const Icon(LucideIcons.fileText, color: Colors.white),
                            label: const Text('Exportar mi Corte (PDF)', style: TextStyle(color: Colors.white, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  );
                }
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Ticket ticket, {required bool isPendiente}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ticket.clienteNombre.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPendiente ? Colors.orange.withOpacity(0.1) : AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPendiente ? 'Pendiente' : 'Entregado',
                    style: TextStyle(
                      color: isPendiente ? Colors.orange : AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ticket.fecha != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppTheme.textLight),
                  const SizedBox(width: 4),
                  Text(_dateFormat.format(ticket.fecha!.toDate()), style: const TextStyle(color: AppTheme.textLight, fontSize: 13)),
                ],
              ),
            const Divider(height: 24),
            Text('Productos (${ticket.productos.length}):', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight, fontSize: 12)),
            const SizedBox(height: 8),
            ...ticket.productos.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${p.cantidad.toStringAsFixed(1)} x ${p.nombre}', style: const TextStyle(fontSize: 14)),
                  Text(_currencyFormat.format(p.precioUnitario * p.cantidad), style: const TextStyle(fontSize: 14)),
                ],
              ),
            )).toList(),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('A Cobrar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_currencyFormat.format(ticket.totalVenta), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.accent)),
              ],
            ),
            if (isPendiente) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.point_of_sale, color: Colors.white),
                  label: const Text('Cobrar Pedido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () => _mostrarDialogoCobro(context, ticket),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () => _mostrarDialogoCancelacion(context, ticket),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoCobro(BuildContext context, Ticket ticket) async {
    final TextEditingController montoRecibidoCtrl = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final double montoRecibido = double.tryParse(montoRecibidoCtrl.text) ?? 0.0;
            final double cambio = montoRecibido - ticket.totalVenta;
            final bool esValido = montoRecibido >= ticket.totalVenta;

            return AlertDialog(
              title: const Text('Cobrar Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total a cobrar:', style: TextStyle(color: Colors.grey[700])),
                    Text(_currencyFormat.format(ticket.totalVenta), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: montoRecibidoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      onChanged: (v) => setStateDialog(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Monto Recibido',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (montoRecibido > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: esValido ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(esValido ? 'Cambio a devolver:' : 'Faltante:', style: TextStyle(fontWeight: FontWeight.bold, color: esValido ? Colors.green[800] : Colors.red[800])),
                            Text(
                              _currencyFormat.format(cambio.abs()),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: esValido ? Colors.green[800] : Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: esValido ? AppTheme.success : Colors.grey),
                  onPressed: esValido ? () => Navigator.pop(context, true) : null,
                  child: const Text('Confirmar Cobro', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      try {
        await _firebaseService.marcarPedidoEntregado(ticket);
        if (mounted) {
          Navigator.pop(context); // Cierra loading
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido cobrado y notificado al administrador.'), backgroundColor: AppTheme.success));
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cierra loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _mostrarDialogoCancelacion(BuildContext context, Ticket ticket) async {
    final TextEditingController motivoCtrl = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar Pedido', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro de que deseas cancelar este pedido? Se descontará la deuda del cliente y no se entregará la mercancía.'),
              const SizedBox(height: 16),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de Cancelación (Requerido)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Atrás', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () {
                if (motivoCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, escribe un motivo de cancelación.'), backgroundColor: Colors.orange));
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Cancelar Pedido', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      try {
        await _firebaseService.cancelarPedido(ticket, motivoCtrl.text.trim());
        if (mounted) {
          Navigator.pop(context); // Cierra loading
          OverlayHelper.showSuccess(context, message: 'Pedido Cancelado Exitosamente');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cierra loading
          OverlayHelper.showError(context, message: 'Error: $e');
        }
      }
    }
  }
}
