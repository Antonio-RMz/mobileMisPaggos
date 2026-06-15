import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_prod.dart';
import 'main.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar el entorno actual a PROD
  Environment.init(EnvironmentType.prod);

  // Inicialización de Firebase con las opciones de configuración para PROD
  // TODO: Cambiar 'DefaultFirebaseOptions.currentPlatform' a las opciones 
  // del nuevo proyecto de producción cuando se genere. Por ahora usa DEV.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptionsProd.currentPlatform,
    );
  } catch (e) {
    debugPrint("Ignorando error de inicialización de Firebase: $e");
  }

  runApp(const GestionClientesApp());
}
