import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'main.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar el entorno actual a DEV
  Environment.init(EnvironmentType.dev);

  // Inicialización de Firebase con las opciones de configuración para DEV
  // (Actualmente apuntando a systdm-ef45c según la instrucción)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const GestionClientesApp());
}
