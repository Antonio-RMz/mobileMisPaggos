import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../models/cliente_model.dart';
import 'cliente_profile_screen.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import 'cliente_list_screen.dart';
import 'ventas_list_screen.dart';

class InicioOperativoScreen extends StatefulWidget {
  const InicioOperativoScreen({super.key});

  @override
  State<InicioOperativoScreen> createState() => _InicioOperativoScreenState();
}

class _InicioOperativoScreenState extends State<InicioOperativoScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().cargarMetricas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Inicio'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: const [
          NotificationBell(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<DashboardProvider>().cargarMetricas();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeliveryStatus(context),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClienteListScreen(isSelectingForOrder: true)),
          );
        },
        icon: const Icon(LucideIcons.truck, color: Colors.white),
        label: const Text('NUEVO PEDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: AppTheme.accent,
        elevation: 4,
      ),
    );
  }



  Widget _buildDeliveryStatus(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) return const SizedBox();
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isWide = screenWidth >= AppTheme.tabletBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de Ventas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildStatusCard(
                          context: context,
                          title: 'Ventas de Hoy',
                          count: dashboard.ventasHoyCount,
                          color: AppTheme.accent,
                          icon: LucideIcons.shoppingBag,
                          filtroEstado: 'Todas',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatusCard(
                          context: context,
                          title: 'Canceladas',
                          count: dashboard.entregasCanceladas,
                          color: Colors.redAccent,
                          icon: LucideIcons.xCircle,
                          isClickable: true,
                          filtroEstado: 'Cancelado',
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildStatusCard(
                        context: context,
                        title: 'Ventas de Hoy',
                        count: dashboard.ventasHoyCount,
                        color: AppTheme.accent,
                        icon: LucideIcons.shoppingBag,
                        filtroEstado: 'Todas',
                      ),
                      _buildStatusCard(
                        context: context,
                        title: 'Canceladas',
                        count: dashboard.entregasCanceladas,
                        color: Colors.redAccent,
                        icon: LucideIcons.xCircle,
                        isClickable: true,
                        filtroEstado: 'Cancelado',
                      ),
                    ],
                  ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard({
    required BuildContext context,
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    bool isClickable = true,
    String filtroEstado = 'Todas',
  }) {
    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            if (isClickable) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
            ],
          ],
        ),
      );

    if (isClickable) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VentasListScreen(filtroEstadoInicial: filtroEstado),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<DashboardProvider>().cargarMetricas();
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildTopMorososList(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (dashboard.topMorosos.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Atención Prioritaria',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashboard.topMorosos.length > 5 ? 5 : dashboard.topMorosos.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final cliente = dashboard.topMorosos[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      child: const Icon(LucideIcons.alertCircle, color: Colors.redAccent),
                    ),
                    title: Text(
                      cliente.apodo.isNotEmpty ? cliente.apodo : '${cliente.nombre} ${cliente.apPaterno}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Saldo pendiente'),
                    trailing: Text(
                      currencyFormat.format(cliente.deudaTotal),
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClienteProfileScreen(cliente: cliente),
                        ),
                      ).then((_) {
                        if (context.mounted) {
                          context.read<DashboardProvider>().cargarMetricas();
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
