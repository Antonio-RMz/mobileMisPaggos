import 'package:flutter/foundation.dart';
import '../models/producto_model.dart';

class CartItem {
  final String id;
  final Producto producto;
  double cantidad;
  bool isDomicilio;
  double precioUnitario;
  String unidadVenta;
  String observaciones;

  CartItem({
    required this.id,
    required this.producto, 
    this.cantidad = 1.0, 
    this.isDomicilio = false,
    double? precioUnitario,
    String? unidadVenta,
    this.observaciones = '',
  }) : 
    this.precioUnitario = precioUnitario ?? producto.precio,
    this.unidadVenta = unidadVenta ?? producto.unidadVenta;

  double get subtotal => precioUnitario * cantidad;
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalCart => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(Producto producto, {double cantidad = 1.0, double? precioUnitario, String? unidadVenta, String observaciones = ''}) {
    // Agrupar solo si no hay observaciones y es una unidad contable
    bool canGroup = observaciones.isEmpty && (unidadVenta == 'pieza' || unidadVenta == 'paquete' || (unidadVenta == null && (producto.unidadVenta == 'pieza' || producto.unidadVenta == 'paquete')));
    
    if (canGroup) {
      final index = _items.indexWhere((item) => item.producto.id == producto.id && item.observaciones.isEmpty);
      if (index >= 0) {
        _items[index].cantidad += cantidad;
        if (precioUnitario != null) _items[index].precioUnitario = precioUnitario;
        if (unidadVenta != null) _items[index].unidadVenta = unidadVenta;
        notifyListeners();
        return;
      }
    }
    
    _items.add(CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + producto.id,
      producto: producto, 
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      unidadVenta: unidadVenta,
      observaciones: observaciones,
    ));
    notifyListeners();
  }

  void updateQuantity(String cartItemId, double newQuantity, {double? precioUnitario, String? unidadVenta, String? observaciones}) {
    if (newQuantity <= 0) {
      removeItem(cartItemId);
      return;
    }
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      _items[index].cantidad = newQuantity;
      if (precioUnitario != null) _items[index].precioUnitario = precioUnitario;
      if (unidadVenta != null) _items[index].unidadVenta = unidadVenta;
      if (observaciones != null) _items[index].observaciones = observaciones;
      notifyListeners();
    }
  }

  void removeItem(String cartItemId) {
    _items.removeWhere((item) => item.id == cartItemId);
    notifyListeners();
  }

  void toggleDomicilio(String cartItemId, bool isDomicilio) {
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      _items[index].isDomicilio = isDomicilio;
      notifyListeners();
    }
  }

  void setAllDomicilio(bool isDomicilio) {
    for (var item in _items) {
      item.isDomicilio = isDomicilio;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
