import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _role = 'admin';
  String _repartidorId = '';

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get role => _role;
  String get repartidorId => _repartidorId;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // 1. Sembrar el usuario admin si no existe en la base de datos
    try {
      final docRef = _firestore.collection('usuarios').doc('admin');
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        await docRef.set({
          'username': 'admin',
          'password': 'mexico2026#',
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error al inicializar admin en Firestore: $e');
    }

    // 2. Verificar si hay sesión guardada localmente
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('is_logged_in') ?? false;
    _role = prefs.getString('logged_role') ?? 'admin';
    _repartidorId = prefs.getString('logged_repartidor_id') ?? '';
    
    _isAuthenticated = isLogged;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fallback local por si el internet o Firestore fallan en el dispositivo
      if (username == 'admin' && password == 'mexico2026#') {
        _isAuthenticated = true;
        _role = 'admin';
        _repartidorId = '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('logged_username', username);
        await prefs.setString('logged_role', 'admin');
        await prefs.setString('logged_repartidor_id', '');
        
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final query = await _firestore
          .collection('usuarios')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        
        _role = data['role'] ?? 'admin';
        _repartidorId = data['repartidorId'] ?? '';

        // Credenciales válidas
        _isAuthenticated = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('logged_username', username);
        await prefs.setString('logged_role', _role);
        await prefs.setString('logged_repartidor_id', _repartidorId);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Credenciales inválidas
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error en login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String username = prefs.getString('logged_username') ?? 'admin';
      _role = prefs.getString('logged_role') ?? 'admin';
      _repartidorId = prefs.getString('logged_repartidor_id') ?? '';
      
      _isAuthenticated = true;
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('logged_username', username);
      await prefs.setString('logged_role', _role);
      await prefs.setString('logged_repartidor_id', _repartidorId);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error en login biometrico: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _role = 'admin';
    _repartidorId = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('logged_username');
    await prefs.remove('logged_role');
    await prefs.remove('logged_repartidor_id');
    notifyListeners();
  }
}
