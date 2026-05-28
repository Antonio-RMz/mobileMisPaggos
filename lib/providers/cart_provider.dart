import 'package:flutter/foundation.dart';
import '../models/producto_model.dart';

class CartItem {
  final Producto producto;
  double cantidad;
  bool isDomicilio;
  double precioUnitario;
  String unidadVenta;

  CartItem({
    required this.producto, 
    this.cantidad = 1.0, 
    this.isDomicilio = false,
    double? precioUnitario,
    String? unidadVenta,
  }) : 
    this.precioUnitario = precioUnitario ?? producto.precio,
    this.unidadVenta = unidadVenta ?? producto.unidadVenta;

  double get subtotal => precioUnitario * cantidad;
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalCart => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(Producto producto, {double cantidad = 1.0, double? precioUnitario, String? unidadVenta}) {
    // Buscar si ya existe
    final index = _items.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) {
      _items[index].cantidad += cantidad;
      if (precioUnitario != null) _items[index].precioUnitario = precioUnitario;
      if (unidadVenta != null) _items[index].unidadVenta = unidadVenta;
    } else {
      _items.add(CartItem(
        producto: producto, 
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        unidadVenta: unidadVenta,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(String productoId, double newQuantity, {double? precioUnitario, String? unidadVenta}) {
    if (newQuantity <= 0) {
      removeItem(productoId);
      return;
    }
    final index = _items.indexWhere((item) => item.producto.id == productoId);
    if (index >= 0) {
      _items[index].cantidad = newQuantity;
      if (precioUnitario != null) _items[index].precioUnitario = precioUnitario;
      if (unidadVenta != null) _items[index].unidadVenta = unidadVenta;
      notifyListeners();
    }
  }

  void removeItem(String productoId) {
    _items.removeWhere((item) => item.producto.id == productoId);
    notifyListeners();
  }

  void toggleDomicilio(String productoId, bool isDomicilio) {
    final index = _items.indexWhere((item) => item.producto.id == productoId);
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
