import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/producto_model.dart';
import '../models/ticket_model.dart';
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

  Future<void> _mostrarDialogoPeso(BuildContext context, CartProvider cart, Producto producto, {double cantidadActual = 0.0}) async {
    final TextEditingController pesoCtrl = TextEditingController(text: cantidadActual > 0 ? cantidadActual.toString() : '');
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ingresar Peso - ${producto.nombre}'),
          content: TextField(
            controller: pesoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Peso en Kilos (ej. 1.5)',
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final double peso = double.tryParse(pesoCtrl.text) ?? 0.0;
                if (peso > 0) {
                  if (cantidadActual > 0) {
                    cart.updateQuantity(producto.id, peso);
                  } else {
                    cart.addItem(producto, cantidad: peso);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCobro(BuildContext context, CartProvider cart) {
    if (cart.items.isEmpty) return;

    final TextEditingController abonoCtrl = TextEditingController();
    bool todoACredito = false;

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
            final double total = cart.totalCart;
            final double abonoIngresado = double.tryParse(abonoCtrl.text) ?? 0.0;
            final double restante = total - abonoIngresado;

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
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Total Venta:', style: TextStyle(fontSize: 16)),
                          Text(_currencyFormat.format(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Opciones de Pago
                  CheckboxListTile(
                    title: const Text('Todo a Crédito (Sin Abono)'),
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
                        labelText: 'Monto a Abonar',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (abonoIngresado > 0)
                      Text(
                        restante > 0 
                          ? 'Saldo Restante: ${_currencyFormat.format(restante)}' 
                          : 'Se liquidará por completo.',
                        style: TextStyle(
                          color: restante > 0 ? Colors.orange[800] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () async {
                      final double abonoFinal = todoACredito ? 0.0 : (double.tryParse(abonoCtrl.text) ?? 0.0);
                      
                      if (abonoFinal > total) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El abono no puede superar el total')));
                        return;
                      }

                      // Armar Ticket
                      final ticket = Ticket(
                        clienteId: widget.cliente.id,
                        clienteNombre: '${widget.cliente.nombre} ${widget.cliente.apPaterno}',
                        productos: cart.items.map((i) {
                          return TicketItem(
                            productoId: i.producto.id,
                            codigo: i.producto.codigo,
                            nombre: i.producto.nombre,
                            cantidad: i.cantidad,
                            precioUnitario: i.producto.precio,
                          );
                        }).toList(),
                        totalVenta: total,
                        totalAbonado: abonoFinal,
                        estado: (total - abonoFinal) <= 0 ? 'Pagado' : 'Con Deuda',
                      );

                      // Mostrar Loading
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      try {
                        await _firebaseService.procesarVenta(ticket);
                        if (mounted) {
                          Navigator.pop(context); // Cierra loading
                          Navigator.pop(context); // Cierra modal
                          cart.clearCart();
                          // No cerramos la lista de clientes aún, vamos a la pantalla de éxito
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentSuccessScreen(
                                ticket: ticket,
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
                                      const SizedBox(height: 4),
                                      Text('${_currencyFormat.format(item.producto.precio)} c/u', style: const TextStyle(color: AppTheme.textLight, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (item.producto.categoria != 'Carnes') ...[
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                                        onPressed: () => cart.updateQuantity(item.producto.id, item.cantidad - 1),
                                      ),
                                      Text('${item.cantidad.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.success),
                                        onPressed: () => cart.updateQuantity(item.producto.id, item.cantidad + 1),
                                      ),
                                    ] else ...[
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _mostrarDialogoPeso(context, cart, item.producto, cantidadActual: item.cantidad);
                                        },
                                        icon: const Icon(Icons.scale, size: 18, color: AppTheme.primary),
                                        label: Text('${item.cantidad.toStringAsFixed(3)} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                        onPressed: () {
                                          cart.removeItem(item.producto.id);
                                          if (cart.items.isEmpty) Navigator.pop(context);
                                        },
                                      ),
                                    ]
                                  ],
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    _currencyFormat.format(item.subtotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                                  ),
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
        return Icons.set_meal_outlined; // Pescado/carne
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nueva Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            Text('${widget.cliente.nombre} ${widget.cliente.apPaterno}', style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
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
              stream: _firebaseService.getProductosStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var productos = snapshot.data!;
                if (_searchQuery.isNotEmpty) {
                  productos = productos.where((p) => p.nombre.toLowerCase().contains(_searchQuery) || p.codigo.toLowerCase().contains(_searchQuery)).toList();
                } else {
                  productos = productos.toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
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
                          if (p.categoria == 'Carnes') {
                            _mostrarDialogoPeso(context, cart, p);
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
                                  color: AppTheme.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_getCategoryIcon(p.categoria), color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                    const SizedBox(height: 4),
                                    Text(p.categoria, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currencyFormat.format(p.precio), 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent)
                                  ),
                                  if (p.categoria == 'Carnes')
                                    const Text('por kg', style: TextStyle(fontSize: 10, color: AppTheme.textLight)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add, color: AppTheme.success, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
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
    );
  }
}
