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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
        title: const Text('MisPaggos'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<DashboardProvider>().cargarMetricas(),
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildMetricsCards(context),
                const SizedBox(height: 30),
                _buildDeliveryStatus(context),
                const SizedBox(height: 30),
                Text(
                  'Atención Prioritaria (Top Morosos)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 15),
                _buildTopMorososList(context),
                const SizedBox(height: 30),
                _buildTopProducts(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola,',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Resumen del Negocio',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cardHighlight,
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.activity, color: AppTheme.primary, size: 28),
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
            const SizedBox(height: 16),
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
      padding: EdgeInsets.all(small ? 16 : 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: small ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textLight,
                ),
              ),
              Icon(icon, color: borderColor, size: small ? 24 : 32),
            ],
          ),
          SizedBox(height: small ? 8 : 12),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: small ? 24 : 32,
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                '¡Excelente! No hay clientes con deuda.',
                style: TextStyle(color: AppTheme.success, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dashboard.topMorosos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.error.withOpacity(0.1),
          child: Text(
            '${index + 1}',
            style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          cliente.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Toque para ver detalles',
          style: TextStyle(color: AppTheme.textLight, fontSize: 12),
        ),
        trailing: Text(
          currencyFormat.format(cliente.deudaTotal),
          style: TextStyle(
            color: AppTheme.error,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estado de Envíos (Hoy)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Icon(LucideIcons.truck, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    title: 'En Reparto',
                    count: dashboard.entregasEnReparto,
                    color: Colors.orange,
                    icon: LucideIcons.packageOpen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatusCard(
                    title: 'Enviados',
                    count: dashboard.entregasEnviadas,
                    color: AppTheme.success,
                    icon: LucideIcons.checkCircle2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatusCard(
                    title: 'Cancelados',
                    count: dashboard.entregasCanceladas,
                    color: AppTheme.error,
                    icon: LucideIcons.xCircle,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard({required String title, required int count, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textLight),
          ),
        ],
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
            Text(
              'Productos Más Vendidos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (carnes.isNotEmpty)
                  Expanded(
                    child: _buildProductList('Carnicería', carnes, Colors.redAccent),
                  ),
                if (carnes.isNotEmpty && catalogo.isNotEmpty) const SizedBox(width: 16),
                if (catalogo.isNotEmpty)
                  Expanded(
                    child: _buildProductList('Catálogo', catalogo, AppTheme.primary),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductList(String title, List<MapEntry<String, double>> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(title == 'Carnicería' ? Icons.set_meal : Icons.inventory_2, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${entry.value.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
