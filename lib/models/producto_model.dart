import 'package:cloud_firestore/cloud_firestore.dart';

class Producto {
  String id;
  String empresaId;
  String nombre;
  String codigo;
  double precio;
  String observaciones;
  String categoria;
  String unidadVenta;
  String seccion;
  bool esChicharron;
  String createBy;
  Timestamp? createAt;
  String updateBy;
  Timestamp? updateAt;

  Producto({
    this.id = '',
    this.empresaId = '',
    required this.nombre,
    required this.codigo,
    required this.precio,
    required this.observaciones,
    this.categoria = 'General',
    this.unidadVenta = 'pieza', // 'kg', 'gramo', 'pieza', 'paquete'
    this.seccion = 'catalogo', // 'catalogo' o 'carniceria'
    this.esChicharron = false,
    this.createBy = 'Admin', // Usuario por defecto hasta tener auth
    this.createAt,
    this.updateBy = 'Admin',
    this.updateAt,
  });

  factory Producto.fromMap(String id, Map<String, dynamic> data) {
    return Producto(
      id: id,
      empresaId: data['empresaId'] ?? '',
      nombre: data['nombre'] ?? '',
      codigo: data['codigo'] ?? '',
      precio: (data['precio'] ?? 0).toDouble(),
      observaciones: data['observaciones'] ?? '',
      categoria: data['categoria'] ?? 'General',
      unidadVenta: data['unidadVenta'] ?? data['tipoVenta'] ?? 'pieza', // Fallback for old data
      seccion: data['seccion'] ?? 'catalogo',
      esChicharron: data['esChicharron'] ?? false,
      createBy: data['createBy'] ?? '',
      createAt: data['createAt'],
      updateBy: data['updateBy'] ?? '',
      updateAt: data['updateAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresaId': empresaId,
      'nombre': nombre,
      'codigo': codigo,
      'precio': precio,
      'observaciones': observaciones,
      'categoria': categoria,
      'unidadVenta': unidadVenta,
      'seccion': seccion,
      'esChicharron': esChicharron,
      'createBy': createBy,
      'createAt': createAt,
      'updateBy': updateBy,
      'updateAt': updateAt,
    };
  }
}
