import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para Cliente
/// Define la estructura de los clientes en la colección 'clientes'.
class Cliente {
  String id;
  String nombre;
  String apPaterno;
  String apMaterno;
  String celular;
  String correo;
  String telefono;
  String observaciones;
  String direccion;
  String apodo;
  String referenciasDireccion;
  double deudaTotal;
  String createBy;
  Timestamp? createAt;
  String updateBy;
  Timestamp? updateAt;

  Cliente({
    this.id = '',
    required this.nombre,
    required this.apPaterno,
    required this.apMaterno,
    required this.celular,
    required this.correo,
    required this.telefono,
    required this.observaciones,
    this.direccion = '',
    this.apodo = '',
    this.referenciasDireccion = '',
    this.deudaTotal = 0.0,
    this.createBy = 'Admin',
    this.createAt,
    this.updateBy = 'Admin',
    this.updateAt,
  });

  String get nombreCompleto => '$nombre $apPaterno $apMaterno'.trim();

  /// Crea una instancia de Cliente a partir de un documento de Firestore
  factory Cliente.fromMap(String id, Map<String, dynamic> data) {
    return Cliente(
      id: id,
      nombre: data['nombre'] ?? '',
      apPaterno: data['appaterno'] ?? '', // Campos en minúscula según requerimiento
      apMaterno: data['apmaterno'] ?? '',
      celular: data['celular'] ?? '',
      correo: data['correo'] ?? '',
      telefono: data['telefono'] ?? '',
      observaciones: data['observaciones'] ?? '',
      direccion: data['direccion'] ?? '',
      apodo: data['apodo'] ?? '',
      referenciasDireccion: data['referenciasDireccion'] ?? '',
      deudaTotal: (data['deuda_total'] ?? 0).toDouble(),
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
      updateBy: data['updateBy'] ?? '',
      updateAt: data['updateAt'],
    );
  }

  /// Convierte la instancia de Cliente a un mapa para guardarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'appaterno': apPaterno,
      'apmaterno': apMaterno,
      'celular': celular,
      'correo': correo,
      'telefono': telefono,
      'observaciones': observaciones,
      'direccion': direccion,
      'apodo': apodo,
      'referenciasDireccion': referenciasDireccion,
      'deuda_total': deudaTotal,
      'createBy': createBy,
      'createAt': createAt,
      'updateBy': updateBy,
      'updateAt': updateAt,
    };
  }
}
