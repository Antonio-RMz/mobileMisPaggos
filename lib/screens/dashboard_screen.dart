import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../models/cliente_model.dart';
import 'cliente_profile_screen.dart';
import '../widgets/app_drawer.dart';
import 'cliente_list_screen.dart';
import 'entregas_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  bool _censurarDatos = false;

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
        title: const Text('MisPaggos'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<DashboardProvider>().cargarMetricas(),
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),

                _buildMetricsCards(context),
                const SizedBox(height: 32),
                _buildDeliveryStatus(context),
                const SizedBox(height: 32),
                const Text(
                  'Atención Prioritaria (Top Morosos)',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTopMorososList(context),
                const SizedBox(height: 32),
                _buildTopProducts(context),
              ],
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hola,',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Resumen del Negocio',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              iconSize: 32,
              icon: Icon(_censurarDatos ? LucideIcons.eyeOff : LucideIcons.eye, color: AppTheme.textLight),
              onPressed: () {
                setState(() {
                  _censurarDatos = !_censurarDatos;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsCards(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildSolidCard(
              title: 'Deuda de Clientes',
              amount: dashboard.totalPorCobrar,
              icon: LucideIcons.wallet,
              color: AppTheme.whiteColor,
              borderColor: AppTheme.accent,
              textColor: AppTheme.textDark,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSolidCard(
                    title: 'Ventas del Mes',
                    amount: dashboard.ventasDelMes,
                    icon: LucideIcons.trendingUp,
                    color: AppTheme.whiteColor,
                    borderColor: AppTheme.primary,
                    textColor: AppTheme.textDark,
                    small: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSolidCard(
                    title: 'Ganancias Hoy',
                    amount: dashboard.ventasDeHoy,
                    icon: LucideIcons.sun,
                    color: AppTheme.whiteColor,
                    borderColor: AppTheme.success,
                    textColor: AppTheme.textDark,
                    small: true,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSolidCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color borderColor,
    required Color textColor,
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.all(small ? 12 : 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: small ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: borderColor, size: small ? 24 : 28),
            ],
          ),
          SizedBox(height: small ? 6 : 10),
          Text(
            _censurarDatos ? '\$***.**' : currencyFormat.format(amount),
            style: TextStyle(
              fontSize: small ? 20 : 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMorososList(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (dashboard.topMorosos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.success.withOpacity(0.3), width: 2),
            ),
            child: const Center(
              child: Text(
                '¡Excelente! No hay clientes con deuda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.success, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dashboard.topMorosos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final cliente = dashboard.topMorosos[index];
            return _buildMorosoTile(context, cliente, index);
          },
        );
      },
    );
  }

  Widget _buildMorosoTile(BuildContext context, Cliente cliente, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Color(cliente.colorPerfil),
          foregroundColor: AppTheme.slateBlue,
          child: Text(
            cliente.iniciales,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        title: Text(
          cliente.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: const Text(
          'Tocar para ver historial',
          style: TextStyle(color: AppTheme.textLight, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Debe', style: TextStyle(color: AppTheme.textLight, fontSize: 11)),
            Text(
              currencyFormat.format(cliente.deudaTotal),
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClienteProfileScreen(cliente: cliente),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeliveryStatus(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estado de Envíos (Hoy)',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Icon(LucideIcons.map, color: AppTheme.primary, size: 32),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusCard(
              context: context,
              title: 'En Reparto (Pendientes)',
              count: dashboard.entregasEnReparto,
              color: Colors.orange.shade700,
              icon: LucideIcons.packageOpen,
              estadoFiltro: 'Pendiente',
            ),
            _buildStatusCard(
              context: context,
              title: 'Completados (Entregados)',
              count: dashboard.entregasEnviadas,
              color: AppTheme.success,
              icon: LucideIcons.checkCircle2,
              estadoFiltro: 'Completados',
            ),
            _buildStatusCard(
              context: context,
              title: 'Cancelados',
              count: dashboard.entregasCanceladas,
              color: AppTheme.error,
              icon: LucideIcons.xCircle,
              estadoFiltro: 'Cancelado',
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
    required String estadoFiltro,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EntregasListScreen(title: title, estadoEntregaFiltro: estadoFiltro),
          ),
        ).then((_) {
          if (context.mounted) {
            context.read<DashboardProvider>().cargarMetricas();
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) return const SizedBox();
        
        final carnes = dashboard.topProductosCarnes.entries.toList();
        final catalogo = dashboard.topProductosCatalogo.entries.toList();

        if (carnes.isEmpty && catalogo.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos Más Vendidos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 20),
            if (carnes.isNotEmpty)
               _buildProductList('Carnicería', carnes, Colors.redAccent),
            if (carnes.isNotEmpty && catalogo.isNotEmpty) const SizedBox(height: 16),
            if (catalogo.isNotEmpty)
               _buildProductList('Catálogo', catalogo, AppTheme.primary),
          ],
        );
      },
    );
  }

  Widget _buildProductList(String title, List<MapEntry<String, double>> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(title == 'Carnicería' ? Icons.set_meal : Icons.inventory_2, color: color, size: 28),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                Text('${entry.value.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
