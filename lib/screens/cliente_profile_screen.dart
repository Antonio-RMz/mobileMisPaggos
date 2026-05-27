import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../services/pdf_service.dart';
import '../utils/overlay_helper.dart';
import 'general_success_screen.dart';

class ClienteProfileScreen extends StatefulWidget {
  final Cliente cliente;
  const ClienteProfileScreen({super.key, required this.cliente});

  @override
  State<ClienteProfileScreen> createState() => _ClienteProfileScreenState();
}

class _ClienteProfileScreenState extends State<ClienteProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // _abrirWhatsApp se movió a GeneralSuccessScreen

  void _mostrarDialogoAbonoGeneral() {
    if (widget.cliente.deudaTotal <= 0) return;

    final TextEditingController abonoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final double abonoIngresado = double.tryParse(abonoCtrl.text) ?? 0.0;
            final double restante = widget.cliente.deudaTotal - abonoIngresado;

            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: bottomInset > 0 ? bottomInset + 24 : 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Abono General a Cuenta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Deuda Actual:', style: TextStyle(fontSize: 16, color: Colors.red)),
                        Text(_currencyFormat.format(widget.cliente.deudaTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: abonoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Monto a Abonar',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  if (abonoIngresado > 0)
                    Text(
                      restante > 0 
                        ? 'Deuda Restante: ${_currencyFormat.format(restante)}' 
                        : 'Se liquidará TODA la deuda del cliente.',
                      style: TextStyle(
                        color: restante > 0 ? Colors.orange[800] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green[600],
                    ),
                    onPressed: () async {
                      final double abonoFinal = double.tryParse(abonoCtrl.text) ?? 0.0;
                      
                      if (abonoFinal <= 0) return;
                      if (abonoFinal > widget.cliente.deudaTotal) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El abono no puede superar la deuda total')));
                        return;
                      }

                      // Mostrar Loading
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      try {
                        await _firebaseService.procesarAbonoGeneral(widget.cliente.id, abonoFinal);
                        
                        // Actualizar cliente localmente para reflejar UI rápida
                        setState(() {
                          widget.cliente.deudaTotal -= abonoFinal;
                        });

                        if (mounted) {
                          Navigator.pop(context); // Cierra loading
                          final msj = 'Hola ${widget.cliente.nombre}, confirmamos tu abono general por ${_currencyFormat.format(abonoFinal)}. Tu nuevo saldo es ${_currencyFormat.format(widget.cliente.deudaTotal)}.\n¡Muchas gracias por tu preferencia!';
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeneralSuccessScreen(
                                title: '¡Abono Registrado!',
                                mainText: _currencyFormat.format(abonoFinal),
                                subtitle: 'a la cuenta de ${widget.cliente.nombre}',
                                whatsAppPhone: widget.cliente.celular,
                                whatsAppMessage: msj,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context); // Cierra loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Confirmar Abono', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoAbonoEspecifico(Ticket ticket) {
    if (ticket.saldoRestante <= 0) return;

    final TextEditingController abonoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final double abonoIngresado = double.tryParse(abonoCtrl.text) ?? 0.0;
            final double restante = ticket.saldoRestante - abonoIngresado;

            return Padding(
              padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: bottomInset > 0 ? bottomInset + 24 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Abono a Ticket', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Deuda del Ticket:', style: TextStyle(fontSize: 16, color: Colors.deepOrange)),
                        Text(_currencyFormat.format(ticket.saldoRestante), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: abonoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Monto a Abonar',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  if (abonoIngresado > 0)
                    Text(
                      restante > 0 ? 'Resta en Ticket: ${_currencyFormat.format(restante)}' : 'Se liquidará este ticket por completo.',
                      style: TextStyle(
                        color: restante > 0 ? Colors.orange[800] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange[800],
                    ),
                    onPressed: () async {
                      final double abonoFinal = double.tryParse(abonoCtrl.text) ?? 0.0;
                      
                      if (abonoFinal <= 0) return;
                      if (abonoFinal > ticket.saldoRestante) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El abono no puede superar la deuda del ticket')));
                        return;
                      }

                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      try {
                        await _firebaseService.procesarAbonoEspecifico(widget.cliente.id, ticket, abonoFinal);
                        
                        setState(() {
                          widget.cliente.deudaTotal -= abonoFinal;
                        });

                        if (mounted) {
                          Navigator.pop(context); // loading
                          final msj = 'Hola ${widget.cliente.nombre}, confirmamos tu pago por ${_currencyFormat.format(abonoFinal)} a tu ticket.\n¡Muchas gracias por tu preferencia!';
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeneralSuccessScreen(
                                title: '¡Abono a Ticket Registrado!',
                                mainText: _currencyFormat.format(abonoFinal),
                                subtitle: 'para el ticket de ${widget.cliente.nombre}',
                                whatsAppPhone: widget.cliente.celular,
                                whatsAppMessage: msj,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('Abonar a Ticket', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Perfil del Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primary),
            tooltip: 'Generar Estado de Cuenta',
            onPressed: () async {
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              try {
                final tickets = await _firebaseService.getTicketsByCliente(widget.cliente.id).first;
                final abonos = await _firebaseService.getAbonosByCliente(widget.cliente.id).first;
                if (context.mounted) Navigator.pop(context);
                await PdfService.imprimirEstadoCuenta(widget.cliente, tickets, abonos);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Header del cliente
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                  child: Text(
                    widget.cliente.nombre[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.cliente.nombre} ${widget.cliente.apPaterno}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                if (widget.cliente.telefono.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Tel: ${widget.cliente.telefono}', style: const TextStyle(color: Colors.grey)),
                  ),
                const SizedBox(height: 24),
                
                // Tarjeta de Deuda
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.cliente.deudaTotal > 0 
                        ? [Colors.red[400]!, Colors.red[700]!] 
                        : [Colors.green[400]!, Colors.green[600]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.cliente.deudaTotal > 0 ? Colors.red : Colors.green).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deuda Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          SizedBox(height: 4),
                        ],
                      ),
                      Text(
                        _currencyFormat.format(widget.cliente.deudaTotal),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                if (widget.cliente.deudaTotal > 0)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Abonar a la Cuenta General', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _mostrarDialogoAbonoGeneral,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Historial de Tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ),
          ),
          const SizedBox(height: 8),

          // Lista de Tickets
          Expanded(
            child: StreamBuilder<List<Ticket>>(
              stream: _firebaseService.getTicketsByCliente(widget.cliente.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error al cargar tickets'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final tickets = snapshot.data ?? [];
                
                if (tickets.isEmpty) {
                  return const Center(child: Text('No hay historial de compras.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final t = tickets[index];
                    final bool pagado = t.estado == 'Pagado';
                    final String fechaStr = t.fecha != null ? DateFormat('dd MMM yyyy - hh:mm a').format(t.fecha!.toDate()) : 'Sin fecha';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                      elevation: 0,
                      child: ExpansionTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: CircleAvatar(
                          backgroundColor: pagado ? Colors.green[50] : Colors.red[50],
                          child: Icon(
                            pagado ? Icons.check_circle : Icons.warning_rounded,
                            color: pagado ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text('Total: ${_currencyFormat.format(t.totalVenta)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            if (!pagado)
                              Text('Resta: ${_currencyFormat.format(t.saldoRestante)}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        children: [
                          Container(
                            color: Colors.grey[50],
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...t.productos.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${p.cantidad}x ${p.nombre}', style: const TextStyle(fontSize: 13)),
                                      Text(_currencyFormat.format(p.subtotal), style: const TextStyle(fontSize: 13, color: AppTheme.accent)),
                                    ],
                                  ),
                                )),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Venta:', style: TextStyle(fontSize: 13)),
                                    Text(_currencyFormat.format(t.totalVenta), style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Abonado:', style: TextStyle(fontSize: 13)),
                                    Text(_currencyFormat.format(t.totalAbonado), style: const TextStyle(fontSize: 13, color: Colors.green)),
                                  ],
                                ),
                                if (!pagado)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Saldo Restante:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      Text(_currencyFormat.format(t.saldoRestante), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ],
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (!pagado)
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.payment, size: 16, color: Colors.white),
                                        label: const Text('Abonar', style: TextStyle(color: Colors.white)),
                                        onPressed: () => _mostrarDialogoAbonoEspecifico(t),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                                      ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.share, size: 16, color: AppTheme.primary),
                                      label: const Text('Compartir PDF', style: TextStyle(color: AppTheme.primary)),
                                      onPressed: () {
                                        PdfService.imprimirTicket(t);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
