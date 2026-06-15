import 'package:cloud_firestore/cloud_firestore.dart';

class Gasto {
  String id;
  String empresaId;
  String concepto;
  double monto;
  Timestamp? fecha;
  String createBy;
  Timestamp? createAt;

  Gasto({
    this.id = '',
    this.empresaId = '',
    required this.concepto,
    required this.monto,
    this.fecha,
    this.createBy = 'Sistema',
    this.createAt,
  });

  factory Gasto.fromMap(String id, Map<String, dynamic> data) {
    return Gasto(
      id: id,
      empresaId: data['empresaId'] ?? '',
      concepto: data['concepto'] ?? '',
      monto: (data['monto'] ?? 0).toDouble(),
      fecha: data['fecha'],
      createBy: data['createBy'] ?? 'Sistema',
      createAt: data['createAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresaId': empresaId,
      'concepto': concepto,
      'monto': monto,
      'fecha': fecha ?? FieldValue.serverTimestamp(),
      'createBy': createBy,
      'createAt': createAt ?? FieldValue.serverTimestamp(),
    };
  }
}
