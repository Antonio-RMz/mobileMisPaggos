import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'providers/cart_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/user_provider.dart';
import 'providers/printer_provider.dart';
import 'screens/login_screen.dart';

import 'services/firebase_service.dart';

/// Widget raíz de la aplicación
class GestionClientesApp extends StatelessWidget {
  const GestionClientesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..init()),
        ProxyProvider<UserProvider, FirebaseService>(
          update: (_, userProvider, __) => FirebaseService(empresaId: userProvider.empresaId),
        ),
        ChangeNotifierProxyProvider<UserProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, userProvider, dashboardProvider) => 
              dashboardProvider!..updateUserProvider(userProvider),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
      ],
      child: MaterialApp(
        title: 'MisPaggos',
        debugShowCheckedModeBanner: false,
        // Se inyecta el tema global definido en app_theme.dart con las reglas de color
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
