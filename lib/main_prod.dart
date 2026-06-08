import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'main.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar el entorno actual a PROD
  Environment.init(EnvironmentType.prod);

  // Inicialización de Firebase con las opciones de configuración para PROD
  // TODO: Cambiar 'DefaultFirebaseOptions.currentPlatform' a las opciones 
  // del nuevo proyecto de producción cuando se genere. Por ahora usa DEV.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const GestionClientesApp());
}
