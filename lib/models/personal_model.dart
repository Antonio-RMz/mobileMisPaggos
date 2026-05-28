import 'package:cloud_firestore/cloud_firestore.dart';

class Personal {
  String id;
  String nombre;
  String telefono;
  String rol; // 'Empleado' o 'Repartidor'
  bool activo;
  String createBy;
  Timestamp? createAt;

  Personal({
    this.id = '',
    required this.nombre,
    required this.telefono,
    required this.rol,
    this.activo = true,
    this.createBy = 'Admin',
    this.createAt,
  });

  factory Personal.fromMap(String id, Map<String, dynamic> data) {
    return Personal(
      id: id,
      nombre: data['nombre'] ?? '',
      telefono: data['telefono'] ?? '',
      rol: data['rol'] ?? 'Empleado',
      activo: data['activo'] ?? true,
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'rol': rol,
      'activo': activo,
      'createBy': createBy,
      'createAt': createAt ?? FieldValue.serverTimestamp(),
    };
  }
}
