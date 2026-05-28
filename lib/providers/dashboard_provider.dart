import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';

class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _totalPorCobrar = 0.0;
  double _ventasDelMes = 0.0;
  List<Cliente> _topMorosos = [];
  Map<String, double> _topProductosCarnes = {};
  Map<String, double> _topProductosCatalogo = {};
  int _entregasEnReparto = 0;
  int _entregasEnviadas = 0;
  int _entregasCanceladas = 0;
  bool _isLoading = false;

  double get totalPorCobrar => _totalPorCobrar;
  double get ventasDelMes => _ventasDelMes;
  List<Cliente> get topMorosos => _topMorosos;
  Map<String, double> get topProductosCarnes => _topProductosCarnes;
  Map<String, double> get topProductosCatalogo => _topProductosCatalogo;
  int get entregasEnReparto => _entregasEnReparto;
  int get entregasEnviadas => _entregasEnviadas;
  int get entregasCanceladas => _entregasCanceladas;
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

      // Ordenar por deuda descendente (todos los morosos)
      clientesMorosos.sort((a, b) => b.deudaTotal.compareTo(a.deudaTotal));
      _topMorosos = clientesMorosos;

      // 2. Ventas del Mes
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final finMes = DateTime(ahora.year, ahora.month + 1, 0, 23, 59, 59);

      final ticketsSnapshot = await _firestore
          .collection('tickets')
          .where('fecha', isGreaterThanOrEqualTo: inicioMes)
          .where('fecha', isLessThanOrEqualTo: finMes)
          .get();

      // Obtener todos los productos para saber su sección
      final productosSnapshot = await _firestore.collection('productos').get();
      Map<String, String> productoSeccion = {};
      Map<String, String> productoNombre = {};
      for (var doc in productosSnapshot.docs) {
        final data = doc.data();
        productoSeccion[doc.id] = data['seccion'] ?? 'catalogo';
        productoNombre[doc.id] = data['nombre'] ?? '';
      }

      double totalVentasMes = 0.0;
      Map<String, double> contCarnes = {};
      Map<String, double> contCatalogo = {};

      int enReparto = 0;
      int enviadas = 0;
      int canceladas = 0;

      for (var doc in ticketsSnapshot.docs) {
        final ticket = Ticket.fromMap(doc.id, doc.data());
        totalVentasMes += ticket.totalVenta;

        // Conteo de estado de entregas del mes o del día? El cliente pide estado actual.
        // Contemos los del día de hoy para que sea relevante en el dashboard
        final bool esDeHoy = ticket.fecha != null && ticket.fecha!.toDate().day == ahora.day && ticket.fecha!.toDate().month == ahora.month && ticket.fecha!.toDate().year == ahora.year;

        if (esDeHoy && ticket.tipoEntrega == 'Domicilio') {
          if (ticket.estadoEntrega == 'Pendiente') {
            enReparto++;
          } else if (ticket.estadoEntrega == 'Entregado') {
            enviadas++;
          } else if (ticket.estadoEntrega == 'Cancelado') {
            canceladas++;
          }
        }

        // Productos vendidos
        for (var item in ticket.productos) {
          final seccion = productoSeccion[item.productoId] ?? 'catalogo';
          final nombre = productoNombre[item.productoId] ?? item.nombre;
          
          if (seccion == 'carniceria') {
            contCarnes[nombre] = (contCarnes[nombre] ?? 0.0) + item.cantidad;
          } else {
            contCatalogo[nombre] = (contCatalogo[nombre] ?? 0.0) + item.cantidad;
          }
        }
      }

      _ventasDelMes = totalVentasMes;
      _entregasEnReparto = enReparto;
      _entregasEnviadas = enviadas;
      _entregasCanceladas = canceladas;

      // Ordenar productos y tomar top 5
      var listCarnes = contCarnes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topProductosCarnes = Map.fromEntries(listCarnes.take(5));

      var listCatalogo = contCatalogo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topProductosCatalogo = Map.fromEntries(listCatalogo.take(5));

    } catch (e) {
      debugPrint('Error cargando métricas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
