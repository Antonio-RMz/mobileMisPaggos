import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/pdf_report_service.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../models/gasto_model.dart';
import '../models/personal_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
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
  final Map<String, String> _clienteNamesCache = {};

  void _loadMissingClientNames(List<Abono> abonos) {
    final missingIds = abonos
        .map((a) => a.clienteId)
        .where((id) => id.isNotEmpty && !_clienteNamesCache.containsKey(id))
        .toSet();

    if (missingIds.isEmpty) return;

    // Add them to cache with a fallback value (to avoid duplicate queries)
    for (var id in missingIds) {
      _clienteNamesCache[id] = id; 
    }

    // Load asynchronously
    Future.microtask(() async {
      for (var id in missingIds) {
        try {
          final doc = await FirebaseFirestore.instance.collection('clientes').doc(id).get();
          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              final String name = data['nombre'] ?? '';
              final String app = data['appaterno'] ?? '';
              final String apm = data['apmaterno'] ?? '';
              final fullName = '$name $app $apm'.trim();
              if (fullName.isNotEmpty) {
                if (mounted) {
                  setState(() {
                    _clienteNamesCache[id] = fullName;
                  });
                }
              }
            }
          }
        } catch (e) {
          // Ignore
        }
      }
    });
  }

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
          data: Theme.of(context),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
          actions: const [
            NotificationBell(),
          ],
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
                    _loadMissingClientNames(abonos);
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
                              _buildCorteRepartidorTab(tickets, abonos, gastos),
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

  void _mostrarDialogoRegistrarGasto(BuildContext contextOriginal, double dineroEnCaja) {
    final TextEditingController conceptoCtrl = TextEditingController();
    final TextEditingController montoCtrl = TextEditingController();
    final TextEditingController pinCtrl = TextEditingController();
    
    showDialog(
      context: contextOriginal,
      builder: (ctxGasto) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registrar Salida de Dinero (Gasto)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Dinero disponible en caja: ${_currencyFormat.format(dineroEnCaja)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 12),
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

                if (monto > dineroEnCaja) {
                  ScaffoldMessenger.of(contextOriginal).showSnackBar(
                    SnackBar(content: Text('No hay dinero suficiente en caja. Disponible: ${_currencyFormat.format(dineroEnCaja)}')),
                  );
                  return;
                }

                Navigator.pop(ctxGasto);

                // Advertencia secundaria
                showDialog(
                  context: contextOriginal,
                  builder: (ctxConfirm) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Confirmar Salida de Caja', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    content: Text('¿Estás seguro de registrar un gasto de ${_currencyFormat.format(monto)} para "$concepto"?\n\nEste dinero se restará de la caja física.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctxConfirm), child: const Text('No, cancelar', style: TextStyle(color: Colors.grey))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          Navigator.pop(ctxConfirm);
                          
                          final safeContext = contextOriginal;
                          showDialog(context: safeContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                          
                          try {
                            final fireService = Provider.of<FirebaseService>(safeContext, listen: false);
                            await fireService.registrarGasto(concepto, monto);

                            if (safeContext.mounted) {
                              Navigator.of(safeContext, rootNavigator: true).pop(); // cerrar loading
                              ScaffoldMessenger.of(safeContext).showSnackBar(const SnackBar(content: Text('Gasto registrado correctamente')));
                            }
                          } catch (e) {
                            if (safeContext.mounted) {
                              Navigator.of(safeContext, rootNavigator: true).pop(); // cerrar loading
                              ScaffoldMessenger.of(safeContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        child: const Text('Sí, Registrar Gasto', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Registrar Gasto', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoEntregarCambio(BuildContext contextOriginal, double dineroEnCaja) {
    final TextEditingController montoCtrl = TextEditingController();
    final TextEditingController pinCtrl = TextEditingController();
    String? selectedRepartidorId;
    List<Personal> repartidoresList = [];
    bool provieneDeCaja = true;

    showDialog(
      context: contextOriginal,
      builder: (ctxCambio) {
        final fireService = Provider.of<FirebaseService>(contextOriginal, listen: false);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Entregar Cambio a Repartidor', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: StreamBuilder<List<Personal>>(
                  stream: fireService.getPersonalStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final repartidores = snapshot.data!
                        .where((p) => p.rol == 'Repartidor' && p.activo)
                        .toList();

                    repartidoresList = repartidores;

                    if (repartidores.isEmpty) {
                      return const Text('No hay repartidores activos registrados.');
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (provieneDeCaja) ...[
                          Text(
                            'Dinero disponible en caja: ${_currencyFormat.format(dineroEnCaja)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Repartidor',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedRepartidorId,
                          items: repartidores.map((r) {
                            return DropdownMenuItem<String>(
                              value: r.id,
                              child: Text(r.nombre),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setStateDialog(() {
                              selectedRepartidorId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: montoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Monto de cambio entregado (\$)',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: pinCtrl,
                          decoration: const InputDecoration(
                            labelText: 'PIN de Confirmación',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Tomar de caja', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          value: provieneDeCaja,
                          activeColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setStateDialog(() {
                              provieneDeCaja = val;
                            });
                          },
                        ),
                      ],
                    );
                  }
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctxCambio),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    final pin = pinCtrl.text.trim();
                    final montoStr = montoCtrl.text.trim();

                    if (selectedRepartidorId == null || montoStr.isEmpty || pin.isEmpty) {
                      ScaffoldMessenger.of(contextOriginal).showSnackBar(
                        const SnackBar(content: Text('Por favor completa todos los campos')),
                      );
                      return;
                    }

                    if (pin != '1234') {
                      ScaffoldMessenger.of(contextOriginal).showSnackBar(
                        const SnackBar(content: Text('PIN Incorrecto')),
                      );
                      return;
                    }

                    final monto = double.tryParse(montoStr);
                    if (monto == null || monto <= 0) {
                      ScaffoldMessenger.of(contextOriginal).showSnackBar(
                        const SnackBar(content: Text('Monto inválido')),
                      );
                      return;
                    }

                    if (provieneDeCaja && monto > dineroEnCaja) {
                      ScaffoldMessenger.of(contextOriginal).showSnackBar(
                        SnackBar(content: Text('No hay dinero suficiente en caja para este cambio. Disponible: ${_currencyFormat.format(dineroEnCaja)}')),
                      );
                      return;
                    }

                    final matchedRep = repartidoresList.where((r) => r.id == selectedRepartidorId);
                    if (matchedRep.isEmpty) {
                      ScaffoldMessenger.of(contextOriginal).showSnackBar(
                        const SnackBar(content: Text('Repartidor no encontrado')),
                      );
                      return;
                    }
                    final selectedRepartidor = matchedRep.first;

                    Navigator.pop(ctxCambio); // cerrar diálogo

                    // Confirmacion secundaria
                    showDialog(
                      context: contextOriginal,
                      builder: (ctxConfirm) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Confirmar Entrega de Cambio', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        content: Text('¿Estás seguro de entregar ${_currencyFormat.format(monto)} al repartidor ${selectedRepartidor.nombre}?\n\n${provieneDeCaja ? "Este monto se tomará y restará de la caja física." : "Este monto proviene de fondos externos (No afecta la caja física)."}'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctxConfirm), child: const Text('No, cancelar', style: TextStyle(color: Colors.grey))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            onPressed: () async {
                              Navigator.pop(ctxConfirm); // cerrar confirmación
                              
                              final safeContext = contextOriginal;
                              showDialog(
                                context: safeContext,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );

                              try {
                                await fireService.registrarGasto(
                                  'Fondo de Cambio - ${selectedRepartidor.nombre}',
                                  monto,
                                  repartidorId: selectedRepartidor.id,
                                  repartidorNombre: selectedRepartidor.nombre,
                                  tipoGasto: 'Cambio',
                                  esDeCaja: provieneDeCaja,
                                );

                                if (safeContext.mounted) {
                                  Navigator.of(safeContext, rootNavigator: true).pop(); // cerrar loading
                                  ScaffoldMessenger.of(safeContext).showSnackBar(
                                    const SnackBar(content: Text('Fondo de cambio registrado correctamente')),
                                  );
                                }
                              } catch (e) {
                                if (safeContext.mounted) {
                                  Navigator.of(safeContext, rootNavigator: true).pop(); // cerrar loading
                                  ScaffoldMessenger.of(safeContext).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Sí, Entregar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Entregar Cambio', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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
                    builder: (ctxConfirm) {
                      bool isSubmitting = false;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Confirmar Abono', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                            content: Text('¿Deseas confirmar un abono de ${_currencyFormat.format(monto)} del repartidor $repartidorNombre de la cuenta total de ${_currencyFormat.format(totalDeuda)}?'),
                            actions: [
                              TextButton(
                                onPressed: isSubmitting ? null : () => Navigator.pop(ctxConfirm),
                                child: const Text('No, corregir', style: TextStyle(color: Colors.redAccent)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                                onPressed: isSubmitting ? null : () async {
                                  setState(() {
                                    isSubmitting = true;
                                  });
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
                          );
                        },
                      );
                    },
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
    abonos = abonos.where((a) => a.ticketId != 'ENTREGA_GENERAL').toList();
    final Map<String, String> localClienteNames = {};
    for (var t in tickets) {
      if (t.clienteId.isNotEmpty && t.clienteNombre.isNotEmpty) {
        localClienteNames[t.clienteId] = t.clienteNombre;
      }
    }

    double totalVendido = 0;
    double totalClientesDeben = 0;
    double totalRepartidoresDeben = 0;
    double totalGastos = 0;
    double totalRecibido = 0;

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado') {
        totalVendido += t.totalVenta;
        
        if (t.estado == 'Con Deuda' || t.formaVenta == 'Crédito') {
          totalClientesDeben += t.saldoRestante;
          if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
            totalRepartidoresDeben += t.totalAbonado;
          }
        } else { // Contado y Pagado/Pendiente
          if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
            totalRepartidoresDeben += t.saldoRestante;
          }
        }
      }
    }
    
    for (var g in gastos) {
      if (g.esDeCaja) {
        totalGastos += g.monto;
      }
    }

    double totalRecibidoClientes = 0;
    double totalRecibidoRepartidores = 0;
    for (var a in abonos) {
      final isRepartidor = a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL';
      if (isRepartidor) {
        totalRecibidoRepartidores += a.monto;
      } else {
        bool wasThroughDriver = false;
        bool isTransfer = false;
        if (a.ticketId != null && a.ticketId!.isNotEmpty) {
          for (var t in tickets) {
            if (t.id == a.ticketId) {
              if (t.tipoEntrega == 'Domicilio') {
                wasThroughDriver = true;
              }
              if (t.metodoPago == 'Transferencia') {
                isTransfer = true;
              }
              break;
            }
          }
        }
        if (!wasThroughDriver && !isTransfer) {
          totalRecibidoClientes += a.monto;
        }
      }
    }
    totalRecibido = totalRecibidoClientes + totalRecibidoRepartidores;
    double totalPendiente = totalClientesDeben + totalRepartidoresDeben;
    final double dineroEnCaja = totalRecibido - totalGastos;

    // Prepare combined list of movimientos
    List<Map<String, dynamic>> movimientos = [];
    
    for (var t in tickets) {
      if (t.estadoEntrega == 'Programado') continue;
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
      final isRepartidor = a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL';
      
      // Skip client abonos collected in cash by a driver, because they are already accounted for in the ENTREGA_REPARTIDOR bulk abono
      if (a.repartidorId != null && a.repartidorId!.isNotEmpty && !isRepartidor) {
        String metodo = 'Efectivo';
        if (a.ticketId != null && a.ticketId!.isNotEmpty) {
          for (var t in tickets) {
            if (t.id == a.ticketId) {
              metodo = t.metodoPago;
              break;
            }
          }
        }
        if (metodo == 'Efectivo') {
          continue;
        }
      }

      // Skip the abono document if it corresponds to a Contado counter sale (since it's already shown in the Venta row)
      bool isContadoAbono = false;
      if (a.ticketId != null && a.ticketId!.isNotEmpty) {
        for (var t in tickets) {
          if (t.id == a.ticketId && t.formaVenta == 'Contado' && (t.tipoEntrega != 'Domicilio' || t.metodoPago != 'Efectivo')) {
            isContadoAbono = true;
            break;
          }
        }
      }
      
      if (isContadoAbono) continue;

      final String abonoName;
      if (isRepartidor) {
        abonoName = a.ticketId == 'ENTREGA_REPARTIDOR' 
            ? 'Entrega de Repartidor - ${a.repartidorId ?? a.createBy}' 
            : 'Entrega General - ${a.repartidorId ?? a.createBy}';
      } else {
        final String resolvedName = localClienteNames[a.clienteId] ?? _clienteNamesCache[a.clienteId] ?? a.clienteId;
        abonoName = resolvedName.isNotEmpty ? 'Abono a Deuda - $resolvedName' : 'Abono a Deuda';
      }
      
      movimientos.add({
        'fecha': a.fecha?.toDate() ?? DateTime.now(),
        'tipo': 'Abono',
        'subtipo': isRepartidor ? 'Repartidor' : 'Cliente',
        'metodo': 'Efectivo', // Default to Efectivo for abonos
        'monto': a.monto,
        'estado': 'Entregado',
        'nombre': abonoName,
        'obj': a,
      });
    }
    for (var g in gastos) {
      if (g.esDeCaja) {
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
      } else {
        movimientos.add({
          'fecha': g.fecha?.toDate() ?? DateTime.now(),
          'tipo': 'Otras Entradas',
          'subtipo': 'Cambio',
          'metodo': 'Externo',
          'monto': g.monto,
          'estado': '',
          'nombre': 'Fondo de Cambio (Externo) - ${g.repartidorNombre ?? ''}',
          'obj': g,
        });
      }
    }
    
    // Sort descending by date
    movimientos.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

    final bool isWide = MediaQuery.of(context).size.width >= AppTheme.tabletBreakpoint;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Seccion de Acciones principales
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Centro de Acciones',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 12),
                        if (isWide)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () => _mostrarDialogoRegistrarGasto(context, dineroEnCaja),
                                      icon: LucideIcons.arrowDownCircle,
                                      label: 'Registrar Salida',
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () => _mostrarDialogoEntregarCambio(context, dineroEnCaja),
                                      icon: LucideIcons.coins,
                                      label: 'Entregar Cambio',
                                      color: Colors.purple.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () {
                                        PdfReportService.generateCorteGeneralPdf(context, tickets, abonos, gastos, _filtro);
                                      },
                                      icon: LucideIcons.printer,
                                      label: 'Corte General (PDF)',
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () {
                                        PdfReportService.generateProductosVendidosPdf(context, tickets, _filtro);
                                      },
                                      icon: LucideIcons.package,
                                      label: 'Productos Vendidos',
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
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
                                      icon: LucideIcons.users,
                                      label: 'Reporte Deudores',
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () {
                                        PdfReportService.generateReportePedidosProgramadosPdf(
                                          context,
                                          _startDate,
                                          _endDate,
                                          _filtro,
                                        );
                                      },
                                      icon: LucideIcons.calendarClock,
                                      label: 'Pedidos Programados',
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildActionButton(
                                onPressed: () => _mostrarDialogoRegistrarGasto(context, dineroEnCaja),
                                icon: LucideIcons.arrowDownCircle,
                                label: 'Registrar Salida de Dinero (Gasto)',
                                color: Colors.red.shade600,
                              ),
                              const SizedBox(height: 8),
                              _buildActionButton(
                                onPressed: () => _mostrarDialogoEntregarCambio(context, dineroEnCaja),
                                icon: LucideIcons.coins,
                                label: 'Entregar Cambio a Repartidor',
                                color: Colors.purple.shade600,
                              ),
                              const SizedBox(height: 8),
                              _buildActionButton(
                                onPressed: () {
                                  PdfReportService.generateCorteGeneralPdf(context, tickets, abonos, gastos, _filtro);
                                },
                                icon: LucideIcons.printer,
                                label: 'Generar PDF Corte General',
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () {
                                        PdfReportService.generateProductosVendidosPdf(context, tickets, _filtro);
                                      },
                                      icon: LucideIcons.package,
                                      label: 'Prod. Vendidos',
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildActionButton(
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
                                      icon: LucideIcons.users,
                                      label: 'Deudores',
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildActionButton(
                                      onPressed: () {
                                        PdfReportService.generateReportePedidosProgramadosPdf(
                                          context,
                                          _startDate,
                                          _endDate,
                                          _filtro,
                                        );
                                      },
                                      icon: LucideIcons.calendarClock,
                                      label: 'Prog. PDF',
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Resumen de Caja (3 indicadores de operacion)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumen Operativo de Caja', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Dinero en Caja',
                                  amount: dineroEnCaja,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Container(height: 40, width: 1, color: Colors.grey.shade200),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Con Repartidores',
                                  amount: totalRepartidoresDeben,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Container(height: 40, width: 1, color: Colors.grey.shade200),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Adeudo Clientes',
                                  amount: totalClientesDeben,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Container(height: 40, width: 1, color: Colors.grey.shade200),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'Gastos Retirados',
                                  amount: totalGastos,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Text('Últimos Movimientos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
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
                      } else if (tipo == 'Otras Entradas') {
                        iconData = LucideIcons.plusCircle;
                        iconColor = Colors.purple;
                        bgColor = Colors.purple.shade100;
                      }

                      String subtitle = tipo;
                      if (tipo == 'Venta') {
                        final t = mov['obj'] as Ticket;
                        final abonoInicialText = (t.formaVenta == 'Contado' && (t.tipoEntrega != 'Domicilio' || t.metodoPago != 'Efectivo')) 
                            ? ' • Pagado: ${_currencyFormat.format(t.totalVenta)}' 
                            : '';
                        subtitle = 'Venta (${t.formaVenta}) en $subtipo • $metodo$abonoInicialText';
                      } else if (tipo == 'Otras Entradas') {
                        subtitle = 'Otras Entradas (Cambio)';
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
                                (tipo == 'Gasto' ? '-' : (tipo == 'Otras Entradas' ? '+' : '')) + _currencyFormat.format(monto), 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16,
                                  color: tipo == 'Gasto' ? Colors.red : (tipo == 'Abono' || tipo == 'Otras Entradas' ? Colors.green : AppTheme.textDark)
                                )
                              ),
                              if (estado == 'Cancelado')
                                const Text('Cancelado', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: movimientos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorteRepartidorTab(List<Ticket> tickets, List<Abono> abonos, List<Gasto> gastos) {
    abonos = abonos.where((a) => a.ticketId != 'ENTREGA_GENERAL').toList();
    Map<String, List<Ticket>> ticketsPorRepartidor = {};
    
    // Agrupar repartidores de abonos también (por si un repartidor no tuvo ventas hoy pero sí cobró un abono)
    Set<String> repartidoresNombres = {};

    for (var t in tickets) {
      if (t.estadoEntrega == 'Programado') continue;
      if (t.tipoEntrega == 'Domicilio' && t.repartidorNombre != null && t.repartidorNombre!.isNotEmpty) {
        repartidoresNombres.add(t.repartidorNombre!);
      }
    }
    for (var a in abonos) {
       if (a.repartidorId != null && a.repartidorId!.isNotEmpty) {
          repartidoresNombres.add(a.repartidorId!);
       }
    }
    for (var g in gastos) {
      if (g.tipoGasto == 'Cambio' && g.repartidorNombre != null && g.repartidorNombre!.isNotEmpty) {
        repartidoresNombres.add(g.repartidorNombre!);
      }
    }

    for (var r in repartidoresNombres) {
       if (r.length == 20 && !r.contains(' ')) continue; // Omitir IDs fantasma
       ticketsPorRepartidor[r] = tickets.where((t) => t.estadoEntrega != 'Programado' && t.tipoEntrega == 'Domicilio' && t.repartidorNombre == r).toList();
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
              int countCancelados = 0;

              for (var t in ticketsRep) {
                if (t.estadoEntrega == 'Cancelado') {
                  countCancelados++;
                } else {
                  totalAsignado += t.totalVenta;
                }
              }

              // Calcular fondo de cambio dado al repartidor hoy
              double totalCambioDado = 0;
              for (var g in gastos) {
                if (g.tipoGasto == 'Cambio' && g.repartidorNombre?.trim().toLowerCase() == repartidor.trim().toLowerCase()) {
                  totalCambioDado += g.monto;
                }
              }

              // Calcular las ventas en efectivo cobradas por el repartidor hoy
              double totalVentasEfectivo = 0;
              for (var t in ticketsRep) {
                if (t.estadoEntrega != 'Cancelado' && t.metodoPago == 'Efectivo') {
                  if (t.formaVenta == 'Contado') {
                    totalVentasEfectivo += t.totalVenta;
                  } else {
                    totalVentasEfectivo += t.totalAbonado;
                  }
                }
              }

              double abonosCobrados = 0;
              for (var a in abonos) {
                if (a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
                  bool isTicketInList = tickets.any((t) => t.id == a.ticketId);
                  if (!isTicketInList && (a.repartidorId == repartidor || a.createBy == repartidor)) {
                    abonosCobrados += a.monto;
                    totalVentasEfectivo += a.monto;
                  }
                }
              }

              // Calcular entregas reales de efectivo del repartidor
              double totalEntregado = 0;
              for (var a in abonos) {
                if ((a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL') && a.repartidorId == repartidor) {
                  totalEntregado += a.monto;
                }
              }

              double totalAEntregar = totalVentasEfectivo + totalCambioDado;
              double totalPendiente = totalAEntregar - totalEntregado;
              totalPendiente = totalPendiente < 0 ? 0.0 : totalPendiente;

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
                              PdfReportService.generateCorteRepartidorPdf(context, repartidor, ticketsRep, tickets, abonos, gastos, _filtro);
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
                              const Text('Mercancía', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalAsignado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Fondo Cambio', style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalCambioDado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Total a Entregar', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalAEntregar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Entregó a caja', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(_currencyFormat.format(totalEntregado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 8, thickness: 0.5),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo Pendiente:', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            _currencyFormat.format(totalPendiente),
                            style: TextStyle(
                              color: totalPendiente > 0 ? Colors.red.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (abonosCobrados > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('De los cuales fueron Abonos:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                            Text(_currencyFormat.format(abonosCobrados), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        )
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

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
