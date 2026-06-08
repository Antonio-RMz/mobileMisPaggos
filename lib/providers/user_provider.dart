import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String _uid = '';
  String _empresaId = '';
  String _rol = '';
  String _nombre = 'STEWARD';
  String _imagePath = '';
  bool _isInitialized = false;

  String get uid => _uid;
  String get empresaId => _empresaId;
  String get rol => _rol;
  String get nombre => _nombre;
  String get imagePath => _imagePath;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('user_uid') ?? '';
    _empresaId = prefs.getString('user_empresa_id') ?? '';
    _rol = prefs.getString('user_rol') ?? '';
    _nombre = prefs.getString('user_name') ?? 'STEWARD';
    _imagePath = prefs.getString('user_image_path') ?? '';
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updateUserData({
    required String uid,
    required String empresaId,
    required String rol,
    required String nombre,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);
    await prefs.setString('user_empresa_id', empresaId);
    await prefs.setString('user_rol', rol);
    await prefs.setString('user_name', nombre);
    
    _uid = uid;
    _empresaId = empresaId;
    _rol = rol;
    _nombre = nombre;
    notifyListeners();
  }

  Future<void> updateNombre(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);
    _nombre = newName;
    notifyListeners();
  }

  Future<void> updateImagePath(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_image_path', newPath);
    _imagePath = newPath;
    notifyListeners();
  }
  
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_uid');
    await prefs.remove('user_empresa_id');
    await prefs.remove('user_rol');
    await prefs.remove('user_name');
    await prefs.remove('user_image_path');
    
    _uid = '';
    _empresaId = '';
    _rol = '';
    _nombre = 'STEWARD';
    _imagePath = '';
    notifyListeners();
  }
}
