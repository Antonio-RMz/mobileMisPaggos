import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/producto_model.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../models/personal_model.dart';

/// Servicio para manejar la lógica de la base de datos Firestore
class FirebaseService {
  // Referencia a las colecciones
  final CollectionReference _clientesCollection = 
      FirebaseFirestore.instance.collection('clientes');
  final CollectionReference _productosCollection = 
      FirebaseFirestore.instance.collection('productos');
  final CollectionReference _ticketsCollection = 
      FirebaseFirestore.instance.collection('tickets');
  final CollectionReference _abonosCollection = 
      FirebaseFirestore.instance.collection('abonos');
  final CollectionReference _personalCollection = 
      FirebaseFirestore.instance.collection('personal');

  // =========================================================================
  // CLIENTES
  // =========================================================================

  /// Método para insertar un nuevo cliente en Firestore (Create)
  Future<void> addCliente(Cliente cliente) async {
    cliente.createAt = Timestamp.now();
    cliente.updateAt = Timestamp.now();
    cliente.createBy = 'Sistema'; // Aquí iría el ID del usuario logueado
    cliente.updateBy = 'Sistema';
    
    try {
      await _clientesCollection.add(cliente.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Método para leer y obtener la lista de clientes en tiempo real (Read)
  Stream<List<Cliente>> getClientesStream() {
    return _clientesCollection.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Cliente.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      
      // Ordenar localmente por fecha de creación descendente
      list.sort((a, b) {
        final tA = a.createAt ?? Timestamp.fromMillisecondsSinceEpoch(0);
        final tB = b.createAt ?? Timestamp.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Método para actualizar un cliente existente (Update)
  Future<void> updateCliente(Cliente cliente) async {
    cliente.updateAt = Timestamp.now();
    cliente.updateBy = 'Sistema'; // Aquí iría el ID del usuario logueado
    try {
      await _clientesCollection.doc(cliente.id).update(cliente.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Método para eliminar un cliente (Delete)
  Future<void> deleteCliente(String id) async {
    try {
      await _clientesCollection.doc(id).delete().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  // =========================================================================
  // PRODUCTOS
  // =========================================================================

  Future<void> addProducto(Producto producto) async {
    producto.createAt = Timestamp.now();
    producto.updateAt = Timestamp.now();
    producto.createBy = 'Sistema';
    producto.updateBy = 'Sistema';
    try {
      await _productosCollection.add(producto.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  Stream<List<Producto>> getProductosStream() {
    return _productosCollection.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Producto.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      
      // Ordenar localmente por nombre
      list.sort((a, b) => a.nombre.compareTo(b.nombre));
      return list;
    });
  }

  Future<void> updateProducto(Producto producto) async {
    producto.updateAt = Timestamp.now();
    producto.updateBy = 'Sistema';
    try {
      await _productosCollection.doc(producto.id).update(producto.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  Future<void> deleteProducto(String id) async {
    try {
      await _productosCollection.doc(id).delete().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  // =========================================================================
  // VENTAS (POS) Y ABONOS
  // =========================================================================

  Future<void> procesarVenta(Ticket ticket) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Guardar el Ticket
    final ticketRef = _ticketsCollection.doc();
    ticket.fecha = Timestamp.now();
    ticket.createAt = Timestamp.now();
    ticket.updateAt = Timestamp.now();
    batch.set(ticketRef, ticket.toMap());

    // 2. Si hay abono inicial, guardar el Abono
    if (ticket.totalAbonado > 0) {
      final abonoRef = _abonosCollection.doc();
      final abono = Abono(
        clienteId: ticket.clienteId,
        ticketId: ticketRef.id,
        monto: ticket.totalAbonado,
        fecha: Timestamp.now(),
        createAt: Timestamp.now(),
        updateAt: Timestamp.now(),
      );
      batch.set(abonoRef, abono.toMap());
    }

    // 3. Actualizar la Deuda Total del Cliente
    final double saldoNuevo = ticket.saldoRestante;
    if (saldoNuevo > 0 && ticket.clienteId.isNotEmpty) {
      final clienteRef = _clientesCollection.doc(ticket.clienteId);
      final doc = await clienteRef.get();
      if (doc.exists) {
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(saldoNuevo),
          'updateAt': Timestamp.now()
        });
      }
    }

    try {
      await batch.commit().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Trae todos los tickets de un cliente, ordenados por fecha descendente
  Stream<List<Ticket>> getTicketsByCliente(String clienteId) {
    return _ticketsCollection
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      
      // Ordenar en memoria (descendente: más recientes primero)
      list.sort((a, b) {
        final tA = a.fecha ?? Timestamp.now();
        final tB = b.fecha ?? Timestamp.now();
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Trae todos los abonos de un cliente, ordenados por fecha descendente
  Stream<List<Abono>> getAbonosByCliente(String clienteId) {
    return _abonosCollection
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Abono.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      
      list.sort((a, b) {
        final tA = a.fecha ?? Timestamp.now();
        final tB = b.fecha ?? Timestamp.now();
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Procesa un abono general, distribuyendo el dinero en los tickets más viejos primero
  Future<void> procesarAbonoGeneral(String clienteId, double montoAbono) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Registrar el Abono General
    final abonoRef = _abonosCollection.doc();
    final abono = Abono(
      clienteId: clienteId,
      monto: montoAbono,
      fecha: Timestamp.now(),
      createAt: Timestamp.now(),
      updateAt: Timestamp.now(),
    );
    batch.set(abonoRef, abono.toMap());

    // 2. Traer tickets con deuda y ordenarlos en memoria (ascendente: viejos primero)
    final snapshotTickets = await _ticketsCollection
        .where('clienteId', isEqualTo: clienteId)
        .where('estado', isEqualTo: 'Con Deuda')
        .get();

    final ticketsList = snapshotTickets.docs.map((doc) {
      return Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();

    ticketsList.sort((a, b) {
      final tA = a.fecha ?? Timestamp.now();
      final tB = b.fecha ?? Timestamp.now();
      return tA.compareTo(tB);
    });

    double dineroRestante = montoAbono;

    // 3. Aplicar "cascada" de pagos
    for (var ticket in ticketsList) {
      final double deudaTicket = ticket.saldoRestante;

      double pagoAEsteTicket = 0.0;

      if (dineroRestante >= deudaTicket) {
        // Liquida este ticket
        pagoAEsteTicket = deudaTicket;
        dineroRestante -= deudaTicket;
        
        ticket.totalAbonado += pagoAEsteTicket;
        ticket.estado = 'Pagado';
      } else {
        // Abono parcial a este ticket
        pagoAEsteTicket = dineroRestante;
        ticket.totalAbonado += dineroRestante;
        dineroRestante = 0;
      }

      ticket.updateAt = Timestamp.now();
      
      // Actualizar el documento del ticket en el batch
      batch.update(_ticketsCollection.doc(ticket.id), {
        'totalAbonado': ticket.totalAbonado,
        'saldoRestante': ticket.saldoRestante,
        'estado': ticket.estado,
        'updateAt': ticket.updateAt,
      });
    }

    // 4. Descontar la deuda total del cliente
    if (clienteId.isNotEmpty) {
      final clienteRef = _clientesCollection.doc(clienteId);
      final doc = await clienteRef.get();
      if (doc.exists) {
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(-montoAbono),
          'updateAt': Timestamp.now(),
        });
      }
    }

    // 5. Commit de toda la transacción
    try {
      await batch.commit().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Procesa un abono a un ticket en específico
  Future<void> procesarAbonoEspecifico(String clienteId, Ticket ticket, double montoAbono) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Registrar el Abono
    final abonoRef = _abonosCollection.doc();
    final abono = Abono(
      clienteId: clienteId,
      monto: montoAbono,
      fecha: Timestamp.now(),
      createAt: Timestamp.now(),
      updateAt: Timestamp.now(),
    );
    batch.set(abonoRef, abono.toMap());

    // 2. Actualizar el ticket
    final double saldoAnterior = ticket.saldoRestante;
    double nuevoAbonado = ticket.totalAbonado + montoAbono;
    if (nuevoAbonado >= ticket.totalVenta) {
      nuevoAbonado = ticket.totalVenta; // tope
      ticket.estado = 'Pagado';
    }
    
    ticket.totalAbonado = nuevoAbonado;
    ticket.updateAt = Timestamp.now();

    batch.update(_ticketsCollection.doc(ticket.id), {
      'totalAbonado': ticket.totalAbonado,
      'saldoRestante': ticket.saldoRestante,
      'estado': ticket.estado,
      'updateAt': ticket.updateAt,
    });

    // 3. Descontar la deuda total del cliente
    final double montoRealDescontado = (montoAbono > saldoAnterior) ? saldoAnterior : montoAbono;
    
    if (clienteId.isNotEmpty) {
      final clienteRef = _clientesCollection.doc(clienteId);
      final doc = await clienteRef.get();
      if (doc.exists) {
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(-montoRealDescontado),
          'updateAt': Timestamp.now(),
        });
      }
    }

    // 4. Commit
    try {
      await batch.commit().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Marca un pedido a domicilio como entregado y lo cobra en su totalidad
  Future<void> marcarPedidoEntregado(Ticket ticket) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Actualizar el ticket
    final double saldoAnterior = ticket.saldoRestante;
    
    ticket.estadoEntrega = 'Entregado';
    ticket.totalAbonado = ticket.totalVenta; // Paga todo
    ticket.estado = 'Pagado';
    ticket.updateAt = Timestamp.now();

    batch.update(_ticketsCollection.doc(ticket.id), {
      'estadoEntrega': ticket.estadoEntrega,
      'totalAbonado': ticket.totalAbonado,
      'saldoRestante': ticket.saldoRestante,
      'estado': ticket.estado,
      'updateAt': ticket.updateAt,
    });

    // 2. Registrar el abono completo por parte del repartidor
    if (saldoAnterior > 0) {
      final abonoRef = _abonosCollection.doc();
      final abono = Abono(
        clienteId: ticket.clienteId,
        ticketId: ticket.id,
        repartidorId: ticket.repartidorId, // Guardar el repartidor que hizo el cobro
        monto: saldoAnterior,
        fecha: Timestamp.now(),
        createAt: Timestamp.now(),
        updateAt: Timestamp.now(),
      );
      batch.set(abonoRef, abono.toMap());
    }

    // 3. Descontar la deuda total del cliente
    if (saldoAnterior > 0 && ticket.clienteId.isNotEmpty) {
      final clienteRef = _clientesCollection.doc(ticket.clienteId);
      final doc = await clienteRef.get();
      if (doc.exists) {
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(-saldoAnterior),
          'updateAt': Timestamp.now(),
        });
      }
    }

    // 4. Commit
    try {
      await batch.commit().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Cancela un pedido, revirtiendo la deuda del cliente
  Future<void> cancelarPedido(Ticket ticket, String motivo) async {
    final batch = FirebaseFirestore.instance.batch();

    final double saldoAnterior = ticket.saldoRestante;
    
    ticket.estadoEntrega = 'Cancelado';
    ticket.estado = 'Cancelado';
    ticket.motivoCancelacion = motivo;
    ticket.updateAt = Timestamp.now();

    batch.update(_ticketsCollection.doc(ticket.id), {
      'estadoEntrega': ticket.estadoEntrega,
      'estado': ticket.estado,
      'motivoCancelacion': ticket.motivoCancelacion,
      'updateAt': ticket.updateAt,
    });

    // Descontar la deuda total del cliente ya que el pedido no se concretó
    if (saldoAnterior > 0 && ticket.clienteId.isNotEmpty) {
      final clienteRef = _clientesCollection.doc(ticket.clienteId);
      final doc = await clienteRef.get();
      if (doc.exists) {
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(-saldoAnterior),
          'updateAt': Timestamp.now(),
        });
      }
    }

    try {
      await batch.commit().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  // =========================================================================
  // REPORTES / CORTE DE CAJA
  // =========================================================================

  /// Trae todos los tickets en un rango de fechas
  Stream<List<Ticket>> getTicketsByDateRange(DateTime start, DateTime end) {
    return _ticketsCollection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
      list.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return list;
    });
  }

  /// Trae todos los abonos en un rango de fechas
  Stream<List<Abono>> getAbonosByDateRange(DateTime start, DateTime end) {
    return _abonosCollection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Abono.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
      list.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return list;
    });
  }

  // =========================================================================
  // PERSONAL (Empleados / Repartidores)
  // =========================================================================

  Future<String> addPersonal(Personal personal) async {
    personal.createAt = Timestamp.now();
    final docRef = _personalCollection.doc();
    personal.id = docRef.id;
    
    try {
      await docRef.set(personal.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    } catch (e) {
      // Ignorar para seguir el flujo local
    }
    return docRef.id;
  }

  Stream<List<Personal>> getPersonalStream() {
    return _personalCollection.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Personal.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      
      list.sort((a, b) => a.nombre.compareTo(b.nombre));
      return list;
    });
  }

  Future<void> updatePersonal(Personal personal) async {
    try {
      await _personalCollection.doc(personal.id).update(personal.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  Future<void> deletePersonal(String id) async {
    try {
      await _personalCollection.doc(id).delete().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  // =========================================================================
  // USUARIOS Y ROLES
  // =========================================================================

  Future<void> crearCuentaUsuario({
    required String personalId,
    required String username,
    required String password,
    required String rol,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(personalId).set({
        'username': username,
        'password': password,
        'role': rol.toLowerCase(),
        'repartidorId': personalId,
        'createAt': Timestamp.now(),
      }).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  Future<void> actualizarCuentaUsuario({
    required String personalId,
    required String username,
    required String password,
    required String rol,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(personalId).set({
        'username': username,
        'password': password,
        'role': rol.toLowerCase(),
        'repartidorId': personalId,
        'updateAt': Timestamp.now(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    } catch (e) {
      // Ignorar
    }
  }

  Future<void> eliminarCuentaUsuario(String personalId) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(personalId).delete().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    }
  }

  /// Consultar los tickets que un repartidor ha entregado en un rango de fechas
  Stream<List<Ticket>> getTicketsEntregadosByRepartidor(String repartidorId, DateTime start, DateTime end) {
    return _ticketsCollection
        .where('repartidorId', isEqualTo: repartidorId)
        .where('estadoEntrega', isEqualTo: 'Entregado')
        .where('updateAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('updateAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  /// Consultar los abonos (efectivo cobrado) por un repartidor en un rango de fechas
  Stream<List<Abono>> getAbonosByRepartidor(String repartidorId, DateTime start, DateTime end) {
    return _abonosCollection
        .where('repartidorId', isEqualTo: repartidorId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Abono.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }
}
