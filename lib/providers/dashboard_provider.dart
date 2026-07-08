import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import 'user_provider.dart';

class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserProvider? _userProvider;

  String? _lastEmpresaId;
  void updateUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    if (_lastEmpresaId != userProvider.empresaId) {
      _lastEmpresaId = userProvider.empresaId;
      if (userProvider.isInitialized) {
        cargarMetricas();
      }
    }
  }

  double _totalPorCobrar = 0.0;
  double _ventasDelMes = 0.0;
  double _ventasDeHoy = 0.0;
  List<Cliente> _topMorosos = [];
  Map<String, double> _topProductosCarnes = {};
  Map<String, double> _topProductosCatalogo = {};
  int _entregasEnReparto = 0;
  int _entregasEnviadas = 0;
  int _entregasCanceladas = 0;
  int _ventasHoyCount = 0;
  List<Ticket> _ticketsDeudaHoy = [];
  Map<String, double> _ventasPorDiaSemana = {};
  bool _isLoading = false;

  double get totalPorCobrar => _totalPorCobrar;
  double get ventasDelMes => _ventasDelMes;
  double get ventasDeHoy => _ventasDeHoy;
  List<Cliente> get topMorosos => _topMorosos;
  Map<String, double> get topProductosCarnes => _topProductosCarnes;
  Map<String, double> get topProductosCatalogo => _topProductosCatalogo;
  int get entregasEnReparto => _entregasEnReparto;
  int get entregasEnviadas => _entregasEnviadas;
  int get entregasCanceladas => _entregasCanceladas;
  int get ventasHoyCount => _ventasHoyCount;
  List<Ticket> get ticketsDeudaHoy => _ticketsDeudaHoy;
  Map<String, double> get ventasPorDiaSemana => _ventasPorDiaSemana;
  bool get isLoading => _isLoading;

  Future<void> cargarMetricas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final empresaId = _userProvider?.empresaId ?? '';

      // 1. Cuentas por cobrar (sumando deudas > 0)
      QuerySnapshot<Map<String, dynamic>> clientesSnapshot;
      try {
        clientesSnapshot = await _firestore
            .collection('clientes')
            .where('empresaId', isEqualTo: empresaId)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        clientesSnapshot = await _firestore
            .collection('clientes')
            .where('empresaId', isEqualTo: empresaId)
            .get(const GetOptions(source: Source.cache));
      }

      double totalDeuda = 0.0;
      List<Cliente> clientesMorosos = [];
      
      for (var doc in clientesSnapshot.docs) {
        final cliente = Cliente.fromMap(doc.id, doc.data());
        if (cliente.deudaTotal > 0) {
          totalDeuda += cliente.deudaTotal;
          clientesMorosos.add(cliente);
        }
      }
      
      // No usamos la suma de clientes para totalPorCobrar, lo calcularemos con los tickets de hoy
      // _totalPorCobrar = totalDeuda;

      // Ordenar por deuda descendente (todos los morosos)
      clientesMorosos.sort((a, b) => b.deudaTotal.compareTo(a.deudaTotal));
      _topMorosos = clientesMorosos;

      // 2. Ventas de la Semana y Deuda de Hoy
      final ahora = DateTime.now();
      final int diasRestar = ahora.weekday - 1;
      final inicioSemana = DateTime(ahora.year, ahora.month, ahora.day).subtract(Duration(days: diasRestar));
      final finSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      QuerySnapshot<Map<String, dynamic>> ticketsSnapshot;
      try {
        ticketsSnapshot = await _firestore
            .collection('tickets')
            .where('empresaId', isEqualTo: empresaId)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        ticketsSnapshot = await _firestore
            .collection('tickets')
            .where('empresaId', isEqualTo: empresaId)
            .get(const GetOptions(source: Source.cache));
      }

      // Obtener todos los productos para saber su sección
      QuerySnapshot<Map<String, dynamic>> productosSnapshot;
      try {
        productosSnapshot = await _firestore
            .collection('productos')
            .where('empresaId', isEqualTo: empresaId)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        productosSnapshot = await _firestore
            .collection('productos')
            .where('empresaId', isEqualTo: empresaId)
            .get(const GetOptions(source: Source.cache));
      }
      Map<String, String> productoSeccion = {};
      Map<String, String> productoNombre = {};
      for (var doc in productosSnapshot.docs) {
        final data = doc.data();
        productoSeccion[doc.id] = data['seccion'] ?? 'catalogo';
        productoNombre[doc.id] = data['nombre'] ?? '';
      }

      double totalVentasMes = 0.0;
      double totalVentasHoy = 0.0;
      Map<String, double> contCarnes = {};
      Map<String, double> contCatalogo = {};
      Map<String, double> ventasPorDia = {
        'Lunes': 0.0, 'Martes': 0.0, 'Miércoles': 0.0, 
        'Jueves': 0.0, 'Viernes': 0.0, 'Sábado': 0.0, 'Domingo': 0.0,
      };

      int enReparto = 0;
      int enviadas = 0;
      int canceladas = 0;
      int ventasHoyCount = 0;

      double totalDeudaHoy = 0.0;
      List<Ticket> ticketsDeudaHoyList = [];

      for (var doc in ticketsSnapshot.docs) {
        final ticket = Ticket.fromMap(doc.id, doc.data());
        
        // Determinar si el ticket es de la semana actual
        final bool esDeLaSemana = ticket.fecha != null && 
            ticket.fecha!.toDate().isAfter(inicioSemana.subtract(const Duration(seconds: 1))) && 
            ticket.fecha!.toDate().isBefore(finSemana.add(const Duration(seconds: 1)));

        // Determinar si es de hoy
        final bool esDeHoy = ticket.fecha != null && ticket.fecha!.toDate().day == ahora.day && ticket.fecha!.toDate().month == ahora.month && ticket.fecha!.toDate().year == ahora.year;

        if (esDeLaSemana && ticket.estadoEntrega != 'Cancelado') {
          totalVentasMes += ticket.totalVenta; // usando misma variable, pero es de la semana
          final date = ticket.fecha!.toDate();
          String dayName = '';
          switch (date.weekday) {
            case 1: dayName = 'Lunes'; break;
            case 2: dayName = 'Martes'; break;
            case 3: dayName = 'Miércoles'; break;
            case 4: dayName = 'Jueves'; break;
            case 5: dayName = 'Viernes'; break;
            case 6: dayName = 'Sábado'; break;
            case 7: dayName = 'Domingo'; break;
          }
          if (dayName.isNotEmpty) {
            ventasPorDia[dayName] = (ventasPorDia[dayName] ?? 0) + ticket.totalVenta;
          }
        }

        if (esDeHoy) {
          if (ticket.estadoEntrega != 'Cancelado') {
            totalVentasHoy += ticket.totalVenta;
            ventasHoyCount++;
          }
          // Deuda generada hoy
          if (ticket.estado != 'Pagado' && ticket.estadoEntrega != 'Cancelado') {
            double saldoRestante = ticket.totalVenta - ticket.totalAbonado;
            if (saldoRestante > 0) {
              totalDeudaHoy += saldoRestante;
              ticketsDeudaHoyList.add(ticket);
            }
          }
          if (ticket.tipoEntrega == 'Domicilio') {
            if (ticket.estadoEntrega == 'Cancelado') {
              canceladas++;
            } else if (ticket.pagoRepartidorConfirmado) {
              enviadas++; // Ahora significa "Completadas"
            } else {
              enReparto++;
            }
          }
          // Productos vendidos hoy
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
      }

      _ventasDelMes = totalVentasMes;
      _ventasDeHoy = totalVentasHoy;
      _totalPorCobrar = totalDeudaHoy;
      _entregasEnReparto = enReparto;
      _entregasEnviadas = enviadas;
      _entregasCanceladas = canceladas;
      _ventasHoyCount = ventasHoyCount;
      _ticketsDeudaHoy = ticketsDeudaHoyList;
      _ventasPorDiaSemana = ventasPorDia;

      // Ordenar productos y tomar top 3
      var listCarnes = contCarnes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topProductosCarnes = Map.fromEntries(listCarnes.take(3));

      var listCatalogo = contCatalogo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topProductosCatalogo = Map.fromEntries(listCatalogo.take(3));

    } catch (e) {
      debugPrint('Error cargando métricas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
