import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/pdf_report_service.dart';
import '../models/ticket_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class CorteCajaScreen extends StatefulWidget {
  const CorteCajaScreen({super.key});

  @override
  State<CorteCajaScreen> createState() => _CorteCajaScreenState();
}

class _CorteCajaScreenState extends State<CorteCajaScreen> {
  FirebaseService get _firebaseService => Provider.of<FirebaseService>(context, listen: false);
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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
      } else if (filtro == 'Últimos 7 días') {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (filtro == 'Este Mes') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
    });
  }

  Future<void> _seleccionarRango(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
        _filtro = 'Rango personalizado';
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    } else {
      // If cancelled, just keep the previous valid filter
      if (_filtro == 'Rango personalizado') {
        // do nothing, keep current custom dates
      } else {
        // do nothing, keep current predefined filter
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Reportes y Cortes', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textDark),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: 'Corte General', icon: Icon(LucideIcons.barChart2)),
              Tab(text: 'Por Repartidor', icon: Icon(LucideIcons.bike)),
            ],
          ),
        ),
        body: StreamBuilder<List<Ticket>>(
          stream: _firebaseService.getTicketsByDateRange(_startDate, _endDate),
          builder: (context, ticketsSnapshot) {
            if (ticketsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tickets = ticketsSnapshot.data ?? [];

            return Column(
              children: [
                // Filtro de fecha (común para ambas pestañas)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filtro,
                        icon: const Icon(LucideIcons.calendar, color: AppTheme.primary),
                        items: ['Hoy', 'Últimos 7 días', 'Este Mes', 'Rango personalizado'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'Rango personalizado' && _filtro == 'Rango personalizado'
                                  ? 'Rango: ${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}'
                                  : value,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          if (val == 'Rango personalizado') {
                            await _seleccionarRango(context);
                          } else if (val != null) {
                            _setDates(val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCorteGeneralTab(tickets),
                      _buildCorteRepartidorTab(tickets),
                    ],
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildCorteGeneralTab(List<Ticket> tickets) {
    double totalGeneral = 0;
    double totalDomicilio = 0;
    double totalLocal = 0;
    double totalEfectivo = 0;
    double totalTransferencia = 0;

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') {
        totalGeneral += t.totalVenta;
        if (t.tipoEntrega == 'Domicilio') {
          totalDomicilio += t.totalVenta;
        } else {
          totalLocal += t.totalVenta;
        }
        if (t.metodoPago == 'Transferencia') {
          totalTransferencia += t.totalVenta;
        } else {
          totalEfectivo += t.totalVenta;
        }
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Ventas Totales', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      _currencyFormat.format(totalGeneral),
                      style: const TextStyle(color: AppTheme.textDark, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('Local', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalLocal), style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(height: 40, width: 2, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Domicilio', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalDomicilio), style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('Efectivo', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalEfectivo), style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(height: 40, width: 2, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Transferencia', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalTransferencia), style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    PdfReportService.generateCorteGeneralPdf(tickets, _filtro);
                  },
                  icon: const Icon(LucideIcons.printer, color: Colors.white),
                  label: const Text('Generar PDF Corte General', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text('Últimos Movimientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              ),
            ],
          ),
        ),
        if (tickets.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No hay ventas en este rango de fechas.', style: TextStyle(color: Colors.grey, fontSize: 16))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = tickets.reversed.toList()[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: t.tipoEntrega == 'Domicilio' ? Colors.orange.shade100 : Colors.blue.shade100,
                        child: Icon(t.tipoEntrega == 'Domicilio' ? LucideIcons.bike : LucideIcons.store, 
                          color: t.tipoEntrega == 'Domicilio' ? Colors.orange : Colors.blue, size: 24),
                      ),
                      title: Text(t.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(t.tipoEntrega, style: const TextStyle(fontSize: 14)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currencyFormat.format(t.totalVenta), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (t.estadoEntrega == 'Cancelado')
                            const Text('Cancelado', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
                childCount: tickets.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCorteRepartidorTab(List<Ticket> tickets) {
    Map<String, List<Ticket>> ticketsPorRepartidor = {};

    for (var t in tickets) {
      if (t.tipoEntrega == 'Domicilio' && t.repartidorNombre != null && t.repartidorNombre!.isNotEmpty) {
        String repartidor = t.repartidorNombre!;
        if (!ticketsPorRepartidor.containsKey(repartidor)) {
          ticketsPorRepartidor[repartidor] = [];
        }
        ticketsPorRepartidor[repartidor]!.add(t);
      }
    }

    var repartidores = ticketsPorRepartidor.keys.toList()..sort();

    return repartidores.isEmpty
        ? const Center(child: Text('No hay pedidos de repartidores en este rango.', style: TextStyle(color: Colors.grey, fontSize: 16)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: repartidores.length,
            itemBuilder: (context, index) {
              final repartidor = repartidores[index];
              final ticketsRep = ticketsPorRepartidor[repartidor]!;
              
              double totalAsignado = 0;
              double totalEntregado = 0;
              double totalPendiente = 0;
              double totalEfectivo = 0;
              double totalTransferencia = 0;
              int countCompletados = 0;
              int countPendientes = 0;
              int countCancelados = 0;

              for (var t in ticketsRep) {
                if (t.estadoEntrega == 'Cancelado') {
                  countCancelados++;
                } else {
                  totalAsignado += t.totalVenta;
                  if (t.pagoRepartidorConfirmado) {
                    countCompletados++;
                    totalEntregado += t.totalVenta;
                    if (t.metodoPago == 'Transferencia') {
                      totalTransferencia += t.totalVenta;
                    } else {
                      totalEfectivo += t.totalVenta;
                    }
                  } else {
                    countPendientes++;
                    totalPendiente += t.totalVenta;
                  }
                }
              }

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            radius: 24,
                            child: const Icon(LucideIcons.user, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(repartidor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          IconButton(
                            iconSize: 24,
                            icon: const Icon(LucideIcons.printer, color: AppTheme.primary),
                            onPressed: () {
                              PdfReportService.generateCorteRepartidorPdf(repartidor, ticketsRep, _filtro);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Confirmado', countCompletados, Colors.green),
                          _buildMiniStat('Pendiente', countPendientes, Colors.orange),
                          _buildMiniStat('Cancelado', countCancelados, Colors.red),
                        ],
                      ),
                      const Divider(height: 32, thickness: 1.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Venta Asignada', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalAsignado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Faltante', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalPendiente), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Recibido', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalEntregado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                            ],
                          ),
                        ],
                      ),
                      if (totalEfectivo > 0 || totalTransferencia > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (totalEfectivo > 0)
                              Text('Efectivo: ${_currencyFormat.format(totalEfectivo)}  ', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                            if (totalTransferencia > 0)
                              Text('Transferencia: ${_currencyFormat.format(totalTransferencia)}', style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
      ],
    );
  }
}
