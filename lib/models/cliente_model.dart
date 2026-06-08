import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para Cliente
/// Define la estructura de los clientes en la colección 'clientes'.
class Cliente {
  String id;
  String empresaId;
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
  int colorPerfil;
  double deudaTotal;
  String createBy;
  Timestamp? createAt;
  String updateBy;
  Timestamp? updateAt;
  bool isDistinguido;

  Cliente({
    this.id = '',
    this.empresaId = '',
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
    this.colorPerfil = 0xFF2DD4BF,
    this.deudaTotal = 0.0,
    this.createBy = 'Admin',
    this.createAt,
    this.updateBy = 'Admin',
    this.updateAt,
    this.isDistinguido = false,
  });

  String get nombreCompleto => '$nombre $apPaterno $apMaterno'.trim();

  String get iniciales {
    String n = nombre.isNotEmpty ? nombre[0].toUpperCase() : '';
    String a = apPaterno.isNotEmpty ? apPaterno[0].toUpperCase() : '';
    if (n.isEmpty && a.isEmpty) return '?';
    return '$n$a';
  }

  /// Crea una instancia de Cliente a partir de un documento de Firestore
  factory Cliente.fromMap(String id, Map<String, dynamic> data) {
    return Cliente(
      id: id,
      empresaId: data['empresaId'] ?? '',
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
      colorPerfil: data['colorPerfil'] ?? 0xFF2DD4BF,
      deudaTotal: (data['deuda_total'] ?? 0).toDouble(),
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
      updateBy: data['updateBy'] ?? '',
      updateAt: data['updateAt'],
      isDistinguido: data['isDistinguido'] ?? false,
    );
  }

  /// Convierte la instancia de Cliente a un mapa para guardarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'empresaId': empresaId,
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
      'colorPerfil': colorPerfil,
      'deuda_total': deudaTotal,
      'createBy': createBy,
      'createAt': createAt,
      'updateBy': updateBy,
      'updateAt': updateAt,
      'isDistinguido': isDistinguido,
    };
  }
}
