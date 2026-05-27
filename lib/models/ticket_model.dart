import 'package:cloud_firestore/cloud_firestore.dart';

class TicketItem {
  String productoId;
  String codigo;
  String nombre;
  double cantidad;
  double precioUnitario;

  TicketItem({
    required this.productoId,
    this.codigo = '',
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'codigo': codigo,
      'nombre': nombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
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
    );
  }
}

class Ticket {
  String id;
  String clienteId;
  String clienteNombre;
  Timestamp? fecha;
  List<TicketItem> productos;
  double totalVenta;
  double totalAbonado;
  String estado; // 'Pagado', 'Con Deuda'
  String createBy;
  Timestamp? createAt;
  String updateBy;
  Timestamp? updateAt;

  Ticket({
    this.id = '',
    required this.clienteId,
    required this.clienteNombre,
    this.fecha,
    required this.productos,
    required this.totalVenta,
    required this.totalAbonado,
    required this.estado,
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
      clienteId: data['clienteId'] ?? '',
      clienteNombre: data['clienteNombre'] ?? '',
      fecha: data['fecha'],
      productos: itemsList,
      totalVenta: (data['totalVenta'] ?? 0).toDouble(),
      totalAbonado: (data['totalAbonado'] ?? 0).toDouble(),
      estado: data['estado'] ?? 'Con Deuda',
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
      updateBy: data['updateBy'] ?? '',
      updateAt: data['updateAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'fecha': fecha,
      'productos': productos.map((x) => x.toMap()).toList(),
      'totalVenta': totalVenta,
      'totalAbonado': totalAbonado,
      'saldoRestante': saldoRestante,
      'estado': estado,
      'createBy': createBy,
      'createAt': createAt,
      'updateBy': updateBy,
      'updateAt': updateAt,
    };
  }
}
