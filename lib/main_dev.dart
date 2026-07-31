import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_dev.dart';
import 'main.dart';
import 'config/environment.dart';
import 'services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.init();

  // Configurar el entorno actual a DEV
  Environment.init(EnvironmentType.dev);

  // Inicialización de Firebase con las opciones de configuración para DEV
  // (Actualmente apuntando a systdm-ef45c según la instrucción)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptionsDev.currentPlatform,
    );
  } catch (e) {
    debugPrint("Ignorando error de inicialización de Firebase: $e");
  }

  runApp(const GestionClientesApp());
}
