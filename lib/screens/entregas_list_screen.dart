import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class EntregasListScreen extends StatefulWidget {
  final String title;
  final String estadoEntregaFiltro;

  const EntregasListScreen({
    super.key,
    required this.title,
    required this.estadoEntregaFiltro,
  });

  @override
  State<EntregasListScreen> createState() => _EntregasListScreenState();
}

class _EntregasListScreenState extends State<EntregasListScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final dateFormat = DateFormat('dd MMM, HH:mm');
  final soloFechaFormat = DateFormat('dd MMM yyyy');

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

  Stream<List<Ticket>> _getEntregasStream() {
    final empresaId = Provider.of<UserProvider>(context, listen: false).empresaId;
    return FirebaseFirestore.instance
        .collection('tickets')
        .where('empresaId', isEqualTo: empresaId)
        .where('tipoEntrega', isEqualTo: 'Domicilio')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data())).toList();
      
      final filtrados = list.where((t) {
        if (t.fecha == null) return false;
        final f = t.fecha!.toDate();
        if (f.isBefore(_fechaInicio) || f.isAfter(_fechaFin)) return false;

        if (widget.estadoEntregaFiltro == 'Cancelado') {
          return t.estadoEntrega == 'Cancelado';
        } else if (widget.estadoEntregaFiltro == 'Completados') {
          return t.pagoRepartidorConfirmado == true && t.estadoEntrega != 'Cancelado';
        } else {
          // Pendiente
          return t.pagoRepartidorConfirmado == false && t.estadoEntrega != 'Cancelado';
        }
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
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ),
      ),
      body: StreamBuilder<List<Ticket>>(
        stream: _getEntregasStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay entregas en esta categoría.'));
          }

          final tickets = snapshot.data!;

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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                        'Repartidor: ${t.repartidorNombre ?? "Sin asignar"}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      Text(
                        'Fecha: ${t.fecha != null ? dateFormat.format(t.fecha!.toDate()) : "Sin fecha"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      if (widget.estadoEntregaFiltro == 'Cancelado' && t.motivoCancelacion != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Motivo: ${t.motivoCancelacion}',
                          style: const TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ],
                      // Mostrar switch si está en Reparto y debe dinero
                      if (widget.estadoEntregaFiltro == 'Pendiente' && t.saldoRestante > 0) ...[
                        const Divider(height: 24),
                        SwitchListTile(
                          title: const Text('Efectivo Recibido', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          value: t.pagoRepartidorConfirmado && t.metodoPago == 'Efectivo',
                          activeColor: AppTheme.success,
                          contentPadding: EdgeInsets.zero,
                          onChanged: t.pagoRepartidorConfirmado
                              ? null
                              : (value) => _confirmarRecepcionDinero(context, t),
                        ),
                        SwitchListTile(
                          title: const Text('Pago por Transferencia', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          value: t.pagoRepartidorConfirmado && t.metodoPago == 'Transferencia',
                          activeColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: t.pagoRepartidorConfirmado
                              ? null
                              : (value) => _confirmarRecepcionTransferencia(context, t),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmarRecepcionDinero(BuildContext context, Ticket ticket) {
    final monto = currencyFormat.format(ticket.saldoRestante);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Recepción', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Confirmas la recepción de $monto del ticket #${ticket.folio} del repartidor ${ticket.repartidorNombre}?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final userName = Provider.of<UserProvider>(context, listen: false).nombre;
                await Provider.of<FirebaseService>(context, listen: false).confirmarPagoRepartidor(ticket, metodoPago: 'Efectivo', cobradoPor: userName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pago confirmado correctamente en Efectivo.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Sí, Confirmar Efectivo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarRecepcionTransferencia(BuildContext context, Ticket ticket) {
    final monto = currencyFormat.format(ticket.saldoRestante);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Transferencia', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de confirmar que recibiste una TRANSFERENCIA de $monto por el ticket #${ticket.folio}?\n\nEste método de pago se reflejará en los reportes.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final userName = Provider.of<UserProvider>(context, listen: false).nombre;
                await Provider.of<FirebaseService>(context, listen: false).confirmarPagoRepartidor(ticket, metodoPago: 'Transferencia', cobradoPor: userName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pago por Transferencia confirmado.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Sí, Confirmar Transferencia', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
