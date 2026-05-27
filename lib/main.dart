import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'providers/cart_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/user_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  // Asegura que los widgets de Flutter estén inicializados antes de Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase con las opciones de configuración para la plataforma actual
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const GestionClientesApp(),
    ),
  );
}

/// Widget raíz de la aplicación
class GestionClientesApp extends StatelessWidget {
  const GestionClientesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MisPaggos',
      debugShowCheckedModeBanner: false,
      // Se inyecta el tema global definido en app_theme.dart con las reglas de color
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            );
          }
          return authProvider.isAuthenticated ? const MainScreen() : const LoginScreen();
        },
      ),
    );
  }
}
