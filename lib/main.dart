import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/environment.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'providers/cart_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/user_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/notification_provider.dart';

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
        ChangeNotifierProxyProvider<UserProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, userProvider, notificationProvider) => 
              notificationProvider!..updateUserProvider(userProvider),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
      ],
      child: MaterialApp(
        title: Environment.isDev ? 'MisPaggosDev' : 'MisPaggos',
        debugShowCheckedModeBanner: false,
        // Se inyecta el tema global definido en app_theme.dart con las reglas de color
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('es', ''),
        ],
        locale: const Locale('es', 'ES'),
        home: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            if (!userProvider.isInitialized) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const MainScreen();
          },
        ),
      ),
    );
  }
}
