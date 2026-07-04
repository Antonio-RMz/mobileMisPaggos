import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../services/pdf_service.dart';
import '../utils/overlay_helper.dart';
import 'general_success_screen.dart';
import 'nuevo_pedido_screen.dart';

class ClienteProfileScreen extends StatefulWidget {
  final Cliente cliente;
  const ClienteProfileScreen({super.key, required this.cliente});

  @override
  State<ClienteProfileScreen> createState() => _ClienteProfileScreenState();
}

class _ClienteProfileScreenState extends State<ClienteProfileScreen> {
  FirebaseService get _firebaseService => Provider.of<FirebaseService>(context, listen: false);
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firebaseService.recalcularDeudaCliente(widget.cliente.id);
    });
  }

  Future<void> _enviarWhatsAppTicket(Cliente cliente, Ticket t) async {
    String cel = cliente.celular.replaceAll(RegExp(r'\D'), '');
    if (cel.isEmpty) {
      OverlayHelper.showError(context, message: 'El cliente no tiene un número de celular registrado.');
      return;
    }
    
    // Si es México, a veces se requiere 52
    if (cel.length == 10) cel = '52$cel';

    String mensaje = 'Hola ${cliente.nombre},\n\n';
    mensaje += 'Aquí tienes el detalle de tu nota de remisión / pedido:\n\n';
    mensaje += 'Folio: ${t.folio}\n';
    if (t.fecha != null) {
      mensaje += 'Fecha: ${DateFormat('dd/MM/yyyy').format(t.fecha!.toDate())}\n';
    }
    mensaje += 'Total: ${_currencyFormat.format(t.totalVenta)}\n';
    mensaje += 'Abonado: ${_currencyFormat.format(t.totalAbonado)}\n';
    mensaje += 'Restante: ${_currencyFormat.format(t.saldoRestante)}\n\n';
    mensaje += 'Productos:\n';
    for (var p in t.productos) {
      mensaje += '- ${p.descripcionAmigable}\n';
    }
    
    final uri = Uri.parse('https://wa.me/$cel?text=${Uri.encodeComponent(mensaje)}');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) OverlayHelper.showError(context, message: 'No se pudo abrir WhatsApp');
      }
    } catch (e) {
      if (mounted) OverlayHelper.showError(context, message: 'Error al abrir WhatsApp: $e');
    }
  }

  void _mostrarDialogoAbonoGeneral(Cliente cliente) {
    if (cliente.deudaTotal <= 0) return;

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
            final double restante = cliente.deudaTotal - abonoIngresado;

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
                        Text(_currencyFormat.format(cliente.deudaTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
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
                      if (abonoFinal > cliente.deudaTotal) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El abono no puede superar la deuda total')));
                        return;
                      }

                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar Abono'),
                          content: Text('¿Deseas registrar este abono general por \$$abonoFinal?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      // Mostrar Loading
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      final double saldoAnterior = cliente.deudaTotal;
                      final double nuevoSaldo = saldoAnterior - abonoFinal;

                      try {
                        await _firebaseService.procesarAbonoGeneral(cliente.id, abonoFinal);

                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pop(); // Cierra loading
                          final msj = 'Confirmamos tu abono general por ${_currencyFormat.format(abonoFinal)}. Tu nuevo saldo es ${_currencyFormat.format(nuevoSaldo)}.\n¡Muchas gracias por tu preferencia!';
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeneralSuccessScreen(
                                title: '¡Abono Registrado!',
                                mainText: _currencyFormat.format(abonoFinal),
                                subtitle: 'a la cuenta de ${cliente.nombre}',
                                whatsAppPhone: cliente.celular,
                                whatsAppMessage: msj,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pop(); // Cierra loading
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

  void _mostrarDialogoAbonoEspecifico(Cliente cliente, Ticket ticket) {
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

                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar Abono'),
                          content: Text('¿Deseas registrar este abono de \$$abonoFinal al ticket #${ticket.folio}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      final double saldoAnteriorTicket = ticket.saldoRestante;
                      final double nuevoSaldoTicket = saldoAnteriorTicket - abonoFinal;

                      try {
                        await _firebaseService.procesarAbonoEspecifico(cliente.id, ticket, abonoFinal);

                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pop(); // loading
                          Navigator.pop(context); // cerrar bottom sheet de abono
                          
                          final msj = 'Confirmamos tu abono por ${_currencyFormat.format(abonoFinal)}. El saldo restante del pedido ${ticket.folio} es ${_currencyFormat.format(nuevoSaldoTicket)}.\n¡Muchas gracias por tu preferencia!';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeneralSuccessScreen(
                                title: '¡Abono a Ticket Registrado!',
                                mainText: _currencyFormat.format(abonoFinal),
                                subtitle: 'para el ticket de ${cliente.nombre}',
                                whatsAppPhone: cliente.celular,
                                whatsAppMessage: msj,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
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

  Future<void> _mostrarDialogoCancelacion(Cliente cliente, Ticket ticket) async {
    final TextEditingController motivoCtrl = TextEditingController();
    final TextEditingController pinCtrl = TextEditingController();

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
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PIN de autorización', border: OutlineInputBorder()),
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
                if (pinCtrl.text != '1234') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrecto'), backgroundColor: AppTheme.error));
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
      final safeContext = this.context;
      if (safeContext.mounted) showDialog(context: safeContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      try {
        await _firebaseService.cancelarPedido(ticket, motivoCtrl.text.trim());
        
        if (safeContext.mounted) {
          Navigator.of(safeContext, rootNavigator: true).pop(); // Cierra loading
          OverlayHelper.showSuccess(safeContext, message: 'Pedido Cancelado Exitosamente');
        }
      } catch (e) {
        if (safeContext.mounted) {
          Navigator.of(safeContext, rootNavigator: true).pop(); // Cierra loading
          OverlayHelper.showError(safeContext, message: 'Error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Cliente>(
      stream: _firebaseService.streamCliente(widget.cliente.id),
      initialData: widget.cliente,
      builder: (context, clienteSnapshot) {
        final cliente = clienteSnapshot.data ?? widget.cliente;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Perfil del Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primary, size: 20),
                  label: const Text('Estado de Cuenta', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                    try {
                      final tickets = await _firebaseService.getTicketsByCliente(cliente.id).first;
                      final abonos = await _firebaseService.getAbonosByCliente(cliente.id).first;
                      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                      if (context.mounted) {
                        await PdfService.imprimirEstadoCuenta(context, cliente, tickets, abonos);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              )
            ],
          ),
          body: StreamBuilder<List<Ticket>>(
            stream: _firebaseService.getTicketsByCliente(cliente.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Error al cargar datos'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final tickets = snapshot.data ?? [];
              
              return Column(
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
                          backgroundColor: Color(cliente.colorPerfil),
                          foregroundColor: AppTheme.slateBlue,
                          child: Text(
                            cliente.iniciales,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${cliente.nombre} ${cliente.apPaterno}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        if (cliente.telefono.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Tel: ${cliente.telefono}', style: const TextStyle(color: Colors.grey)),
                          ),
                        const SizedBox(height: 24),
                        
                        // Tarjeta de Deuda
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: cliente.deudaTotal > 0 
                                ? [Colors.red[400]!, Colors.red[700]!] 
                                : [Colors.green[400]!, Colors.green[600]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (cliente.deudaTotal > 0 ? Colors.red : Colors.green).withOpacity(0.3),
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
                                _currencyFormat.format(cliente.deudaTotal),
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (cliente.deudaTotal > 0)
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
                              onPressed: () => _mostrarDialogoAbonoGeneral(cliente),
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
                    child: tickets.isEmpty 
                      ? const Center(child: Text('No hay historial de compras.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
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
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Ticket #${t.folio}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(_currencyFormat.format(t.totalVenta), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    if (!pagado && t.estadoEntrega != 'Cancelado')
                                      Text('Resta: ${_currencyFormat.format(t.saldoRestante)}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                    if (t.estadoEntrega == 'Cancelado')
                                      Text('Cancelado: ${t.motivoCancelacion}', style: const TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic)),
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(p.descripcionAmigable, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                                    if (p.observaciones.isNotEmpty)
                                                      Text(p.observaciones, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
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
                                            if (!pagado && t.estadoEntrega != 'Cancelado')
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.payment, size: 16, color: Colors.white),
                                                label: const Text('Abonar', style: TextStyle(color: Colors.white)),
                                                onPressed: () => _mostrarDialogoAbonoEspecifico(cliente, t),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                                              ),
                                            if (t.estadoEntrega == 'Pendiente')
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.error),
                                                label: const Text('Cancelar', style: TextStyle(color: AppTheme.error)),
                                                onPressed: () => _mostrarDialogoCancelacion(cliente, t),
                                                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                                              ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.share, size: 16, color: Colors.green),
                                              label: const Text('WhatsApp', style: TextStyle(color: Colors.green)),
                                              onPressed: () {
                                                _enviarWhatsAppTicket(cliente, t);
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
                        ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
