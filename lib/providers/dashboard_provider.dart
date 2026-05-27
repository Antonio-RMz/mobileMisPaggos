import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';

class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _totalPorCobrar = 0.0;
  double _ventasDelMes = 0.0;
  List<Cliente> _topMorosos = [];
  bool _isLoading = false;

  double get totalPorCobrar => _totalPorCobrar;
  double get ventasDelMes => _ventasDelMes;
  List<Cliente> get topMorosos => _topMorosos;
  bool get isLoading => _isLoading;

  Future<void> cargarMetricas() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Cuentas por cobrar (sumando deudas > 0)
      final clientesSnapshot = await _firestore
          .collection('clientes')
          .get();

      double totalDeuda = 0.0;
      List<Cliente> clientesMorosos = [];
      
      for (var doc in clientesSnapshot.docs) {
        final cliente = Cliente.fromMap(doc.id, doc.data());
        if (cliente.deudaTotal > 0) {
          totalDeuda += cliente.deudaTotal;
          clientesMorosos.add(cliente);
        }
      }
      
      _totalPorCobrar = totalDeuda;

      // Ordenar por deuda descendente y tomar top 5
      clientesMorosos.sort((a, b) => b.deudaTotal.compareTo(a.deudaTotal));
      _topMorosos = clientesMorosos.take(5).toList();

      // 2. Ventas del Mes
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final finMes = DateTime(ahora.year, ahora.month + 1, 0, 23, 59, 59);

      final ticketsSnapshot = await _firestore
          .collection('tickets')
          .where('fecha', isGreaterThanOrEqualTo: inicioMes)
          .where('fecha', isLessThanOrEqualTo: finMes)
          .get();

      double totalVentasMes = 0.0;
      for (var doc in ticketsSnapshot.docs) {
        final ticket = Ticket.fromMap(doc.id, doc.data());
        totalVentasMes += ticket.totalVenta;
      }

      _ventasDelMes = totalVentasMes;

    } catch (e) {
      debugPrint('Error cargando métricas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
