import 'package:flutter/foundation.dart';
import '../models/producto_model.dart';

class CartItem {
  final Producto producto;
  double cantidad;

  CartItem({required this.producto, this.cantidad = 1.0});

  double get subtotal => producto.precio * cantidad;
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalCart => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(Producto producto, {double cantidad = 1.0}) {
    // Buscar si ya existe
    final index = _items.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) {
      _items[index].cantidad += cantidad;
    } else {
      _items.add(CartItem(producto: producto, cantidad: cantidad));
    }
    notifyListeners();
  }

  void updateQuantity(String productoId, double newQuantity) {
    if (newQuantity <= 0) {
      removeItem(productoId);
      return;
    }
    final index = _items.indexWhere((item) => item.producto.id == productoId);
    if (index >= 0) {
      _items[index].cantidad = newQuantity;
      notifyListeners();
    }
  }

  void removeItem(String productoId) {
    _items.removeWhere((item) => item.producto.id == productoId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
