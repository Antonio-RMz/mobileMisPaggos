import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/producto_model.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';

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
    // Ordenamos por fecha de creación descendente
    return _clientesCollection
        .orderBy('createAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Cliente.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
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
    return _productosCollection
        .orderBy('nombre', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Producto.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
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
    if (saldoNuevo > 0) {
      final clienteRef = _clientesCollection.doc(ticket.clienteId);
      batch.update(clienteRef, {
        'deuda_total': FieldValue.increment(saldoNuevo),
        'updateAt': Timestamp.now()
      });
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
    final clienteRef = _clientesCollection.doc(clienteId);
    batch.update(clienteRef, {
      'deuda_total': FieldValue.increment(-montoAbono),
      'updateAt': Timestamp.now(),
    });

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
    
    final clienteRef = _clientesCollection.doc(clienteId);
    batch.update(clienteRef, {
      'deuda_total': FieldValue.increment(-montoRealDescontado),
      'updateAt': Timestamp.now(),
    });

    // 4. Commit
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
}
