import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String _nombre = 'STEWARD';
  String _imagePath = '';
  bool _isInitialized = false;

  String get nombre => _nombre;
  String get imagePath => _imagePath;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _nombre = prefs.getString('user_name') ?? 'STEWARD';
    _imagePath = prefs.getString('user_image_path') ?? '';
    _isInitialized = true;
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
}
