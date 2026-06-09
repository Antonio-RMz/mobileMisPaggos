import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/producto_model.dart';
import '../models/ticket_model.dart';
import '../models/personal_model.dart';
import '../services/firebase_service.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'payment_success_screen.dart';

class NuevoPedidoScreen extends StatefulWidget {
  final Cliente? cliente;
  const NuevoPedidoScreen({super.key, this.cliente});

  @override
  State<NuevoPedidoScreen> createState() => _NuevoPedidoScreenState();
}

class _NuevoPedidoScreenState extends State<NuevoPedidoScreen> {
  FirebaseService get _firebaseService => Provider.of<FirebaseService>(context, listen: false);
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  String _searchQuery = '';
  late Stream<List<Producto>> _productosStream;

  @override
  void initState() {
    super.initState();
    _productosStream = _firebaseService.getProductosStream();
  }

  String _removeAccents(String str) {
    var withDia = 'áéíóúÁÉÍÓÚñÑ';
    var withoutDia = 'aeiouAEIOUnN';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  Cliente get _currentCliente => widget.cliente ?? Cliente(
    id: '',
    nombre: 'Público',
    apPaterno: 'en General',
    apMaterno: '',
    celular: '',
    correo: '',
    telefono: '',
    observaciones: '',
  );

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
            double fractionVal = 0.0;
            if (modoVenta.contains('1/4')) fractionVal = 0.25;
            if (modoVenta.contains('1/2')) fractionVal = 0.5;
            if (modoVenta.contains('3/4')) fractionVal = 0.75;

            double cantidadFinal = 0.0;
            double totalCalculado = 0.0;

            if (modoVenta.startsWith('Monto')) {
              cantidadFinal = inputVal / precioKilo;
              totalCalculado = inputVal;
            } else if (modoVenta == 'Gramos') {
              cantidadFinal = inputVal / 1000;
              totalCalculado = cantidadFinal * precioKilo;
            } else if (modoVenta.startsWith('Unidad Base')) {
              cantidadFinal = inputVal + fractionVal;
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
                      value: modoVenta.startsWith('Unidad Base') ? 'Unidad Base' : modoVenta,
                      decoration: const InputDecoration(labelText: 'Modo de Venta', border: OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'Unidad Base', child: Text('Por ${producto.unidadVenta}')),
                        if (producto.unidadVenta == 'kg') ...[
                          const DropdownMenuItem(value: 'Monto (\$)', child: Text('Por Monto (\$)' )),
                          const DropdownMenuItem(value: 'Gramos', child: Text('Por Gramos')),
                          const DropdownMenuItem(value: 'Piezas', child: Text('Por Piezas')),
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
                    if (modoVenta.startsWith('Unidad Base') && producto.unidadVenta == 'kg')
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: inputCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              autofocus: true,
                              onChanged: (v) => setStateDialog((){}),
                              decoration: const InputDecoration(
                                labelText: 'Kilos enteros',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: modoVenta.contains('1/4') ? '1/4' : (modoVenta.contains('1/2') ? '1/2' : (modoVenta.contains('3/4') ? '3/4' : '0')),
                              decoration: const InputDecoration(labelText: 'Fracción', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: '0', child: Text('0', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: '1/4', child: Text('1/4', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: '1/2', child: Text('1/2', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: '3/4', child: Text('3/4', style: TextStyle(fontSize: 14))),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() {
                                    if (val == '0') {
                                      modoVenta = 'Unidad Base';
                                    } else {
                                      modoVenta = 'Unidad Base - $val';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      TextField(
                        controller: inputCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: true,
                        onChanged: (v) => setStateDialog((){}),
                        decoration: InputDecoration(
                          labelText: modoVenta.startsWith('Monto') 
                              ? 'Monto a Cobrar (\$)' 
                              : (modoVenta == 'Gramos' 
                                  ? 'Gramos (g)' 
                                  : (modoVenta == 'Piezas' ? 'Cantidad (piezas)' : 'Cantidad (${producto.unidadVenta})')),
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
                      } else if (modoVenta == 'Piezas' && obsStr.isEmpty) {
                        obsStr = '(Pedido original: ${inputVal.toStringAsFixed(0)} piezas)';
                      } else if (modoVenta == 'Piezas' && obsStr.isNotEmpty) {
                        obsStr = '(Pedido original: ${inputVal.toStringAsFixed(0)} piezas) - $obsStr';
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

  Widget _buildConceptoLibreCard(CartProvider cart, BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarDialogoConceptoLibre(context, cart),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Otro / Concepto Libre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                    SizedBox(height: 4),
                    Text('Agregar un concepto o monto manual', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoConceptoLibre(BuildContext context, CartProvider cart) async {
    final TextEditingController conceptoCtrl = TextEditingController();
    final TextEditingController montoCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Concepto Libre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: conceptoCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Concepto / Nombre', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto a Cobrar (\$)', prefixText: '\$ ', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = conceptoCtrl.text.trim();
                final monto = double.tryParse(montoCtrl.text) ?? 0.0;
                if (nombre.isNotEmpty && monto > 0) {
                  final productoManual = Producto(
                    id: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
                    codigo: 'LIBRE',
                    nombre: nombre,
                    observaciones: 'Concepto libre ingresado manualmente',
                    precio: monto,
                    unidadVenta: 'pieza',
                    categoria: 'Concepto Libre',
                    seccion: 'general',
                    createBy: '',
                    createAt: Timestamp.now(),
                  );
                  cart.addItem(productoManual, cantidad: 1.0, precioUnitario: monto);
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCobro(BuildContext context, CartProvider cart) {
    if (cart.items.isEmpty) return;

    final double totalVenta = cart.totalCart;

    String? repartidorId;
    String? repartidorNombre;
    final String clienteNombreFinal = _currentCliente.id != '' 
        ? '${_currentCliente.nombre} ${_currentCliente.apPaterno}'.trim() 
        : 'Público en General';

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

            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: bottomInset > 0 ? bottomInset + 24 : 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Confirmar Pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  
                  // Resumen
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.backgroundLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        const Text('Total a Cobrar:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_currencyFormat.format(totalVenta), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                      ]
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Resumen de Orden
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Cliente: $clienteNombreFinal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.shopping_basket, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('${cart.items.length} producto(s) en el pedido:', style: const TextStyle(color: AppTheme.textDark)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Listado de productos
                        ...cart.items.map((item) {
                          final bool usaFracciones = item.producto.unidadVenta != 'pieza' && item.producto.unidadVenta != 'paquete';
                          final String qtyText = usaFracciones ? '${item.cantidad.toStringAsFixed(2)} ${item.producto.unidadVenta}' : '${item.cantidad.toInt()}x';
                          
                          String displayStr = '• $qtyText ${item.producto.nombre} - ${_currencyFormat.format(item.subtotal)}';
                          if (item.observaciones.isNotEmpty) {
                             displayStr += '\n    * ${item.observaciones}';
                          }

                          return Padding(
                            padding: const EdgeInsets.only(left: 28, bottom: 6),
                            child: Text(displayStr, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  StreamBuilder<List<Personal>>(
                    stream: _firebaseService.getPersonalStream(),
                    builder: (context, snapshot) {
                      List<Personal> repartidores = [];
                      
                      if (snapshot.hasData) {
                        repartidores = snapshot.data!.where((p) => p.activo).toList();
                      }

                      repartidores.insert(0, Personal(
                        id: 'SUCURSAL',
                        nombre: 'Sucursal (Venta en tienda)',
                        telefono: '',
                        rol: 'Repartidor',
                        activo: true,
                        createAt: Timestamp.now(),
                      ));

                      if (repartidores.isEmpty) {
                        // Si no hay datos o estamos offline sin caché, proveemos un repartidor de rescate
                        repartidores.add(Personal(
                          id: 'REP_TEMP_OFFLINE',
                          nombre: 'Repartidor Temporal (Offline)',
                          telefono: '',
                          rol: 'Repartidor',
                          activo: true,
                          createAt: Timestamp.now(),
                        ));
                      }
                      
                      return DropdownButtonFormField<String>(
                        value: repartidorId,
                        decoration: InputDecoration(
                          labelText: 'Asignar Repartidor',
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
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.accent,
                    ),
                    onPressed: () async {
                      if (repartidorId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor asigna un repartidor.')));
                        return;
                      }

                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar Pedido'),
                          content: const Text('¿Estás seguro de confirmar y guardar este pedido?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent)),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      try {
                        final userName = Provider.of<UserProvider>(context, listen: false).nombre;
                        
                        final ticket = Ticket(
                          clienteId: _currentCliente.id != '' ? _currentCliente.id : 'GNR001',
                          clienteNombre: clienteNombreFinal,
                          tipoEntrega: repartidorId == 'SUCURSAL' ? 'Local' : 'Domicilio',
                          repartidorId: repartidorId,
                          repartidorNombre: repartidorNombre,
                          estadoEntrega: repartidorId == 'SUCURSAL' ? 'Entregado' : 'Pendiente',
                          productos: cart.items.map((i) {
                            return TicketItem(
                              productoId: i.producto.id,
                              codigo: i.producto.codigo,
                              nombre: i.producto.nombre,
                              cantidad: i.cantidad,
                              precioUnitario: i.precioUnitario,
                              observaciones: i.observaciones,
                              unidadVenta: i.producto.unidadVenta,
                              seccion: i.producto.seccion,
                            );
                          }).toList(),
                          totalVenta: totalVenta,
                          totalAbonado: 0.0,
                          estado: 'Con Deuda',
                          createBy: userName,
                        );
                        
                        await _firebaseService.procesarVenta(ticket);

                        if (mounted) {
                          Navigator.pop(context); // Cierra loading
                          Navigator.pop(context); // Cierra modal
                          cart.clearCart();
                          
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentSuccessScreen(
                                ticket: ticket,
                                abonado: 0.0,
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
                    child: const Text('Confirmar Pedido', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
        return Consumer<CartProvider>(
          builder: (context, cartConsumer, child) {
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
                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                        label: const Text('Continuar', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
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

  Widget _buildProductList(CartProvider cart, BuildContext context, List<Producto> allProductos, {required bool isCarniceria}) {
        var productos = List<Producto>.from(allProductos);
        
        // Filtro por sección
        productos = productos.where((p) => isCarniceria ? p.seccion == 'carniceria' : p.seccion != 'carniceria').toList();

        if (_searchQuery.isNotEmpty) {
          final queryNorm = _removeAccents(_searchQuery.toLowerCase().trim());
          productos = productos.where((p) {
            final nombreNorm = _removeAccents(p.nombre.toLowerCase());
            final codigoNorm = _removeAccents(p.codigo.toLowerCase());
            return nombreNorm.contains(queryNorm) || codigoNorm.contains(queryNorm);
          }).toList();
        } else {
          productos.sort((a, b) => a.nombre.compareTo(b.nombre));
        }
        
        if (productos.isEmpty) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildConceptoLibreCard(cart, context),
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No se encontraron productos', style: TextStyle(color: AppTheme.textLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildConceptoLibreCard(cart, context);
            }
            final p = productos[index - 1];
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
                const Text('Nuevo Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                Text(_currentCliente.id != '' ? '${_currentCliente.nombre} ${_currentCliente.apPaterno}' : 'Público en General', style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
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
                child: StreamBuilder<List<Producto>>(
                  stream: _productosStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final productos = snapshot.data!;
                    return TabBarView(
                      children: [
                        _buildProductList(cart, context, productos, isCarniceria: false),
                        _buildProductList(cart, context, productos, isCarniceria: true),
                      ],
                    );
                  }
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
