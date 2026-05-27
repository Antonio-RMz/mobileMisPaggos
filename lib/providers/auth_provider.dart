import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isAuthenticated = false;
  bool _isLoading = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

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
    
    _isAuthenticated = isLogged;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final query = await _firestore
          .collection('usuarios')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // Credenciales válidas
        _isAuthenticated = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('logged_username', username);
        
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

  Future<void> logout() async {
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('logged_username');
    notifyListeners();
  }
}
