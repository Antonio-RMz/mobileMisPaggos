import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../theme/app_theme.dart';
import '../utils/overlay_helper.dart';
import '../widgets/app_drawer.dart';

class CorteCajaScreen extends StatefulWidget {
  const CorteCajaScreen({super.key});

  @override
  State<CorteCajaScreen> createState() => _CorteCajaScreenState();
}

class _CorteCajaScreenState extends State<CorteCajaScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  String _filtro = 'Hoy';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setDates('Hoy');
  }

  void _setDates(String filtro) {
    final now = DateTime.now();
    setState(() {
      _filtro = filtro;
      if (filtro == 'Hoy') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (filtro == 'Esta Semana') {
        _startDate = DateTime(now.year, now.month, now.day - now.weekday + 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (filtro == 'Este Mes') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
        _filtro = 'Personalizado';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Selectores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
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
                  label: Text(_filtro == 'Personalizado' ? '${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}' : 'Rango Personalizado'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)),
                )
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Ticket>>(
              stream: _firebaseService.getTicketsByDateRange(_startDate, _endDate),
              builder: (context, ticketsSnapshot) {
                return StreamBuilder<List<Abono>>(
                  stream: _firebaseService.getAbonosByDateRange(_startDate, _endDate),
                  builder: (context, abonosSnapshot) {
                    if (ticketsSnapshot.connectionState == ConnectionState.waiting || abonosSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tickets = ticketsSnapshot.data ?? [];
                    final abonos = abonosSnapshot.data ?? [];

                    double ventasTotales = 0;
                    double deudaGenerada = 0;

                    for (var t in tickets) {
                      ventasTotales += t.totalVenta;
                      deudaGenerada += t.saldoRestante;
                    }

                    double ingresosReales = 0;
                    for (var a in abonos) {
                      ingresosReales += a.monto;
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          _buildSummaryCard('Ventas Totales (Valor de Mercancía)', ventasTotales, AppTheme.accent),
                          _buildSummaryCard('Ingresos Reales (Efectivo Recibido)', ingresosReales, Colors.green[700]!),
                          _buildSummaryCard('Deuda Generada', deudaGenerada, Colors.red[600]!),
                          
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                              try {
                                await PdfService.generarCorteCajaPdf(_startDate, _endDate, tickets, abonos, ventasTotales, ingresosReales, deudaGenerada);
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
                            label: const Text('Exportar y Compartir', style: TextStyle(color: Colors.white, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                );
              }
            )
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filtro == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) _setDates(label);
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accent : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 8),
          Text(_currencyFormat.format(amount), style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Ticket t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(t.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              if (t.fecha != null)
                Text(DateFormat('dd/MM/yy HH:mm').format(t.fecha!.toDate()), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(t.tipoEntrega == 'Domicilio' ? Icons.two_wheeler : Icons.storefront, size: 16, color: t.tipoEntrega == 'Domicilio' ? Colors.orange : AppTheme.success),
              const SizedBox(width: 6),
              Text(t.tipoEntrega == 'Domicilio' ? 'Repartidor: ${t.repartidorNombre ?? "Asignado"}' : 'Sucursal', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Venta:', style: TextStyle(fontSize: 13)),
              Text(_currencyFormat.format(t.totalVenta), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Abono Inicial:', style: TextStyle(fontSize: 13)),
              Text(_currencyFormat.format(t.totalAbonado), style: const TextStyle(color: AppTheme.success)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo Pendiente:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(_currencyFormat.format(t.saldoRestante), style: TextStyle(color: t.saldoRestante > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
