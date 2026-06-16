import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/pdf_report_service.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../models/gasto_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../utils/overlay_helper.dart';
import 'dashboard_screen.dart';

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
  bool _isUnlocked = false;
  final TextEditingController _pinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setDates('Hoy');
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
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
    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Reportes (Bloqueado)'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.lock, size: 80, color: AppTheme.primary),
                const SizedBox(height: 24),
                const Text('Esta sección contiene información sensible.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '****',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_pinCtrl.text == '1234') {
                      setState(() {
                        _isUnlocked = true;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrecto'), backgroundColor: Colors.red));
                      _pinCtrl.clear();
                    }
                  },
                  child: const Text('Desbloquear Reportes', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Reportes y Cortes'),
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
            return StreamBuilder<List<Abono>>(
              stream: _firebaseService.getAbonosByDateRange(_startDate, _endDate),
              builder: (context, abonosSnapshot) {
                return StreamBuilder<List<Gasto>>(
                  stream: _firebaseService.getGastosByDateRange(_startDate, _endDate),
                  builder: (context, gastosSnapshot) {
                    if (ticketsSnapshot.connectionState == ConnectionState.waiting || 
                        abonosSnapshot.connectionState == ConnectionState.waiting ||
                        gastosSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tickets = ticketsSnapshot.data ?? [];
                    final abonos = abonosSnapshot.data ?? [];
                    final gastos = gastosSnapshot.data ?? [];

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
                              _buildCorteGeneralTab(tickets, abonos, gastos),
                              _buildCorteRepartidorTab(tickets, abonos),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                );
              }
            );
          }
        ),
      ),
    );
  }

  void _mostrarDialogoRegistrarGasto(BuildContext contextOriginal) {
    final TextEditingController conceptoCtrl = TextEditingController();
    final TextEditingController montoCtrl = TextEditingController();
    final TextEditingController pinCtrl = TextEditingController();
    
    showDialog(
      context: contextOriginal,
      builder: (ctxGasto) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registrar Salida de Dinero (Gasto)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: conceptoCtrl,
                decoration: const InputDecoration(labelText: 'Concepto (Ej. Gasolina, Bolsas)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                decoration: const InputDecoration(labelText: 'Monto a retirar', prefixText: '\$'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: 'PIN de Confirmación'),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctxGasto),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                final concepto = conceptoCtrl.text.trim();
                final montoStr = montoCtrl.text.trim();

                if (concepto.isEmpty || montoStr.isEmpty || pin.isEmpty) {
                  ScaffoldMessenger.of(contextOriginal).showSnackBar(const SnackBar(content: Text('Por favor llena todos los campos')));
                  return;
                }

                if (pin != '1234') {
                  ScaffoldMessenger.of(contextOriginal).showSnackBar(const SnackBar(content: Text('PIN Incorrecto')));
                  return;
                }

                final monto = double.tryParse(montoStr);
                if (monto == null || monto <= 0) {
                  ScaffoldMessenger.of(contextOriginal).showSnackBar(const SnackBar(content: Text('Monto inválido')));
                  return;
                }

                try {
                  Navigator.pop(ctxGasto);
                  showDialog(context: contextOriginal, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                  
                  final fireService = Provider.of<FirebaseService>(contextOriginal, listen: false);
                  await fireService.registrarGasto(concepto, monto);

                  if (contextOriginal.mounted) {
                    Navigator.of(contextOriginal, rootNavigator: true).pop();
                    ScaffoldMessenger.of(contextOriginal).showSnackBar(const SnackBar(content: Text('Gasto registrado correctamente')));
                  }
                } catch (e) {
                  if (contextOriginal.mounted) {
                    Navigator.of(contextOriginal, rootNavigator: true).pop();
                    ScaffoldMessenger.of(contextOriginal).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Registrar Gasto', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  void _mostrarDialogoAbonoRepartidor(BuildContext contextOriginal, String repartidorNombre, double totalDeuda, List<String> ticketIds) {
    final TextEditingController abonoCtrl = TextEditingController();
    showDialog(
      context: contextOriginal,
      builder: (ctxAbono) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Entrega Efectivo - $repartidorNombre', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Debe a Caja actual: ${_currencyFormat.format(totalDeuda)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 16),
              TextField(
                controller: abonoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto entregado (\$)', prefixText: '\$ ', border: OutlineInputBorder()),
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
                  OverlayHelper.showError(contextOriginal, message: 'El monto no puede ser mayor a la deuda de ${_currencyFormat.format(totalDeuda)}');
                  return;
                }
                
                if (monto > 0) {
                  Navigator.pop(ctxAbono); // cierra modal del monto
                  
                  // Abre confirmación secundaria que el usuario pidió
                  showDialog(
                    context: contextOriginal,
                    builder: (ctxConfirm) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Confirmar Abono', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      content: Text('¿Deseas confirmar un abono de ${_currencyFormat.format(monto)} del repartidor $repartidorNombre de la cuenta total de ${_currencyFormat.format(totalDeuda)}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctxConfirm),
                          child: const Text('No, corregir', style: TextStyle(color: Colors.redAccent)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                          onPressed: () async {
                            Navigator.pop(ctxConfirm); // cierra confirmacion
                            
                            final safeContext = this.context;
                            if (!safeContext.mounted) return;
                            
                            showDialog(context: safeContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                            
                            try {
                              await _firebaseService.registrarAbonoRepartidor(repartidorNombre, monto, ticketIdsToPay: ticketIds);
                              if (safeContext.mounted) {
                                Navigator.pop(safeContext); // cerrar loading
                                OverlayHelper.showSuccess(safeContext, message: 'Entrega registrada exitosamente');
                              }
                            } catch (e) {
                              if (safeContext.mounted) {
                                Navigator.pop(safeContext); // cerrar loading
                                OverlayHelper.showError(safeContext, message: 'Error: $e');
                              }
                            }
                          },
                          child: const Text('Sí, Confirmar Abono', style: TextStyle(color: Colors.white)),
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

  Widget _buildCorteGeneralTab(List<Ticket> tickets, List<Abono> abonos, List<Gasto> gastos) {
    double totalVendido = 0;
    double totalPorCobrar = 0;

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') {
        totalVendido += t.totalVenta;
        if (!t.pagoRepartidorConfirmado && t.saldoRestante > 0) {
          totalPorCobrar += t.saldoRestante;
        }
      }
    }
    
    double totalGastos = 0;
    for (var g in gastos) {
      totalGastos += g.monto;
    }

    // Prepare combined list of movimientos
    List<Map<String, dynamic>> movimientos = [];
    
    for (var t in tickets) {
      movimientos.add({
        'fecha': t.fecha?.toDate() ?? DateTime.now(),
        'tipo': 'Venta',
        'subtipo': t.tipoEntrega, // Domicilio, Local
        'metodo': t.metodoPago, // Efectivo, Transferencia
        'monto': t.totalVenta,
        'estado': t.estadoEntrega,
        'nombre': t.clienteNombre,
        'obj': t,
      });
    }
    for (var a in abonos) {
      if (a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        movimientos.add({
          'fecha': a.fecha?.toDate() ?? DateTime.now(),
          'tipo': 'Abono',
          'subtipo': '',
          'metodo': '',
          'monto': a.monto,
          'estado': '',
          'nombre': 'Abono a Deuda',
          'obj': a,
        });
      }
    }
    for (var g in gastos) {
      movimientos.add({
        'fecha': g.fecha?.toDate() ?? DateTime.now(),
        'tipo': 'Gasto',
        'subtipo': '',
        'metodo': '',
        'monto': g.monto,
        'estado': '',
        'nombre': g.concepto,
        'obj': g,
      });
    }
    
    // Sort descending by date
    movimientos.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

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
                    const Text('Resumen General', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('Vendí', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalVendido), style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(height: 40, width: 2, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Gasté', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalGastos), style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(height: 40, width: 2, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Me Deben', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(totalPorCobrar), style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoRegistrarGasto(context),
                  icon: const Icon(LucideIcons.arrowDownCircle, color: Colors.white),
                  label: const Text('Registrar Salida de Dinero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    PdfReportService.generateCorteGeneralPdf(context, tickets, abonos, gastos, _filtro);
                  },
                  icon: const Icon(LucideIcons.printer, color: Colors.white),
                  label: const Text('Generar PDF Corte General', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    PdfReportService.generateProductosVendidosPdf(context, tickets, _filtro);
                  },
                  icon: const Icon(LucideIcons.fileText, color: Colors.white),
                  label: const Text('Generar PDF Productos Vendidos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                    try {
                      final fireService = Provider.of<FirebaseService>(context, listen: false);
                      final ticketsDeuda = await fireService.getAllTicketsConDeudaFuture();
                      final abonosFut = await fireService.getAllAbonosFuture();
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) {
                        PdfReportService.generateReporteDeudoresPdf(context, ticketsDeuda, abonosFut);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  icon: const Icon(LucideIcons.users, color: Colors.white),
                  label: const Text('Generar PDF Reporte Deudores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
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
        if (movimientos.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No hay movimientos en este rango de fechas.', style: TextStyle(color: Colors.grey, fontSize: 16))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final mov = movimientos[index];
                  final String tipo = mov['tipo'];
                  final String subtipo = mov['subtipo'];
                  final String metodo = mov['metodo'];
                  final double monto = mov['monto'];
                  final String estado = mov['estado'];
                  final String nombre = mov['nombre'];
                  
                  IconData iconData = LucideIcons.store;
                  Color iconColor = Colors.blue;
                  Color bgColor = Colors.blue.shade100;
                  
                  if (tipo == 'Venta') {
                    if (subtipo == 'Domicilio') {
                      iconData = LucideIcons.bike;
                      iconColor = Colors.orange;
                      bgColor = Colors.orange.shade100;
                    } else {
                      iconData = LucideIcons.store;
                      iconColor = Colors.blue;
                      bgColor = Colors.blue.shade100;
                    }
                  } else if (tipo == 'Abono') {
                    iconData = LucideIcons.banknote;
                    iconColor = Colors.green;
                    bgColor = Colors.green.shade100;
                  } else if (tipo == 'Gasto') {
                    iconData = LucideIcons.minusCircle;
                    iconColor = Colors.red;
                    bgColor = Colors.red.shade100;
                  }

                  String subtitle = tipo;
                  if (tipo == 'Venta') {
                    subtitle = 'Venta en $subtipo • $metodo';
                  }

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
                        backgroundColor: bgColor,
                        child: Icon(iconData, color: iconColor, size: 24),
                      ),
                      title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(subtitle, style: const TextStyle(fontSize: 14)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            (tipo == 'Gasto' ? '-' : '') + _currencyFormat.format(monto), 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: tipo == 'Gasto' ? Colors.red : (tipo == 'Abono' ? Colors.green : AppTheme.textDark)
                            )
                          ),
                          if (estado == 'Cancelado')
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

  Widget _buildCorteRepartidorTab(List<Ticket> tickets, List<Abono> abonos) {
    Map<String, List<Ticket>> ticketsPorRepartidor = {};
    
    // Agrupar repartidores de abonos también (por si un repartidor no tuvo ventas hoy pero sí cobró un abono)
    Set<String> repartidoresNombres = {};

    for (var t in tickets) {
      if (t.tipoEntrega == 'Domicilio' && t.repartidorNombre != null && t.repartidorNombre!.isNotEmpty) {
        repartidoresNombres.add(t.repartidorNombre!);
      }
    }
    for (var a in abonos) {
       if (a.repartidorId != null && a.repartidorId!.isNotEmpty) {
          repartidoresNombres.add(a.repartidorId!);
       }
    }

    for (var r in repartidoresNombres) {
       if (r.length == 20 && !r.contains(' ')) continue; // Omitir IDs fantasma
       ticketsPorRepartidor[r] = tickets.where((t) => t.tipoEntrega == 'Domicilio' && t.repartidorNombre == r).toList();
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
                  totalEntregado += t.totalAbonado;
                  totalPendiente += t.saldoRestante;
                  
                  if (t.pagoRepartidorConfirmado) {
                    countCompletados++;
                  } else {
                    countPendientes++;
                  }
                  
                  if (t.metodoPago == 'Transferencia') {
                    totalTransferencia += t.totalAbonado;
                  } else {
                    totalEfectivo += t.totalAbonado;
                  }
                }
              }

              double abonosCobrados = 0;
              for (var a in abonos) {
                if (a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
                  bool isTicketInList = tickets.any((t) => t.id == a.ticketId);
                  if (!isTicketInList && (a.repartidorId == repartidor || a.createBy == repartidor)) {
                    abonosCobrados += a.monto;
                  }
                }
              }

              // No sumamos a totalEntregado ni restamos de totalPendiente 
              // porque t.totalAbonado y t.saldoRestante ya lo manejan.

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
                              PdfReportService.generateCorteRepartidorPdf(context, repartidor, ticketsRep, abonos, _filtro);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 16, thickness: 1.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Valor Mercancía', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalAsignado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Debe entregar', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalPendiente), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Entregó a caja', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalEntregado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                            ],
                          ),
                        ],
                      ),
                      if (abonosCobrados > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Abonos:', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(_currencyFormat.format(abonosCobrados), style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                      if (totalTransferencia > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('(*Incluye ${_currencyFormat.format(totalTransferencia)} por Transferencia)', style: const TextStyle(color: Colors.blue, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ]
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
