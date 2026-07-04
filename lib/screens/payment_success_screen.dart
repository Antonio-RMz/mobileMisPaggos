import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/ticket_model.dart';
import '../theme/app_theme.dart';
import '../services/pdf_service.dart';
import '../providers/printer_provider.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Ticket ticket;
  final double abonado;

  const PaymentSuccessScreen({
    super.key,
    required this.ticket,
    required this.abonado,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> with SingleTickerProviderStateMixin {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compartirPorWhatsApp() async {
    final sb = StringBuffer();
    sb.writeln('✅ *¡Venta Exitosa!*');
    
    final productosCarniceria = widget.ticket.productos.where((p) => p.seccion == 'carniceria').toList();
    final productosCatalogo = widget.ticket.productos.where((p) => p.seccion != 'carniceria').toList();
    
    final esSoloCarniceria = productosCarniceria.isNotEmpty && productosCatalogo.isEmpty;
    final tieneRepartidor = widget.ticket.tipoEntrega == 'Domicilio' && widget.ticket.repartidorNombre != null;

    if (esSoloCarniceria && tieneRepartidor) {
      sb.writeln('Hola, confirmamos el pago de tu pedido ${widget.ticket.folio} por ${_currencyFormat.format(widget.ticket.totalVenta)}.\n');
      sb.writeln('Repartidor: ${widget.ticket.repartidorNombre}');
      
      sb.writeln('\n*Productos:*');
      for (var p in productosCarniceria) {
        sb.writeln('- ${p.descripcionAmigable} (${_currencyFormat.format(p.precioUnitario)})');
      }
    } else {
      if (tieneRepartidor) {
        sb.writeln('Repartidor: ${widget.ticket.repartidorNombre}');
      }
      sb.writeln('Total: ${_currencyFormat.format(widget.ticket.totalVenta)}');
      sb.writeln('Primer Abono: ${_currencyFormat.format(widget.abonado)}');
      
      final restante = widget.ticket.totalVenta - widget.ticket.totalAbonado;
      if (restante > 0) {
        sb.writeln('Saldo Restante: ${_currencyFormat.format(restante)}');
        final fechaFormateada = widget.ticket.fecha != null 
            ? DateFormat('dd/MM/yyyy').format(widget.ticket.fecha!.toDate())
            : DateFormat('dd/MM/yyyy').format(DateTime.now());
        sb.writeln('Fecha de pago: $fechaFormateada');
      }

      if (productosCarniceria.isNotEmpty) {
        sb.writeln('\n*Productos Carnicería:*');
        for (var p in productosCarniceria) {
          sb.writeln('- ${p.descripcionAmigable} (${_currencyFormat.format(p.precioUnitario)})');
        }
      }
      
      if (productosCatalogo.isNotEmpty) {
        sb.writeln('\n*Productos Catálogo:*');
        for (var p in productosCatalogo) {
          final codigoText = p.codigo.isNotEmpty ? '[${p.codigo}] ' : '';
          sb.writeln('- $codigoText${p.descripcionAmigable} (${_currencyFormat.format(p.precioUnitario)})');
        }
      }
    }

    sb.writeln('\n¡Gracias por tu compra!');

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(sb.toString())}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTotal = widget.ticket.totalVenta - widget.ticket.totalAbonado <= 0;
    
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                // Animación de Éxito
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: AppTheme.success, size: 100),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.ticket.tipoEntrega == 'Domicilio' 
                      ? '¡Pedido Confirmado!' 
                      : (isTotal ? '¡Pago Exitoso!' : '¡Abono Registrado!'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.ticket.tipoEntrega != 'Domicilio' || widget.abonado > 0) ...[
                  Text(
                    _currencyFormat.format(widget.abonado),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'a ${widget.ticket.clienteNombre}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Tarjeta de Resumen (estilo ticket)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Venta:', style: TextStyle(color: Colors.black54, fontSize: 16)),
                          Text(_currencyFormat.format(widget.ticket.totalVenta), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      if (widget.ticket.tipoEntrega != 'Domicilio' || widget.abonado > 0) ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Abonado:', style: TextStyle(color: Colors.black54, fontSize: 16)),
                            Text(_currencyFormat.format(widget.abonado), style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        if (!isTotal) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Saldo Restante:', style: TextStyle(color: Colors.black54, fontSize: 16)),
                              Text(
                                _currencyFormat.format(widget.ticket.totalVenta - widget.ticket.totalAbonado),
                                style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ]
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Botones de acción
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _compartirPorWhatsApp,
                          icon: const Icon(Icons.share, color: Colors.green),
                          label: const Text('Compartir Comprobante (WhatsApp)'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Consumer<PrinterProvider>(
                          builder: (context, printerProvider, child) {
                            bool isConnected = printerProvider.isConnected;
                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected ? Colors.blueAccent : Colors.white,
                                foregroundColor: isConnected ? Colors.white : AppTheme.textDark,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () async {
                                if (isConnected) {
                                  try {
                                    await printerProvider.printDeliveryTicket(widget.ticket);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Impresión enviada correctamente'), backgroundColor: Colors.green),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                } else {
                                  await PdfService.imprimirTicket(widget.ticket, abonoReciente: widget.abonado);
                                }
                              },
                              icon: Icon(Icons.print, color: isConnected ? Colors.white : Colors.blueAccent),
                              label: Text(isConnected ? 'Imprimir Ticket (Bluetooth)' : 'Generar Ticket PDF'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst); // Cerrar success screen y regresar al main
                        },
                        child: const Text(
                          'Volver al Directorio',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}
