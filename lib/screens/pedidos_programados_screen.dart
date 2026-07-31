import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/ticket_model.dart';
import '../models/personal_model.dart';
import '../services/firebase_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import '../utils/overlay_helper.dart';
import 'payment_success_screen.dart';

class PedidosProgramadosScreen extends StatefulWidget {
  const PedidosProgramadosScreen({super.key});

  @override
  State<PedidosProgramadosScreen> createState() => _PedidosProgramadosScreenState();
}

class _PedidosProgramadosScreenState extends State<PedidosProgramadosScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final regFormat = DateFormat('dd MMM, HH:mm');
  String _sortingOrder = 'entrega'; // 'entrega' o 'registro'

  String _formatearFechaProgramada(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('hh:mm a').format(dt);
    if (checkDate == today) {
      return 'Hoy a las $timeStr';
    } else if (checkDate == tomorrow) {
      return 'Mañana a las $timeStr';
    } else {
      return '${DateFormat('dd MMM').format(dt)} a las $timeStr';
    }
  }

  bool _isChicharron(TicketItem item) {
    if (item.esChicharron) return true;
    final clean = item.nombre.toLowerCase();
    return clean.contains('chicharron') || clean.contains('chicharrón');
  }

  String _formatearFechaProduccion(DateTime dt) {
    final months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final weekdays = [
      '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    return '${weekdays[dt.weekday]}, ${dt.day} de ${months[dt.month]}';
  }

  String _calcularTotalProduccion(List<Ticket> tickets) {
    double totalKg = 0;
    double totalPzas = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Programado') continue;
      for (var item in t.productos) {
        if (_isChicharron(item)) {
          if (item.unidadVenta.toLowerCase().contains('kg') || item.unidadVenta.toLowerCase().contains('kilo')) {
            totalKg += item.cantidad;
          } else {
            totalPzas += item.cantidad;
          }
        }
      }
    }
    
    final List<String> parts = [];
    if (totalKg > 0) {
      parts.add('${totalKg % 1 == 0 ? totalKg.toInt() : totalKg.toStringAsFixed(2)} kg');
    }
    if (totalPzas > 0) {
      parts.add('${totalPzas % 1 == 0 ? totalPzas.toInt() : totalPzas.toStringAsFixed(1)} pzas');
    }
    return parts.isEmpty ? '0' : parts.join(' + ');
  }

  Widget _buildSortingFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.arrowUpDown, size: 14, color: AppTheme.textLight),
              SizedBox(width: 6),
              Text(
                'Ordenar por:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Hora de Entrega', style: TextStyle(fontSize: 12)),
                selected: _sortingOrder == 'entrega',
                selectedColor: Colors.blue.shade50,
                checkmarkColor: Colors.blue.shade800,
                labelStyle: TextStyle(
                  color: _sortingOrder == 'entrega' ? Colors.blue.shade800 : AppTheme.textLight,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(
                  color: _sortingOrder == 'entrega' ? Colors.blue.shade400 : Colors.grey.shade300,
                  width: _sortingOrder == 'entrega' ? 1.5 : 1.0,
                ),
                onSelected: (val) {
                  if (val) setState(() => _sortingOrder = 'entrega');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Hora de Registro', style: TextStyle(fontSize: 12)),
                selected: _sortingOrder == 'registro',
                selectedColor: Colors.blue.shade50,
                checkmarkColor: Colors.blue.shade800,
                labelStyle: TextStyle(
                  color: _sortingOrder == 'registro' ? Colors.blue.shade800 : AppTheme.textLight,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(
                  color: _sortingOrder == 'registro' ? Colors.blue.shade400 : Colors.grey.shade300,
                  width: _sortingOrder == 'registro' ? 1.5 : 1.0,
                ),
                onSelected: (val) {
                  if (val) setState(() => _sortingOrder = 'registro');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.calendarClock, size: 48, color: Colors.orange),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(FirebaseService firebaseService) {
    return StreamBuilder<List<Ticket>>(
      stream: firebaseService.getScheduledTicketsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final allTickets = snapshot.data ?? [];
        final tickets = allTickets.where((t) => !t.productos.any((item) => _isChicharron(item))).toList();
        
        if (tickets.isEmpty) {
          return _buildEmptyState('Sin Pedidos Generales', 'Los pedidos programados generales aparecerán aquí.');
        }

        // Apply local sorting
        if (_sortingOrder == 'entrega') {
          tickets.sort((a, b) {
            final tA = a.fechaEntregaProgramada ?? a.fecha ?? Timestamp.now();
            final tB = b.fechaEntregaProgramada ?? b.fecha ?? Timestamp.now();
            return tA.compareTo(tB);
          });
        } else {
          tickets.sort((a, b) {
            final tA = a.createAt ?? a.fecha ?? Timestamp.now();
            final tB = b.createAt ?? b.fecha ?? Timestamp.now();
            return tA.compareTo(tB);
          });
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildSortingFilter(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      return _buildPedidoCard(context, ticket, index + 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChicharronTab(FirebaseService firebaseService) {
    return StreamBuilder<List<Ticket>>(
      stream: firebaseService.getScheduledTicketsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final allTickets = snapshot.data ?? [];
        final chicharronTickets = allTickets.where((t) => t.productos.any((item) => _isChicharron(item))).toList();

        if (chicharronTickets.isEmpty) {
          return _buildEmptyState('Sin Pedidos de Chicharrón', 'Los pedidos programados de chicharrón aparecerán aquí.');
        }

        // Group by scheduled date (yyyy-MM-dd)
        final Map<DateTime, List<Ticket>> grouped = {};
        for (var t in chicharronTickets) {
          if (t.fechaEntregaProgramada != null) {
            final date = t.fechaEntregaProgramada!.toDate();
            final midnight = DateTime(date.year, date.month, date.day);
            grouped.putIfAbsent(midnight, () => []).add(t);
          }
        }

        // Sort dates ascending
        final sortedDates = grouped.keys.toList()..sort();

        // Sort tickets in each date group according to user sorting preference
        for (var date in sortedDates) {
          grouped[date]!.sort((a, b) {
            if (_sortingOrder == 'entrega') {
              final tA = a.fechaEntregaProgramada ?? a.fecha ?? Timestamp.now();
              final tB = b.fechaEntregaProgramada ?? b.fecha ?? Timestamp.now();
              return tA.compareTo(tB);
            } else {
              final tA = a.createAt ?? a.fecha ?? Timestamp.now();
              final tB = b.createAt ?? b.fecha ?? Timestamp.now();
              return tA.compareTo(tB);
            }
          });
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildSortingFilter(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final list = grouped[date]!;
                      
                      final String dateStr = _formatearFechaProduccion(date);
                      final String totalProd = _calcularTotalProduccion(list);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Header
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 4.0),
                            child: Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          
                          // Tickets list of cards
                          ...list.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final ticket = entry.value;
                            return _buildPedidoCard(context, ticket, idx + 1, isChicharronOnly: true);
                          }).toList(),
                          
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Pedidos Programados'),
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
              Tab(text: 'General', icon: Icon(LucideIcons.calendar)),
              Tab(text: 'Chicharrón', icon: Icon(Icons.restaurant)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralTab(firebaseService),
            _buildChicharronTab(firebaseService),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoCard(BuildContext context, Ticket ticket, int position, {bool isChicharronOnly = false}) {
    final bool pagado = ticket.estado == 'Pagado';
    final DateTime scheduledDate = ticket.fechaEntregaProgramada?.toDate() ?? DateTime.now();
    final String scheduledStr = _formatearFechaProgramada(scheduledDate);

    final DateTime now = DateTime.now();
    final bool vencido = scheduledDate.isBefore(now);
    final bool proximo = scheduledDate.difference(now).inMinutes <= 30 && !vencido;
    final bool isCompleted = ticket.estadoEntrega != 'Programado';

    Color borderColor;
    double borderWidth;
    Color bannerBgColor;
    Color bannerTextColor;
    IconData bannerIcon;
    String bannerText;

    if (isCompleted) {
      borderColor = Colors.grey.shade300;
      borderWidth = 1.0;
      if (ticket.estadoEntrega == 'Cancelado') {
        bannerBgColor = Colors.red.shade100;
        bannerTextColor = Colors.red.shade900;
        bannerIcon = LucideIcons.xCircle;
        bannerText = 'CANCELADO';
      } else {
        bannerBgColor = Colors.green.shade100;
        bannerTextColor = Colors.green.shade900;
        bannerIcon = LucideIcons.checkCircle2;
        bannerText = 'COMPLETADO';
      }
    } else if (vencido) {
      borderColor = Colors.red.shade700;
      borderWidth = 2.5;
      bannerBgColor = Colors.red.shade100;
      bannerTextColor = Colors.red.shade900;
      bannerIcon = LucideIcons.alertCircle;
      bannerText = 'ENTREGA VENCIDA: $scheduledStr';
    } else if (proximo) {
      borderColor = Colors.redAccent.withOpacity(0.5);
      borderWidth = 2.0;
      bannerBgColor = Colors.red.shade50;
      bannerTextColor = Colors.red.shade900;
      bannerIcon = LucideIcons.alertTriangle;
      bannerText = 'ENTREGA PRÓXIMA: $scheduledStr';
    } else {
      borderColor = Colors.amber.shade200;
      borderWidth = 1.5;
      bannerBgColor = Colors.amber.shade50;
      bannerTextColor = Colors.orange.shade900;
      bannerIcon = LucideIcons.clock;
      bannerText = 'Entrega: $scheduledStr';
    }

    final displayItems = isChicharronOnly 
        ? ticket.productos.where(_isChicharron).toList()
        : ticket.productos;

    return Card(
      elevation: 0,
      color: isCompleted ? Colors.grey.shade50 : Colors.white,
      margin: EdgeInsets.only(bottom: isCompleted ? 8 : 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Alerta / Programación
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: isCompleted ? 6 : 10),
            decoration: BoxDecoration(
              color: bannerBgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: isCompleted ? 18 : 22,
                  height: isCompleted ? 18 : 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bannerTextColor.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$position',
                    style: TextStyle(
                      color: bannerTextColor,
                      fontWeight: FontWeight.w900,
                      fontSize: isCompleted ? 10 : 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  bannerIcon,
                  color: bannerTextColor,
                  size: isCompleted ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerText,
                    style: TextStyle(
                      color: bannerTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: isCompleted ? 11 : 13,
                    ),
                  ),
                ),
                if (ticket.createAt != null && !isCompleted)
                  Text(
                    'Reg: ${regFormat.format(ticket.createAt!.toDate())}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isCompleted ? 10 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del cliente y Folio
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '#${ticket.folio}  ${ticket.clienteNombre}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: isCompleted ? 14 : 16, 
                          color: isCompleted ? Colors.grey.shade600 : AppTheme.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? Colors.grey.shade200 
                            : (pagado ? Colors.green.shade50 : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted 
                            ? (ticket.estadoEntrega == 'Cancelado' ? 'Cancelado' : 'Entregado')
                            : (pagado ? 'Pagado' : 'Por Cobrar: ${currencyFormat.format(ticket.saldoRestante)}'),
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.grey.shade700
                              : (pagado ? Colors.green.shade800 : Colors.red.shade800),
                          fontWeight: FontWeight.bold,
                          fontSize: isCompleted ? 10 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompleted ? 6 : 12),
                const Divider(),
                SizedBox(height: isCompleted ? 4 : 8),

                // Lista de productos
                ...displayItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(2)} ${item.unidadVenta}  x ',
                          style: TextStyle(
                            color: Colors.grey.shade600, 
                            fontSize: isCompleted ? 11 : 13, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nombre,
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey.shade700 : AppTheme.textDark, 
                                  fontSize: isCompleted ? 11 : 13, 
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.observaciones.isNotEmpty && !isCompleted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    'Nota: "${item.observaciones}"',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 11,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.subtotal),
                          style: TextStyle(
                            color: isCompleted ? Colors.grey.shade700 : AppTheme.textDark, 
                            fontSize: isCompleted ? 11 : 13, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                SizedBox(height: isCompleted ? 6 : 12),
                const Divider(),
                SizedBox(height: isCompleted ? 6 : 12),

                // Total de la venta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isCompleted ? 13 : 15)),
                    Text(
                      currencyFormat.format(ticket.totalVenta),
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: isCompleted ? 15 : 18, 
                        color: isCompleted ? Colors.grey.shade700 : AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 16),
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _despacharPedido(context, ticket),
                          icon: const Icon(LucideIcons.truck, size: 18, color: Colors.white),
                          label: const Text('Despachar', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmarCancelacion(context, ticket),
                          icon: const Icon(LucideIcons.xCircle, size: 18, color: AppTheme.error),
                          label: const Text('Cancelar', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppTheme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _despacharPedido(BuildContext context, Ticket ticket) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    String? selectedRiderId;
    String? selectedRiderName;
    bool esCredito = false;
    final TextEditingController abonoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StreamBuilder<List<Personal>>(
          stream: firebaseService.getPersonalStream(),
          builder: (context, snapshot) {
            List<Personal> activeRiders = [];
            if (snapshot.hasData) {
              activeRiders = snapshot.data!.where((p) => p.activo).toList();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Asignar Repartidor y Despachar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona quién entregará el pedido #${ticket.folio} de ${ticket.clienteNombre}.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 24),
                  if (activeRiders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No hay repartidores activos disponibles.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedRiderId,
                              decoration: InputDecoration(
                                labelText: 'Seleccionar Repartidor',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.two_wheeler, color: Colors.orange),
                              ),
                              hint: const Text('Seleccionar...'),
                              items: activeRiders.map((r) {
                                return DropdownMenuItem(value: r.id, child: Text(r.nombre));
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedRiderId = val;
                                  selectedRiderName = activeRiders.firstWhere((r) => r.id == val).nombre;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Forma de Venta
                            const Text('Forma de Venta:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Completo (Contado)', style: TextStyle(fontSize: 12)),
                                  selected: !esCredito,
                                  selectedColor: Colors.blue.shade50,
                                  checkmarkColor: Colors.blue.shade800,
                                  labelStyle: TextStyle(
                                    color: !esCredito ? Colors.blue.shade800 : AppTheme.textLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  side: BorderSide(
                                    color: !esCredito ? Colors.blue.shade400 : Colors.grey.shade300,
                                    width: !esCredito ? 1.5 : 1.0,
                                  ),
                                  onSelected: (val) {
                                    if (val) setModalState(() => esCredito = false);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('A Crédito / Abono', style: TextStyle(fontSize: 12)),
                                  selected: esCredito,
                                  selectedColor: Colors.blue.shade50,
                                  checkmarkColor: Colors.blue.shade800,
                                  labelStyle: TextStyle(
                                    color: esCredito ? Colors.blue.shade800 : AppTheme.textLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  side: BorderSide(
                                    color: esCredito ? Colors.blue.shade400 : Colors.grey.shade300,
                                    width: esCredito ? 1.5 : 1.0,
                                  ),
                                  onSelected: (val) {
                                    if (val) setModalState(() => esCredito = true);
                                  },
                                ),
                              ],
                            ),
                            
                            if (esCredito) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: abonoCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Abono Inicial (\$)',
                                  prefixText: '\$ ',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            
                            ElevatedButton(
                              onPressed: selectedRiderId == null
                                  ? null
                                  : () async {
                                      Navigator.pop(modalContext); // Cierra bottom sheet
                                      
                                      // Mostrar loading y guardar su BuildContext
                                      BuildContext? loadingCtx;
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) {
                                          loadingCtx = ctx;
                                          return const Center(child: CircularProgressIndicator());
                                        },
                                      );

                                      double abono = 0.0;
                                      double saldo = ticket.totalVenta;
                                      String estado = 'Pendiente';
                                      String formaVenta = 'Contado';

                                      if (esCredito) {
                                        abono = double.tryParse(abonoCtrl.text) ?? 0.0;
                                        if (abono >= ticket.totalVenta) {
                                          abono = ticket.totalVenta;
                                          estado = 'Pagado';
                                        } else {
                                          estado = 'Con Deuda';
                                        }
                                        saldo = ticket.totalVenta - abono;
                                        formaVenta = 'Crédito';
                                      }

                                      try {
                                        await firebaseService.despacharTicketProgramado(
                                          ticket.id,
                                          selectedRiderId!,
                                          selectedRiderName!,
                                          formaVenta: formaVenta,
                                          totalAbonado: abono,
                                          saldoRestante: saldo,
                                          estado: estado,
                                        );
                                        if (loadingCtx != null && loadingCtx!.mounted) {
                                          Navigator.pop(loadingCtx!); // Cierra loading
                                        }
                                        if (context.mounted) {
                                          // Actualizar los datos del ticket localmente para la pantalla de éxito
                                          ticket.repartidorId = selectedRiderId;
                                          ticket.repartidorNombre = selectedRiderName;
                                          ticket.estadoEntrega = 'Entregado';
                                          ticket.tipoEntrega = 'Domicilio';
                                          ticket.formaVenta = formaVenta;
                                          ticket.totalAbonado = abono;
                                          ticket.estado = estado;

                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PaymentSuccessScreen(
                                                ticket: ticket,
                                                abonado: abono,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (loadingCtx != null && loadingCtx!.mounted) {
                                          Navigator.pop(loadingCtx!); // Cierra loading
                                        }
                                        if (context.mounted) {
                                          OverlayHelper.showError(context, message: 'Error al despachar: $e');
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: AppTheme.accent,
                              ),
                              child: const Text('Confirmar Envío', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarCancelacion(BuildContext context, Ticket ticket) {
    final TextEditingController pinCtrl = TextEditingController();
    final TextEditingController motivoCtrl = TextEditingController();
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Pedido', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('¿Estás seguro de cancelar el pedido programado #${ticket.folio}? Se revertirán los registros vinculados.'),
               const SizedBox(height: 16),
               TextField(
                 controller: pinCtrl,
                 obscureText: true,
                 keyboardType: TextInputType.number,
                 decoration: const InputDecoration(labelText: 'PIN de autorización', border: OutlineInputBorder()),
                 autofocus: true,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: motivoCtrl,
                 textCapitalization: TextCapitalization.sentences,
                 decoration: const InputDecoration(
                   labelText: 'Motivo de cancelación',
                   border: OutlineInputBorder(),
                   hintText: 'Ej. El cliente canceló, error de captura...',
                 ),
                 maxLines: 2,
               ),
            ],
          ),
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
              final motivo = motivoCtrl.text.trim();
              if (motivo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar un motivo de cancelación'), backgroundColor: AppTheme.error));
                return;
              }
              Navigator.pop(ctx); // Cierra dialog
              
              // Mostrar loading y guardar su BuildContext
              BuildContext? loadingCtx;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  loadingCtx = ctx;
                  return const Center(child: CircularProgressIndicator());
                },
              );

              try {
                await firebaseService.cancelarTicket(ticket, motivo);
                if (loadingCtx != null && loadingCtx!.mounted) {
                  Navigator.pop(loadingCtx!); // Cierra loading
                }
                if (context.mounted) {
                  OverlayHelper.showSuccess(context, message: 'Pedido Cancelado Exitosamente');
                }
              } catch (e) {
                if (loadingCtx != null && loadingCtx!.mounted) {
                  Navigator.pop(loadingCtx!); // Cierra loading
                }
                if (context.mounted) {
                  OverlayHelper.showError(context, message: 'Error al cancelar: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
