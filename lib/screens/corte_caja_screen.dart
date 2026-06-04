import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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

  String _filtro = 'Últimos 7 días';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setDates('Últimos 7 días');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Reportes', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            onPressed: () {}, // Download report
          )
        ],
      ),
      body: StreamBuilder<List<Ticket>>(
        stream: _firebaseService.getTicketsByDateRange(_startDate, _endDate),
        builder: (context, ticketsSnapshot) {
          if (ticketsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tickets = ticketsSnapshot.data ?? [];
          
          double facturacion = 0;
          for (var t in tickets) {
            facturacion += t.totalVenta;
          }
          
          // Simulando margen (ej. 25% de la facturación)
          double margen = facturacion * 0.25;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filtros
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _filtro,
                      icon: const Icon(LucideIcons.calendar),
                      items: ['Hoy', 'Últimos 7 días', 'Este Mes'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _setDates(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Ventas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Grilla de tarjetas principales
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Ventas', tickets.length.toString(), Colors.blue, false)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Facturación', _currencyFormat.format(facturacion), Colors.blue, false)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Margen', _currencyFormat.format(margen), Colors.blue, false)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
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
                                const Text('Productos más Vendidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Ver reporte', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Producto', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                Text('Facturación', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTopProductItem('Pollo Entero', '\$350'),
                            const SizedBox(height: 8),
                            _buildTopProductItem('Carne Molida', '\$210'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                                const Text('Productos con más Margen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Ver reporte', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Producto', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                Text('Margen', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTopProductItem('Queso Oaxaca', '\$120'),
                            const SizedBox(height: 8),
                            _buildTopProductItem('Salsa Habanero', '\$45'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
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
                                const Text('Detalle de Ventas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Ver reporte', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Venta', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (tickets.isNotEmpty) ...[
                              _buildRecentSaleItem(tickets[0]),
                              if (tickets.length > 1) const SizedBox(height: 8),
                              if (tickets.length > 1) _buildRecentSaleItem(tickets[1]),
                            ] else ...[
                              const Center(child: Text('Sin ventas recientes', style: TextStyle(fontSize: 12))),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTopProductItem(String name, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                child: const Icon(LucideIcons.package, size: 14, color: Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentSaleItem(Ticket t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: const Icon(LucideIcons.receipt, size: 14, color: Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Venta #${t.folio ?? ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(_currencyFormat.format(t.totalVenta), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, bool isCurrency) {
    return Container(
      height: 200,
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Ver reporte', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text('\$${value.toInt()}', style: TextStyle(color: Colors.grey.shade400, fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return Text('27 may', style: TextStyle(color: Colors.grey.shade400, fontSize: 9));
                        if (value == 5) return Text('2 jun', style: TextStyle(color: Colors.grey.shade400, fontSize: 9));
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: 150,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 5),
                      FlSpot(1, 6),
                      FlSpot(2, 7),
                      FlSpot(3, 8),
                      FlSpot(4, 30),
                      FlSpot(5, 140),
                    ],
                    isCurved: true,
                    color: Colors.blue.shade400,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400.withOpacity(0.3), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
