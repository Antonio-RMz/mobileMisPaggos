import 'package:cloud_firestore/cloud_firestore.dart';

class Abono {
  String id;
  String clienteId;
  String? ticketId; // Si es null, es un abono general a la cuenta
  String? repartidorId; // Agregado para saber qué repartidor cobró este efectivo
  double monto;
  Timestamp? fecha;
  String createBy;
  Timestamp? createAt;
  String updateBy;
  Timestamp? updateAt;

  Abono({
    this.id = '',
    required this.clienteId,
    this.ticketId,
    this.repartidorId,
    required this.monto,
    this.fecha,
    this.createBy = 'Sistema',
    this.createAt,
    this.updateBy = 'Sistema',
    this.updateAt,
  });

  factory Abono.fromMap(String id, Map<String, dynamic> data) {
    return Abono(
      id: id,
      clienteId: data['clienteId'] ?? '',
      ticketId: data['ticketId'],
      repartidorId: data['repartidorId'],
      monto: (data['monto'] ?? 0).toDouble(),
      fecha: data['fecha'],
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
      updateBy: data['updateBy'] ?? '',
      updateAt: data['updateAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'ticketId': ticketId,
      'repartidorId': repartidorId,
      'monto': monto,
      'fecha': fecha,
      'createBy': createBy,
      'createAt': createAt,
      'updateBy': updateBy,
      'updateAt': updateAt,
    };
  }
}
