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

  final String empresaId;

  FirebaseService({required this.empresaId});

  // =========================================================================
  // CLIENTES
  // =========================================================================

  /// Método para insertar un nuevo cliente en Firestore (Create)
  Future<void> addCliente(Cliente cliente) async {
    cliente.empresaId = empresaId;
    cliente.createAt = Timestamp.now();
    cliente.updateAt = Timestamp.now();
    cliente.createBy = 'Sistema'; // Aquí iría el ID del usuario logueado
    cliente.updateBy = 'Sistema';
    
    final docRef = _clientesCollection.doc();
    cliente.id = docRef.id;
    
    try {
      await docRef.set(cliente.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente en cache
    } catch (e) {
      if (!e.toString().contains('UNAVAILABLE')) {
        print('Error en addCliente: $e');
      }
    }
  }

  /// Método para leer y obtener la lista de clientes en tiempo real (Read)
  Stream<List<Cliente>> getClientesStream() {
    return _clientesCollection
        .where('empresaId', isEqualTo: empresaId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
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

  /// Método para obtener un cliente por su ID
  Future<Cliente?> getClienteById(String id) async {
    try {
      final doc = await _clientesCollection.doc(id).get();
      if (doc.exists) {
        return Cliente.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error obteniendo cliente: $e');
    }
    return null;
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
    producto.empresaId = empresaId;
    producto.createAt = Timestamp.now();
    producto.updateAt = Timestamp.now();
    producto.createBy = 'Sistema';
    producto.updateBy = 'Sistema';
    
    final docRef = _productosCollection.doc();
    producto.id = docRef.id;
    
    try {
      await docRef.set(producto.toMap()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Se encola localmente
    } catch (e) {
      if (!e.toString().contains('UNAVAILABLE')) {
        print('Error en addProducto: $e');
      }
    }
  }

  Stream<List<Producto>> getProductosStream() {
    return _productosCollection
        .where('empresaId', isEqualTo: empresaId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
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

  Future<String> getSiguienteCodigoCarniceria() async {
    try {
      final snapshot = await _productosCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('seccion', isEqualTo: 'carniceria')
          .get(const GetOptions(source: Source.serverAndCache));
      
      if (snapshot.docs.isEmpty) return 'A001';

      String maxCode = 'A000';
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String code = data['codigo'] ?? '';
        if (code.length == 4 && RegExp(r'^[A-Z][0-9]{3}$').hasMatch(code)) {
          if (code.compareTo(maxCode) > 0) {
            maxCode = code;
          }
        }
      }

      if (maxCode == 'A000') return 'A001';

      String letra = maxCode.substring(0, 1);
      int numero = int.parse(maxCode.substring(1));

      numero++;
      if (numero > 999) {
        letra = String.fromCharCode(letra.codeUnitAt(0) + 1);
        numero = 1;
      }

      return '$letra${numero.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generando código: $e');
      return 'A001';
    }
  }

  Future<String> getSiguienteCodigoCatalogo() async {
    try {
      final snapshot = await _productosCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('seccion', isNotEqualTo: 'carniceria')
          .get(const GetOptions(source: Source.serverAndCache));
      
      if (snapshot.docs.isEmpty) return 'C001';

      String maxCode = 'C000';
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String code = data['codigo'] ?? '';
        if (code.length == 4 && RegExp(r'^[C-Z][0-9]{3}$').hasMatch(code)) {
          if (code.compareTo(maxCode) > 0) {
            maxCode = code;
          }
        }
      }

      if (maxCode == 'C000') return 'C001';

      String letra = maxCode.substring(0, 1);
      int numero = int.parse(maxCode.substring(1));

      numero++;
      if (numero > 999) {
        letra = String.fromCharCode(letra.codeUnitAt(0) + 1);
        numero = 1;
      }

      return '$letra${numero.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generando código: $e');
      return 'C001';
    }
  }

  // =========================================================================
  // VENTAS (POS) Y ABONOS
  // =========================================================================

  Future<void> procesarVenta(Ticket ticket) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Leer documentos necesarios primero
        final counterRef = FirebaseFirestore.instance.collection('metadata').doc('counters');
        final counterDoc = await transaction.get(counterRef);
        
        final double saldoNuevo = ticket.saldoRestante;
        DocumentSnapshot? clienteDoc;
        if (saldoNuevo > 0 && ticket.clienteId.isNotEmpty) {
          clienteDoc = await transaction.get(_clientesCollection.doc(ticket.clienteId));
        }

        // Calcular nuevo folio
        int nextFolioNum = 1;
        if (counterDoc.exists && counterDoc.data() != null && (counterDoc.data() as Map<String, dynamic>).containsKey('ticketFolio')) {
          nextFolioNum = ((counterDoc.data() as Map<String, dynamic>)['ticketFolio'] as int) + 1;
          transaction.update(counterRef, {'ticketFolio': nextFolioNum});
        } else {
          transaction.set(counterRef, {'ticketFolio': nextFolioNum}, SetOptions(merge: true));
        }
        
        ticket.empresaId = empresaId;
        ticket.folio = nextFolioNum.toString().padLeft(6, '0');

        // 1. Guardar el Ticket
        final ticketRef = _ticketsCollection.doc();
        ticket.id = ticketRef.id;
        ticket.fecha = Timestamp.now();
        ticket.createAt = Timestamp.now();
        ticket.updateAt = Timestamp.now();
        transaction.set(ticketRef, ticket.toMap());

        // 2. Si hay abono inicial, guardar el Abono
        if (ticket.totalAbonado > 0) {
          final abonoRef = _abonosCollection.doc();
          final abono = Abono(
            empresaId: empresaId,
            clienteId: ticket.clienteId,
            ticketId: ticketRef.id,
            monto: ticket.totalAbonado,
            fecha: Timestamp.now(),
            createAt: Timestamp.now(),
            updateAt: Timestamp.now(),
          );
          transaction.set(abonoRef, abono.toMap());
        }

        // 3. Actualizar la Deuda Total del Cliente
        if (clienteDoc != null && clienteDoc.exists) {
          transaction.update(_clientesCollection.doc(ticket.clienteId), {
            'deuda_total': FieldValue.increment(saldoNuevo),
            'updateAt': Timestamp.now()
          });
        }
      }).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await _procesarVentaOffline(ticket);
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('failed to get document')) {
        await _procesarVentaOffline(ticket);
      } else {
        print('Error en procesarVenta: $e');
      }
    }
  }

  Future<void> _procesarVentaOffline(Ticket ticket) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Intentar leer el contador desde cache
      int nextFolioNum = 1;
      try {
        final counterRef = FirebaseFirestore.instance.collection('metadata').doc('counters');
        final counterDoc = await counterRef.get(const GetOptions(source: Source.cache));
        if (counterDoc.exists && counterDoc.data() != null && (counterDoc.data() as Map<String, dynamic>).containsKey('ticketFolio')) {
          nextFolioNum = ((counterDoc.data() as Map<String, dynamic>)['ticketFolio'] as int) + 1;
          batch.update(counterRef, {'ticketFolio': nextFolioNum});
        }
      } catch (e) {
        // Ignorar si no hay cache
      }
      
      String folioTemp = 'OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      if (nextFolioNum > 1) {
          folioTemp = nextFolioNum.toString().padLeft(6, '0');
      }
      ticket.empresaId = empresaId;
      ticket.folio = folioTemp;

      // 1. Guardar el Ticket
      final ticketRef = _ticketsCollection.doc();
      ticket.id = ticketRef.id;
      ticket.fecha = Timestamp.now();
      ticket.createAt = Timestamp.now();
      ticket.updateAt = Timestamp.now();
      batch.set(ticketRef, ticket.toMap());

      // 2. Si hay abono inicial, guardar el Abono
      if (ticket.totalAbonado > 0) {
        final abonoRef = _abonosCollection.doc();
        final abono = Abono(
          empresaId: empresaId,
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
      if (ticket.saldoRestante > 0 && ticket.clienteId.isNotEmpty) {
        batch.update(_clientesCollection.doc(ticket.clienteId), {
          'deuda_total': FieldValue.increment(ticket.saldoRestante),
          'updateAt': Timestamp.now()
        });
      }

      // Ejecutamos en fire-and-forget para que Firestore lo guarde en cache y regresemos control a la UI
      batch.commit().catchError((e) => print('Error commit offline: $e'));
    } catch (e) {
      print('Error en _procesarVentaOffline: $e');
    }
  }

  /// Cancela un ticket y revierte la deuda si aplica
  Future<void> cancelarTicket(Ticket ticket, String motivo) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot? clienteDoc;
        final clienteRef = _clientesCollection.doc(ticket.clienteId);

        // 1. LECTURAS (Deben ir antes de las escrituras)
        if (ticket.saldoRestante > 0 && ticket.clienteId.isNotEmpty) {
          clienteDoc = await transaction.get(clienteRef);
        }

        // 2. ESCRITURAS
        final ticketRef = _ticketsCollection.doc(ticket.id);
        transaction.update(ticketRef, {
          'estadoEntrega': 'Cancelado',
          'motivoCancelacion': motivo,
          'updateAt': Timestamp.now()
        });

        if (clienteDoc != null && clienteDoc.exists) {
          transaction.update(clienteRef, {
            'deuda_total': FieldValue.increment(-ticket.saldoRestante),
            'updateAt': Timestamp.now()
          });
        }
      }).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await _cancelarTicketOffline(ticket, motivo);
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('failed to get document')) {
        await _cancelarTicketOffline(ticket, motivo);
      } else {
        print('Error cancelando ticket: $e');
        rethrow;
      }
    }
  }

  Future<void> _cancelarTicketOffline(Ticket ticket, String motivo) async {
    final batch = FirebaseFirestore.instance.batch();
    
    final ticketRef = _ticketsCollection.doc(ticket.id);
    batch.update(ticketRef, {
      'estadoEntrega': 'Cancelado',
      'motivoCancelacion': motivo,
      'updateAt': Timestamp.now()
    });

    if (ticket.saldoRestante > 0 && ticket.clienteId.isNotEmpty) {
      final clienteRef = _clientesCollection.doc(ticket.clienteId);
      batch.update(clienteRef, {
        'deuda_total': FieldValue.increment(-ticket.saldoRestante),
        'updateAt': Timestamp.now()
      });
    }

    batch.commit().catchError((e) => print('Error _cancelarTicketOffline: $e'));
  }

  /// Confirma que el repartidor entregó el dinero
  Future<void> confirmarPagoRepartidor(Ticket ticket, {String metodoPago = 'Efectivo', String? cobradoPor}) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot? clienteDoc;
        final clienteRef = _clientesCollection.doc(ticket.clienteId);

        // 1. LECTURAS
        if (ticket.saldoRestante > 0 && ticket.clienteId.isNotEmpty) {
          clienteDoc = await transaction.get(clienteRef);
        }

        // 2. ESCRITURAS
        final ticketRef = _ticketsCollection.doc(ticket.id);
        
        transaction.update(ticketRef, {
          'pagoRepartidorConfirmado': true,
          'metodoPago': metodoPago,
          'cobradoPor': cobradoPor,
          'totalAbonado': ticket.totalVenta,
          'estadoEntrega': 'Entregado',
          'estado': 'Pagado',
          'updateAt': Timestamp.now()
        });

        if (ticket.saldoRestante > 0) {
          final abonoRef = _abonosCollection.doc();
          final abono = Abono(
            empresaId: empresaId,
            clienteId: ticket.clienteId,
            ticketId: ticket.id,
            monto: ticket.saldoRestante, // El monto que faltaba
            fecha: Timestamp.now(),
            createAt: Timestamp.now(),
            updateAt: Timestamp.now(),
          );
          transaction.set(abonoRef, abono.toMap());

          if (clienteDoc != null && clienteDoc.exists) {
            transaction.update(clienteRef, {
              'deuda_total': FieldValue.increment(-ticket.saldoRestante),
              'updateAt': Timestamp.now()
            });
          }
        }
      }).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await _confirmarPagoRepartidorOffline(ticket, metodoPago: metodoPago, cobradoPor: cobradoPor);
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('failed to get document')) {
        await _confirmarPagoRepartidorOffline(ticket, metodoPago: metodoPago, cobradoPor: cobradoPor);
      } else {
        print('Error confirmando pago repartidor: $e');
        rethrow;
      }
    }
  }

  Future<void> _confirmarPagoRepartidorOffline(Ticket ticket, {String metodoPago = 'Efectivo', String? cobradoPor}) async {
    final batch = FirebaseFirestore.instance.batch();
    
    final ticketRef = _ticketsCollection.doc(ticket.id);
    batch.update(ticketRef, {
      'pagoRepartidorConfirmado': true,
      'metodoPago': metodoPago,
      'cobradoPor': cobradoPor,
      'totalAbonado': ticket.totalVenta,
      'estadoEntrega': 'Entregado',
      'estado': 'Pagado',
      'updateAt': Timestamp.now()
    });

    if (ticket.saldoRestante > 0) {
      final abonoRef = _abonosCollection.doc();
      final abono = Abono(
        empresaId: empresaId,
        clienteId: ticket.clienteId,
        ticketId: ticket.id,
        monto: ticket.saldoRestante,
        fecha: Timestamp.now(),
        createAt: Timestamp.now(),
        updateAt: Timestamp.now(),
      );
      batch.set(abonoRef, abono.toMap());

      if (ticket.clienteId.isNotEmpty) {
        final clienteRef = _clientesCollection.doc(ticket.clienteId);
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(-ticket.saldoRestante),
          'updateAt': Timestamp.now()
        });
      }
    }

    batch.commit().catchError((e) => print('Error _confirmarPagoRepartidorOffline: $e'));
  }

  /// Trae todos los tickets de un cliente, ordenados por fecha descendente
  Stream<List<Ticket>> getTicketsByCliente(String clienteId) {
    return _ticketsCollection
        .where('empresaId', isEqualTo: empresaId)
        .where('clienteId', isEqualTo: clienteId)
        .snapshots(includeMetadataChanges: true)
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
        .where('empresaId', isEqualTo: empresaId)
        .where('clienteId', isEqualTo: clienteId)
        .snapshots(includeMetadataChanges: true)
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
      empresaId: empresaId,
      clienteId: clienteId,
      monto: montoAbono,
      fecha: Timestamp.now(),
      createAt: Timestamp.now(),
      updateAt: Timestamp.now(),
    );
    batch.set(abonoRef, abono.toMap());

    // 2. Traer tickets con deuda y ordenarlos en memoria (ascendente: viejos primero)
    final snapshotTickets = await _ticketsCollection
        .where('empresaId', isEqualTo: empresaId)
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
      empresaId: empresaId,
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
        empresaId: empresaId,
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
        .where('empresaId', isEqualTo: empresaId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((t) {
            if (t.fecha == null) return false;
            final date = t.fecha!.toDate();
            return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end.add(const Duration(seconds: 1)));
          })
          .toList();
      list.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return list;
    });
  }

  /// Trae todos los abonos en un rango de fechas
  Stream<List<Abono>> getAbonosByDateRange(DateTime start, DateTime end) {
    return _abonosCollection
        .where('empresaId', isEqualTo: empresaId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Abono.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((a) {
            if (a.fecha == null) return false;
            final date = a.fecha!.toDate();
            return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end.add(const Duration(seconds: 1)));
          })
          .toList();
      list.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return list;
    });
  }

  // =========================================================================
  // PERSONAL (Empleados / Repartidores)
  // =========================================================================

  Future<String> addPersonal(Personal personal) async {
    personal.empresaId = empresaId;
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
    return _personalCollection
        .where('empresaId', isEqualTo: empresaId)
        .snapshots().map((snapshot) {
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
        .where('empresaId', isEqualTo: empresaId)
        .where('repartidorId', isEqualTo: repartidorId)
        .where('estadoEntrega', isEqualTo: 'Entregado')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((t) {
            if (t.updateAt == null) return false;
            final date = t.updateAt!.toDate();
            return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end.add(const Duration(seconds: 1)));
          })
          .toList();
    });
  }

  /// Consultar los abonos (efectivo cobrado) por un repartidor en un rango de fechas
  Stream<List<Abono>> getAbonosByRepartidor(String repartidorId, DateTime start, DateTime end) {
    return _abonosCollection
        .where('empresaId', isEqualTo: empresaId)
        .where('repartidorId', isEqualTo: repartidorId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Abono.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((a) {
            if (a.fecha == null) return false;
            final date = a.fecha!.toDate();
            return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end.add(const Duration(seconds: 1)));
          })
          .toList();
    });
  }
}
