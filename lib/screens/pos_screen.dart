import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/producto_model.dart';
import '../models/ticket_model.dart';
import '../models/personal_model.dart';
import '../services/firebase_service.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'payment_success_screen.dart';

class PosScreen extends StatefulWidget {
  final Cliente cliente;
  const PosScreen({super.key, required this.cliente});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  String _searchQuery = '';

  Future<void> _mostrarDialogoConfiguracionProducto(BuildContext context, CartProvider cart, Producto producto, {CartItem? itemActual}) async {
    String modoVenta = 'Unidad Base'; // 'Unidad Base', 'Monto ($)', 'Gramos'
    final double precioKilo = producto.precio;
    
    double cantidadBaseInicial = itemActual?.cantidad ?? 1.0;
    String obsInicial = itemActual?.observaciones ?? '';
    
    // Intentar quitar la etiqueta automática (Cobro: $...) si existe al editar
    if (obsInicial.startsWith('(Cobro:')) {
      final idx = obsInicial.indexOf(') - ');
      if (idx != -1) {
        obsInicial = obsInicial.substring(idx + 4);
      } else {
        obsInicial = ''; // Era solo el cobro
      }
    }

    final TextEditingController inputCtrl = TextEditingController();
    final TextEditingController obsCtrl = TextEditingController(text: obsInicial);
    final TextEditingController overrideCtrl = TextEditingController();
    bool overrideTotal = false;
    
    inputCtrl.text = (itemActual != null) ? cantidadBaseInicial.toString() : '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double inputVal = double.tryParse(inputCtrl.text) ?? 0.0;
            double cantidadFinal = 0.0;
            double totalCalculado = 0.0;

            if (modoVenta == 'Monto (\$)' && precioKilo > 0) {
              cantidadFinal = inputVal / precioKilo;
              totalCalculado = inputVal;
            } else if (modoVenta == 'Gramos') {
              cantidadFinal = inputVal / 1000;
              totalCalculado = cantidadFinal * precioKilo;
            } else {
              cantidadFinal = inputVal;
              totalCalculado = cantidadFinal * precioKilo;
            }

            return AlertDialog(
              title: Text('Configurar - ${producto.nombre}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: modoVenta,
                      decoration: const InputDecoration(labelText: 'Modo de Venta', border: OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'Unidad Base', child: Text('Por ${producto.unidadVenta}')),
                        if (producto.unidadVenta == 'kg') ...[
                          const DropdownMenuItem(value: 'Monto (\$)', child: Text('Por Monto (\$)' )),
                          const DropdownMenuItem(value: 'Gramos', child: Text('Por Gramos')),
                        ]
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            modoVenta = val;
                            inputCtrl.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: inputCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      onChanged: (v) => setStateDialog((){}),
                      decoration: InputDecoration(
                        labelText: modoVenta == 'Monto (\$)' ? 'Monto a Cobrar (\$)' : (modoVenta == 'Gramos' ? 'Gramos (g)' : 'Cantidad (${producto.unidadVenta})'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones / Instrucciones',
                        hintText: 'Ej. Tasajeado, En cubos, Sin grasa...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (inputVal > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Equivale a:'),
                                Text('${cantidadFinal.toStringAsFixed(3)} ${producto.unidadVenta}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total:'),
                                Text(_currencyFormat.format(totalCalculado), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (inputVal > 0) ...[
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('¿Cambiar total a cobrar?', style: TextStyle(fontWeight: FontWeight.bold)),
                        value: overrideTotal,
                        onChanged: (val) {
                          setStateDialog(() {
                            overrideTotal = val ?? false;
                            if (overrideTotal) {
                              overrideCtrl.text = totalCalculado.toStringAsFixed(2);
                            } else {
                              overrideCtrl.clear();
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppTheme.primary,
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: overrideTotal ? 70 : 0,
                        child: SingleChildScrollView(
                          child: TextField(
                            controller: overrideCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: overrideTotal,
                            onChanged: (v) => setStateDialog((){}),
                            decoration: InputDecoration(
                              labelText: 'Nuevo Total a Cobrar (\$)',
                              prefixText: '\$ ',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: overrideTotal ? Colors.white : Colors.grey[200],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (cantidadFinal > 0) {
                      double overrideVal = double.tryParse(overrideCtrl.text) ?? totalCalculado;
                      double precioUnitarioCalculado = overrideTotal && cantidadFinal > 0 ? (overrideVal / cantidadFinal) : precioKilo;
                      
                      String obsStr = obsCtrl.text.trim();
                      if (modoVenta == 'Monto (\$)' && obsStr.isEmpty) {
                        obsStr = '(Cobro: ${_currencyFormat.format(inputVal)})';
                      } else if (modoVenta == 'Monto (\$)' && obsStr.isNotEmpty) {
                        obsStr = '(Cobro: ${_currencyFormat.format(inputVal)}) - $obsStr';
                      } else if (modoVenta == 'Gramos' && obsStr.isEmpty) {
                        obsStr = '(Pedido original: ${inputVal.toStringAsFixed(0)} g)';
                      } else if (modoVenta == 'Gramos' && obsStr.isNotEmpty) {
                        obsStr = '(Pedido original: ${inputVal.toStringAsFixed(0)} g) - $obsStr';
                      }

                      if (overrideTotal && overrideVal != totalCalculado) {
                        final ajusteStr = '(Ajuste de precio: Cobrado a ${_currencyFormat.format(overrideVal)})';
                        obsStr = obsStr.isEmpty ? ajusteStr : '$obsStr - $ajusteStr';
                      }

                      if (itemActual != null) {
                        cart.updateQuantity(itemActual.id, cantidadFinal, observaciones: obsStr, precioUnitario: precioUnitarioCalculado);
                      } else {
                        cart.addItem(producto, cantidad: cantidadFinal, observaciones: obsStr, precioUnitario: precioUnitarioCalculado);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _mostrarDialogoCobro(BuildContext context, CartProvider cart) {
    if (cart.items.isEmpty) return;

    final itemsTienda = cart.items.where((i) => !i.isDomicilio).toList();
    final itemsDomicilio = cart.items.where((i) => i.isDomicilio).toList();
    
    final double totalTienda = itemsTienda.fold(0.0, (sum, item) => sum + item.subtotal);
    final double totalDomicilio = itemsDomicilio.fold(0.0, (sum, item) => sum + item.subtotal);

    final TextEditingController abonoCtrl = TextEditingController();
    bool todoACredito = false;
    String? repartidorId;
    String? repartidorNombre;

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
            final double restanteTienda = totalTienda - abonoIngresado;

            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: bottomInset > 0 ? bottomInset + 24 : 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Procesar Venta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  
                  // Resumen
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.backgroundLight, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        if (itemsTienda.isNotEmpty)
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Total Tienda:', style: TextStyle(fontSize: 16, color: AppTheme.success, fontWeight: FontWeight.bold)),
                            Text(_currencyFormat.format(totalTienda), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.success)),
                          ]),
                        if (itemsTienda.isNotEmpty && itemsDomicilio.isNotEmpty) const Divider(),
                        if (itemsDomicilio.isNotEmpty)
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Total Domicilio (Crédito):', style: TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                            Text(_currencyFormat.format(totalDomicilio), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ]),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Gran Total:', style: TextStyle(fontSize: 16)),
                          Text(_currencyFormat.format(totalTienda + totalDomicilio), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (itemsDomicilio.isNotEmpty) ...[
                    StreamBuilder<List<Personal>>(
                      stream: _firebaseService.getPersonalStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final repartidores = snapshot.data!.where((p) => p.rol == 'Repartidor' && p.activo).toList();
                        
                        return DropdownButtonFormField<String>(
                          value: repartidorId,
                          decoration: InputDecoration(
                            labelText: 'Asignar Repartidor (Domicilio)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.two_wheeler, color: Colors.orange),
                          ),
                          hint: const Text('Seleccionar repartidor...'),
                          items: repartidores.map((r) {
                            return DropdownMenuItem(value: r.id, child: Text(r.nombre));
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              repartidorId = val;
                              repartidorNombre = repartidores.firstWhere((r) => r.id == val).nombre;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (itemsTienda.isNotEmpty) ...[
                    CheckboxListTile(
                      title: const Text('Pago Tienda a Crédito (Sin Abono)'),
                      value: todoACredito,
                      activeColor: AppTheme.primary,
                      onChanged: (val) {
                        setModalState(() {
                          todoACredito = val ?? false;
                          if (todoACredito) abonoCtrl.clear();
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (!todoACredito) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: abonoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => setModalState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Monto a Abonar (Tienda)',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: TextButton(
                            onPressed: () {
                              setModalState(() {
                                abonoCtrl.text = totalTienda.toStringAsFixed(2);
                              });
                            },
                            child: const Text('Liquidar', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (abonoIngresado > 0)
                        Text(
                          restanteTienda > 0 
                            ? 'Saldo Restante Tienda: ${_currencyFormat.format(restanteTienda)}' 
                            : 'Tienda liquidada por completo.',
                          style: TextStyle(
                            color: restanteTienda > 0 ? Colors.orange[800] : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ],

                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () async {
                      final double abonoFinal = todoACredito ? 0.0 : (double.tryParse(abonoCtrl.text) ?? 0.0);
                      
                      if (itemsTienda.isNotEmpty && abonoFinal > totalTienda) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El abono no puede superar el total de tienda')));
                        return;
                      }

                      if (itemsDomicilio.isNotEmpty && repartidorId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor asigna un repartidor para la entrega a domicilio.')));
                        return;
                      }

                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      try {
                        Ticket? ticketTienda;
                        Ticket? ticketDomicilio;

                        if (itemsTienda.isNotEmpty) {
                          ticketTienda = Ticket(
                            clienteId: widget.cliente.id,
                            clienteNombre: '${widget.cliente.nombre} ${widget.cliente.apPaterno}',
                            tipoEntrega: 'Local',
                            estadoEntrega: 'Entregado',
                            productos: itemsTienda.map((i) {
                              return TicketItem(
                                productoId: i.producto.id,
                                codigo: i.producto.codigo,
                                nombre: i.producto.nombre,
                                cantidad: i.cantidad,
                                precioUnitario: i.precioUnitario,
                                observaciones: i.observaciones,
                              );
                            }).toList(),
                            totalVenta: totalTienda,
                            totalAbonado: abonoFinal,
                            estado: (totalTienda - abonoFinal) <= 0 ? 'Pagado' : 'Con Deuda',
                          );
                          await _firebaseService.procesarVenta(ticketTienda);
                        }

                        if (itemsDomicilio.isNotEmpty) {
                          ticketDomicilio = Ticket(
                            clienteId: widget.cliente.id,
                            clienteNombre: '${widget.cliente.nombre} ${widget.cliente.apPaterno}',
                            tipoEntrega: 'Domicilio',
                            repartidorId: repartidorId,
                            repartidorNombre: repartidorNombre,
                            estadoEntrega: 'Pendiente',
                            productos: itemsDomicilio.map((i) {
                              return TicketItem(
                                productoId: i.producto.id,
                                codigo: i.producto.codigo,
                                nombre: i.producto.nombre,
                                cantidad: i.cantidad,
                                precioUnitario: i.precioUnitario,
                                observaciones: i.observaciones,
                              );
                            }).toList(),
                            totalVenta: totalDomicilio,
                            totalAbonado: 0.0, // Domicilio siempre es crédito hasta que el repartidor cobre
                            estado: 'Con Deuda',
                          );
                          await _firebaseService.procesarVenta(ticketDomicilio);
                        }

                        if (mounted) {
                          Navigator.pop(context); // Cierra loading
                          Navigator.pop(context); // Cierra modal
                          cart.clearCart();
                          
                          // Ir a la pantalla de éxito pasando el ticket que tenga pago o el principal
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentSuccessScreen(
                                ticket: ticketTienda ?? ticketDomicilio!,
                                abonado: abonoFinal,
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
                    child: const Text('Confirmar Venta', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarCarritoBottomSheet(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tu Carrito', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: AppTheme.error),
                      onPressed: () {
                        cart.clearCart();
                        Navigator.pop(context);
                      },
                      tooltip: 'Vaciar carrito',
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: cart.items.isEmpty
                  ? const Center(child: Text('El carrito está vacío', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final bool usaFracciones = item.producto.unidadVenta != 'pieza' && item.producto.unidadVenta != 'paquete';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: AppTheme.backgroundLight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                      if (item.observaciones.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(item.observaciones, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
                                      ],
                                      const SizedBox(height: 4),
                                      StatefulBuilder(
                                        builder: (context, setStateItem) {
                                          return Row(
                                            children: [
                                              Icon(item.isDomicilio ? Icons.two_wheeler : Icons.storefront, size: 16, color: item.isDomicilio ? Colors.orange : AppTheme.success),
                                              const SizedBox(width: 4),
                                              Text(item.isDomicilio ? 'Envío' : 'Tienda', style: TextStyle(fontSize: 12, color: item.isDomicilio ? Colors.orange : AppTheme.success, fontWeight: FontWeight.bold)),
                                              Switch(
                                                value: item.isDomicilio,
                                                activeColor: Colors.orange,
                                                onChanged: (val) {
                                                  cart.toggleDomicilio(item.id, val);
                                                  setStateItem(() {});
                                                },
                                              ),
                                            ],
                                          );
                                        }
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!usaFracciones) ...[
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                                            onPressed: () => cart.updateQuantity(item.id, item.cantidad - 1),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('${item.cantidad.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.add_circle_outline, color: AppTheme.success),
                                            onPressed: () => cart.updateQuantity(item.id, item.cantidad + 1),
                                          ),
                                        ] else ...[
                                          TextButton.icon(
                                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _mostrarDialogoConfiguracionProducto(context, cart, item.producto, itemActual: item);
                                            },
                                            icon: const Icon(Icons.scale, size: 16, color: AppTheme.primary),
                                            label: Text('${item.cantidad.toStringAsFixed(2)} ${item.unidadVenta}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                          ),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                            onPressed: () {
                                              cart.removeItem(item.id);
                                              if (cart.items.isEmpty) Navigator.pop(context);
                                            },
                                          ),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currencyFormat.format(item.subtotal),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Venta', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                            Text(
                              _currencyFormat.format(cart.totalCart),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          backgroundColor: cart.items.isEmpty ? Colors.grey : AppTheme.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: cart.items.isEmpty ? null : () {
                          Navigator.pop(context);
                          _mostrarDialogoCobro(context, cart);
                        },
                        icon: const Icon(Icons.payments_outlined, color: Colors.white),
                        label: const Text('Cobrar', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String categoria) {
    switch (categoria) {
      case 'Carnes':
        return Icons.set_meal_outlined;
      case 'Cremería':
        return Icons.egg_outlined;
      case 'Abarrotes':
        return Icons.shopping_basket_outlined;
      case 'Catálogo':
        return Icons.menu_book_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildProductList(CartProvider cart, BuildContext context, {required bool isCarniceria}) {
    return StreamBuilder<List<Producto>>(
      stream: _firebaseService.getProductosStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        var productos = snapshot.data!;
        
        // Filtro por sección
        productos = productos.where((p) => isCarniceria ? p.seccion == 'carniceria' : p.seccion != 'carniceria').toList();

        if (_searchQuery.isNotEmpty) {
          productos = productos.where((p) => p.nombre.toLowerCase().contains(_searchQuery) || p.codigo.toLowerCase().contains(_searchQuery)).toList();
        } else {
          productos.sort((a, b) => a.nombre.compareTo(b.nombre));
        }
        
        if (productos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('No se encontraron productos', style: TextStyle(color: AppTheme.textLight)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length,
          itemBuilder: (context, index) {
            final p = productos[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final bool usaFracciones = p.unidadVenta != 'pieza' && p.unidadVenta != 'paquete';
                  
                  if (usaFracciones || isCarniceria) {
                    _mostrarDialogoConfiguracionProducto(context, cart, p);
                  } else {
                    cart.addItem(p);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${p.nombre} agregado al carrito'),
                        duration: const Duration(milliseconds: 800),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                  FocusScope.of(context).unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCarniceria ? Colors.redAccent.withOpacity(0.05) : AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(isCarniceria ? Icons.set_meal : _getCategoryIcon(p.categoria), color: isCarniceria ? Colors.redAccent : AppTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            if (!isCarniceria && p.codigo.isNotEmpty)
                              Text('Cód: ${p.codigo}', style: const TextStyle(fontSize: 12, color: AppTheme.textLight))
                            else if (p.codigo.isNotEmpty)
                              Text('Cód Int: ${p.codigo}', style: const TextStyle(fontSize: 12, color: AppTheme.textLight))
                            else
                              Text(p.categoria, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormat.format(p.precio), 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isCarniceria ? Colors.redAccent : AppTheme.accent)
                          ),
                          Text('por ${p.unidadVenta}', style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (cart.items.isEmpty) {
          Navigator.of(context).pop();
          return;
        }

        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Cancelar Venta?'),
            content: const Text('Tienes productos en el carrito. Si sales ahora, se perderán.\n\n¿Deseas salir de todas formas?'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, continuar venta', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Sí, salir y vaciar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          cart.clearCart();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
              onPressed: () async {
                // Manually trigger the pop scope logic
                if (cart.items.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Cancelar Venta?'),
                    content: const Text('Tienes productos en el carrito. Si sales ahora, se perderán.\n\n¿Deseas salir de todas formas?'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No, continuar venta', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Sí, salir y vaciar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
        
                if (confirm == true) {
                  cart.clearCart();
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nueva Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                Text('${widget.cliente.nombre} ${widget.cliente.apPaterno}', style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
              ],
            ),
            bottom: const TabBar(
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textLight,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Catálogo'),
                Tab(icon: Icon(Icons.set_meal_outlined), text: 'Carnicería'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Buscador Flotante
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textLight),
                    filled: true,
                    fillColor: AppTheme.cardHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), 
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              
              // Catálogo de Productos
              Expanded(
                child: TabBarView(
                  children: [
                    _buildProductList(cart, context, isCarniceria: false),
                    _buildProductList(cart, context, isCarniceria: true),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: cart.items.isEmpty 
            ? null 
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _mostrarCarritoBottomSheet(context, cart),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${cart.items.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const Text('Ver Carrito', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(_currencyFormat.format(cart.totalCart), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
