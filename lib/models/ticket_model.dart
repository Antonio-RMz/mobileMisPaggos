import 'package:cloud_firestore/cloud_firestore.dart';

class TicketItem {
  String productoId;
  String codigo;
  String nombre;
  double cantidad;
  double precioUnitario;
  String observaciones;
  String unidadVenta;

  TicketItem({
    required this.productoId,
    this.codigo = '',
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.observaciones = '',
    this.unidadVenta = '',
  });

  double get subtotal => cantidad * precioUnitario;

  String get descripcionAmigable {
    String cantStr = cantidad % 1 == 0 ? cantidad.toInt().toString() : cantidad.toStringAsFixed(3).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    
    if (observaciones.contains('(Cobro:')) {
      final match = RegExp(r'\(Cobro:\s*(\$[^)]+)\)').firstMatch(observaciones);
      if (match != null) {
        String monto = match.group(1)!;
        return '$monto de $nombre';
      }
    }
    
    if (observaciones.contains('(Pedido original:')) {
      final match = RegExp(r'\(Pedido original:\s*([^\)]+)\)').firstMatch(observaciones);
      if (match != null) {
        String original = match.group(1)!;
        return '$original de $nombre';
      }
    }

    String unidadStr = unidadVenta.isNotEmpty ? ' $unidadVenta' : '';
    if (unidadVenta == 'pieza' || unidadVenta == 'paquete') {
       if (cantidad != 1) unidadStr = ' ${unidadVenta}s';
    }

    return '$cantStr$unidadStr de $nombre'.trim();
  }

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'codigo': codigo,
      'nombre': nombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'observaciones': observaciones,
      'unidadVenta': unidadVenta,
      'subtotal': subtotal,
    };
  }

  factory TicketItem.fromMap(Map<String, dynamic> map) {
    return TicketItem(
      productoId: map['productoId'] ?? '',
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      precioUnitario: (map['precioUnitario'] ?? 0).toDouble(),
      observaciones: map['observaciones'] ?? '',
      unidadVenta: map['unidadVenta'] ?? '',
    );
  }
}

class Ticket {
  String id;
  String folio;
  String clienteId;
  String clienteNombre;
  Timestamp? fecha;
  List<TicketItem> productos;
  double totalVenta;
  double totalAbonado;
  String estado; // 'Pagado', 'Con Deuda'
  
  // Nuevos campos para entregas
  String tipoEntrega; // 'Local', 'Domicilio'
  String? repartidorId;
  String? repartidorNombre;
  String estadoEntrega; // 'Entregado', 'Pendiente', 'Cancelado'
  String? motivoCancelacion;

  String createBy;
  Timestamp? createAt;
  String updateBy;
  Timestamp? updateAt;

  Ticket({
    this.id = '',
    this.folio = '',
    required this.clienteId,
    required this.clienteNombre,
    this.fecha,
    required this.productos,
    required this.totalVenta,
    required this.totalAbonado,
    required this.estado,
    this.tipoEntrega = 'Local',
    this.repartidorId,
    this.repartidorNombre,
    this.estadoEntrega = 'Entregado',
    this.motivoCancelacion,
    this.createBy = 'Sistema',
    this.createAt,
    this.updateBy = 'Sistema',
    this.updateAt,
  });

  double get saldoRestante => totalVenta - totalAbonado;

  factory Ticket.fromMap(String id, Map<String, dynamic> data) {
    var list = data['productos'] as List? ?? [];
    List<TicketItem> itemsList = list.map((i) => TicketItem.fromMap(i as Map<String, dynamic>)).toList();

    return Ticket(
      id: id,
      folio: data['folio'] ?? id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase(),
      clienteId: data['clienteId'] ?? '',
      clienteNombre: data['clienteNombre'] ?? '',
      fecha: data['fecha'],
      productos: itemsList,
      totalVenta: (data['totalVenta'] ?? 0).toDouble(),
      totalAbonado: (data['totalAbonado'] ?? 0).toDouble(),
      estado: data['estado'] ?? 'Con Deuda',
      tipoEntrega: data['tipoEntrega'] ?? 'Local',
      repartidorId: data['repartidorId'],
      repartidorNombre: data['repartidorNombre'],
      estadoEntrega: data['estadoEntrega'] ?? 'Entregado',
      motivoCancelacion: data['motivoCancelacion'],
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
      updateBy: data['updateBy'] ?? '',
      updateAt: data['updateAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'folio': folio,
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'fecha': fecha,
      'productos': productos.map((x) => x.toMap()).toList(),
      'totalVenta': totalVenta,
      'totalAbonado': totalAbonado,
      'saldoRestante': saldoRestante,
      'estado': estado,
      'tipoEntrega': tipoEntrega,
      'repartidorId': repartidorId,
      'repartidorNombre': repartidorNombre,
      'estadoEntrega': estadoEntrega,
      'motivoCancelacion': motivoCancelacion,
      'createBy': createBy,
      'createAt': createAt,
      'updateBy': updateBy,
      'updateAt': updateAt,
    };
  }
}
