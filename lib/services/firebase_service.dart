import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/producto_model.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../models/gasto_model.dart';
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
  final CollectionReference _gastosCollection = 
      FirebaseFirestore.instance.collection('gastos');

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

  /// Método para obtener un stream del cliente en tiempo real por su ID
  Stream<Cliente> streamCliente(String clienteId) {
    return _clientesCollection.doc(clienteId).snapshots().map((doc) {
      return Cliente.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    });
  }

  /// Método para obtener un cliente por su ID
  Future<Cliente?> getClienteById(String id) async {
    try {
      DocumentSnapshot doc;
      try {
        doc = await _clientesCollection.doc(id).get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await _clientesCollection.doc(id).get(const GetOptions(source: Source.cache));
      }
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

  /// Método para sincronizar/corregir la deuda total del cliente en Firestore
  Future<void> sincronizarDeudaCliente(String clienteId, double trueDebt) async {
    try {
      await _clientesCollection.doc(clienteId).update({
        'deuda_total': trueDebt,
        'updateAt': Timestamp.now(),
        'updateBy': 'Sistema (Auto-Sync)',
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      print('Error en sincronizarDeudaCliente: $e');
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

        // 3. Actualizar la Deuda Total del Cliente si se creó como Con Deuda (Venta Local a Crédito)
        if (ticket.estado == 'Con Deuda' && clienteDoc != null && clienteDoc.exists && ticket.clienteId != 'GNR001') {
          transaction.update(_clientesCollection.doc(ticket.clienteId), {
            'deuda_total': FieldValue.increment(saldoNuevo),
            'updateAt': Timestamp.now()
          });
        }
      }).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await _procesarVentaOffline(ticket);
    } catch (e) {
      print('Error en procesarVenta: $e, intentando modo offline...');
      await _procesarVentaOffline(ticket);
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

      // 3. Actualizar la Deuda Total del Cliente si se creó como Con Deuda (Venta Local a Crédito)
      if (ticket.estado == 'Con Deuda' && ticket.saldoRestante > 0 && ticket.clienteId.isNotEmpty && ticket.clienteId != 'GNR001') {
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

  /// Transfiere la deuda de un ticket al cliente (se envía a Atención Prioritaria)
  Future<void> marcarTicketComoDeudaCliente(Ticket ticket) async {
    if (ticket.saldoRestante <= 0 || ticket.deudaManualAsignada) return;

    final batch = FirebaseFirestore.instance.batch();

    ticket.estado = 'Con Deuda';
    ticket.deudaManualAsignada = true;
    ticket.pagoRepartidorConfirmado = true; // Liberar al repartidor
    ticket.updateAt = Timestamp.now();
    ticket.updateBy = 'Sistema';

    batch.update(_ticketsCollection.doc(ticket.id), {
      'estado': ticket.estado,
      'deudaManualAsignada': ticket.deudaManualAsignada,
      'pagoRepartidorConfirmado': ticket.pagoRepartidorConfirmado,
      'updateAt': ticket.updateAt,
      'updateBy': ticket.updateBy,
    });

    if (ticket.clienteId.isNotEmpty && ticket.clienteId != 'GNR001') {
      batch.update(_clientesCollection.doc(ticket.clienteId), {
        'deuda_total': FieldValue.increment(ticket.saldoRestante),
        'updateAt': Timestamp.now(),
      });
    }

    await batch.commit();
  }

  /// Cancela un ticket y revierte la deuda si aplica
  Future<void> marcarTicketComoTransferencia(Ticket ticket) async {
    if (ticket.saldoRestante <= 0) return; // Ya esta pagado
    
    final batch = FirebaseFirestore.instance.batch();

    double deudaActual = ticket.saldoRestante;
    ticket.metodoPago = 'Transferencia';
    ticket.pagoRepartidorConfirmado = true;
    ticket.totalAbonado = ticket.totalVenta;
    ticket.estado = 'Pagado';
    ticket.updateAt = Timestamp.now();

    final ticketRef = _ticketsCollection.doc(ticket.id);
    batch.update(ticketRef, ticket.toMap());

    // Abono para el cliente
    final abonoId = _abonosCollection.doc().id;
    final abono = Abono(
      id: abonoId,
      clienteId: ticket.clienteId,
      ticketId: ticket.id,
      monto: deudaActual,
      repartidorId: ticket.repartidorId,
      empresaId: empresaId,
      createAt: Timestamp.now(),
      fecha: Timestamp.now(),
      createBy: 'Sistema',
    );
    batch.set(_abonosCollection.doc(abonoId), abono.toMap());
    
    // Abono de conciliación para cuadrar deuda del cliente
    if (ticket.estado == 'Con Deuda' && ticket.clienteId != 'GNR001') {
      final clienteRef = _clientesCollection.doc(ticket.clienteId);
      batch.update(clienteRef, {'deuda_total': FieldValue.increment(-deudaActual)});
    }

    try {
      await batch.commit().timeout(const Duration(seconds: 5));
    } catch (e) {
      throw Exception('Error al liquidar por transferencia: $e');
    }
  }

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

        if (clienteDoc != null && clienteDoc.exists && ticket.estado == 'Con Deuda') {
          transaction.update(clienteRef, {
            'deuda_total': FieldValue.increment(-ticket.saldoRestante),
            'updateAt': Timestamp.now()
          });
        }
      }).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await _cancelarTicketOffline(ticket, motivo);
    } catch (e) {
      print('Error cancelando ticket: $e, intentando modo offline...');
      await _cancelarTicketOffline(ticket, motivo);
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

    if (ticket.saldoRestante > 0 && ticket.clienteId.isNotEmpty && ticket.estado == 'Con Deuda') {
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

          if (clienteDoc != null && clienteDoc.exists && ticket.estado == 'Con Deuda') {
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
      print('Error confirmando pago repartidor: $e, intentando modo offline...');
      await _confirmarPagoRepartidorOffline(ticket, metodoPago: metodoPago, cobradoPor: cobradoPor);
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

      if (ticket.clienteId.isNotEmpty && ticket.estado == 'Con Deuda') {
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

    // 2. Traer tickets del cliente (sin filtro de estado para evitar errores de índice y offline caching)
    QuerySnapshot snapshotTickets;
    try {
      snapshotTickets = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('clienteId', isEqualTo: clienteId)
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (_) {
      snapshotTickets = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('clienteId', isEqualTo: clienteId)
          .get(const GetOptions(source: Source.cache));
    }

    final ticketsList = snapshotTickets.docs.map((doc) {
      return Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).where((t) => t.estado == 'Con Deuda' && t.saldoRestante > 0).toList();

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
      DocumentSnapshot doc;
      try {
        doc = await clienteRef.get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await clienteRef.get(const GetOptions(source: Source.cache));
      }
      if (doc.exists) {
        batch.update(clienteRef, {
          'deuda_total': FieldValue.increment(-montoAbono),
          'updateAt': Timestamp.now(),
        });
      }
    }

    // 5. Commit de toda la transacción
    try {
      await batch.commit().timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // Se encola localmente, es normal en offline
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

    final bool estabaConDeuda = ticket.estado == 'Con Deuda';
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

    // 3. Descontar la deuda total del cliente (solo si el ticket estaba registrado con deuda)
    if (clienteId.isNotEmpty && estabaConDeuda) {
      final double montoRealDescontado = (montoAbono > saldoAnterior) ? saldoAnterior : montoAbono;
      final clienteRef = _clientesCollection.doc(clienteId);
      DocumentSnapshot doc;
      try {
        doc = await clienteRef.get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await clienteRef.get(const GetOptions(source: Source.cache));
      }
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
      DocumentSnapshot doc;
      try {
        doc = await clienteRef.get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await clienteRef.get(const GetOptions(source: Source.cache));
      }
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
      DocumentSnapshot doc;
      try {
        doc = await clienteRef.get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await clienteRef.get(const GetOptions(source: Source.cache));
      }
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

  Future<void> registrarAbonoRepartidor(String repartidorNombre, double monto, {List<String>? ticketIdsToPay}) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // Obtener los tickets del repartidor que deba a caja
    QuerySnapshot ticketsSnapshot;
    try {
      ticketsSnapshot = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (_) {
      ticketsSnapshot = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .get(const GetOptions(source: Source.cache));
    }

    var tickets = ticketsSnapshot.docs
        .map((d) => Ticket.fromMap(d.id, d.data() as Map<String, dynamic>))
        .where((t) {
          bool esMismoRepartidor = t.repartidorNombre?.trim().toLowerCase() == repartidorNombre.trim().toLowerCase();
          bool esPendiente = t.estadoEntrega != 'Cancelado' && !t.pagoRepartidorConfirmado && t.saldoRestante > 0;
          return esMismoRepartidor && esPendiente;
        })
        .toList();

    if (ticketIdsToPay != null && ticketIdsToPay.isNotEmpty) {
      tickets = tickets.where((t) => ticketIdsToPay.contains(t.id)).toList();
    }

    // Ordenar por fecha (los más antiguos primero)
    tickets.sort((a, b) => (a.fecha ?? Timestamp.now()).compareTo(b.fecha ?? Timestamp.now()));

    double abonoRestante = monto;

    for (var t in tickets) {
      if (abonoRestante <= 0) break;

      if (t.formaVenta == 'Crédito') {
        if (!t.pagoRepartidorConfirmado) {
          double loQueFaltaEntregar = t.totalAbonado;
          if (abonoRestante >= loQueFaltaEntregar) {
            abonoRestante -= loQueFaltaEntregar;
            t.pagoRepartidorConfirmado = true;
          } else {
            abonoRestante = 0;
          }
          batch.update(_ticketsCollection.doc(t.id), {
            'pagoRepartidorConfirmado': t.pagoRepartidorConfirmado,
            'updateAt': Timestamp.now()
          });
        }
        continue;
      }

      double abonarAlTicket = 0;
      if (abonoRestante >= t.saldoRestante) {
        abonarAlTicket = t.saldoRestante;
        abonoRestante -= t.saldoRestante;
      } else {
        abonarAlTicket = abonoRestante;
        abonoRestante = 0;
      }

      final bool estabaConDeuda = t.estado == 'Con Deuda';
      t.totalAbonado += abonarAlTicket;
      
      if (t.saldoRestante <= 0) {
        t.estado = 'Pagado';
        t.pagoRepartidorConfirmado = true;
      }

      batch.update(_ticketsCollection.doc(t.id), t.toMap());

      // Reducir la deuda del cliente si aplica (solo si el ticket estaba registrado con deuda)
      if (abonarAlTicket > 0 && t.clienteId.isNotEmpty && estabaConDeuda) {
         batch.update(_clientesCollection.doc(t.clienteId), {
           'deuda_total': FieldValue.increment(-abonarAlTicket)
         });

         // Crear el registro del abono para el cliente para que aparezca en el estado de cuenta (PDF)
         final abonoClienteId = _abonosCollection.doc().id;
         final abonoCliente = Abono(
           id: abonoClienteId,
           clienteId: t.clienteId,
           ticketId: t.id,
           monto: abonarAlTicket,
           repartidorId: repartidorNombre,
           empresaId: empresaId,
           createAt: Timestamp.now(),
           fecha: Timestamp.now(),
           createBy: 'Repartidor',
         );
         batch.set(_abonosCollection.doc(abonoClienteId), abonoCliente.toMap());
      }
    }
    
    // Crear el registro del abono en el historial para auditoría
    final abonoId = _abonosCollection.doc().id;
    final abono = Abono(
      id: abonoId,
      clienteId: '', // No asociado a un solo cliente
      ticketId: 'ENTREGA_REPARTIDOR', // Esto es solo un log, no se suma doble en caja
      monto: monto,
      repartidorId: repartidorNombre,
      empresaId: empresaId,
      createAt: Timestamp.now(),
      fecha: Timestamp.now(),
      createBy: 'Sistema',
    );
    batch.set(_abonosCollection.doc(abonoId), abono.toMap());
    
    // Si sobró dinero que no pudo asignarse a un ticket, lo dejamos flotando como abono general
    if (abonoRestante > 0) {
      final abonoSobranteId = _abonosCollection.doc().id;
      final abonoSobrante = Abono(
        id: abonoSobranteId,
        clienteId: '',
        ticketId: 'ENTREGA_GENERAL',
        monto: abonoRestante,
        repartidorId: repartidorNombre,
        empresaId: empresaId,
        createAt: Timestamp.now(),
        fecha: Timestamp.now(),
        createBy: 'Sistema',
      );
      batch.set(_abonosCollection.doc(abonoSobranteId), abonoSobrante.toMap());
    }
    
    try {
      await batch.commit().timeout(const Duration(seconds: 5));
    } catch (e) {
      throw Exception('No se pudo procesar la entrega: $e');
    }
  }

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
  // GASTOS / EGRESOS
  // =========================================================================

  Future<void> registrarGasto(
    String concepto,
    double monto, {
    String? repartidorId,
    String? repartidorNombre,
    String? tipoGasto = 'General',
    bool esDeCaja = true,
  }) async {
    final gasto = Gasto(
      empresaId: empresaId,
      concepto: concepto,
      monto: monto,
      createBy: 'Cajero',
      repartidorId: repartidorId,
      repartidorNombre: repartidorNombre,
      tipoGasto: tipoGasto,
      esDeCaja: esDeCaja,
    );
    await _gastosCollection.add(gasto.toMap());
  }

  Stream<List<Gasto>> getGastosByDateRange(DateTime start, DateTime end) {
    return _gastosCollection
        .where('empresaId', isEqualTo: empresaId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Gasto.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((g) {
            if (g.fecha == null) return false;
            final date = g.fecha!.toDate();
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

  /// Obtiene todos los tickets que tienen deuda (usado para el Reporte de Deudores)
  Future<List<Ticket>> getAllTicketsConDeudaFuture() async {
    QuerySnapshot snapshot;
    try {
      snapshot = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('estado', isEqualTo: 'Con Deuda')
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (_) {
      snapshot = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('estado', isEqualTo: 'Con Deuda')
          .get(const GetOptions(source: Source.cache));
    }
    return snapshot.docs
        .map((doc) => Ticket.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .where((t) => t.saldoRestante > 0)
        .toList();
  }

  /// Obtiene todos los abonos para cruzar información en el Reporte de Deudores
  Future<List<Abono>> getAllAbonosFuture() async {
    QuerySnapshot snapshot;
    try {
      snapshot = await _abonosCollection
          .where('empresaId', isEqualTo: empresaId)
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (_) {
      snapshot = await _abonosCollection
          .where('empresaId', isEqualTo: empresaId)
          .get(const GetOptions(source: Source.cache));
    }
    return snapshot.docs
        .map((doc) => Abono.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Recalcula la deuda total real de un cliente y la actualiza en Firestore
  Future<void> recalcularDeudaCliente(String clienteId) async {
    if (clienteId.isEmpty || clienteId == 'GNR001') return;

    try {
      // 1. Obtener todos los tickets del cliente
      final ticketsSnapshot = await _ticketsCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('clienteId', isEqualTo: clienteId)
          .get();

      final tickets = ticketsSnapshot.docs
          .map((d) => Ticket.fromMap(d.id, d.data() as Map<String, dynamic>))
          .where((t) => t.estadoEntrega != 'Cancelado')
          .toList();

      // 2. Obtener todos los abonos del cliente
      final abonosSnapshot = await _abonosCollection
          .where('empresaId', isEqualTo: empresaId)
          .where('clienteId', isEqualTo: clienteId)
          .get();

      final abonos = abonosSnapshot.docs
          .map((d) => Abono.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();

      // 3. Calcular la deuda real
      double totalVentaDeuda = 0;
      final Set<String> debtTicketIds = {};
      for (var t in tickets) {
        if (t.formaVenta == 'Crédito' || t.estado == 'Con Deuda' || t.deudaManualAsignada) {
          totalVentaDeuda += t.totalVenta;
          debtTicketIds.add(t.id);
        }
      }

      double totalAbonadoDeuda = 0;
      for (var a in abonos) {
        if (a.ticketId == null || a.ticketId!.isEmpty) {
          totalAbonadoDeuda += a.monto;
        } else {
          // Solo sumamos abonos asociados a tickets que generen deuda para el cliente
          if (debtTicketIds.contains(a.ticketId)) {
            totalAbonadoDeuda += a.monto;
          }
        }
      }

      double deudaReal = totalVentaDeuda - totalAbonadoDeuda;
      deudaReal = double.parse(deudaReal.toStringAsFixed(2)); // Evitar problemas de precisión de punto flotante

      // 4. Actualizar en Firestore
      await _clientesCollection.doc(clienteId).update({
        'deuda_total': deudaReal,
        'updateAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error en recalcularDeudaCliente: $e');
    }
  }
}
