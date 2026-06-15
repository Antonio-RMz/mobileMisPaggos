import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import 'cliente_profile_screen.dart';
import '../widgets/app_drawer.dart';
import 'cliente_list_screen.dart';

import '../config/environment.dart';

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
        title: Text(Environment.isDev ? 'MisPaggosDev' : 'MisPaggos'),
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
              title: 'Deuda Generada Hoy',
              amount: dashboard.totalPorCobrar,
              icon: LucideIcons.wallet,
              color: AppTheme.whiteColor,
              borderColor: AppTheme.accent,
              textColor: AppTheme.textDark,
              onTap: () => _mostrarDetalleDeudaHoy(context, dashboard.ticketsDeudaHoy),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSolidCard(
                    title: 'Ventas de la Sem.',
                    amount: dashboard.ventasDelMes,
                    icon: LucideIcons.trendingUp,
                    color: AppTheme.whiteColor,
                    borderColor: AppTheme.primary,
                    textColor: AppTheme.textDark,
                    small: true,
                    onTap: () => _mostrarDetalleVentasSemana(context, dashboard.ventasPorDiaSemana),
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

  void _mostrarDetalleDeudaHoy(BuildContext context, List<Ticket> ticketsDeuda) {
    if (ticketsDeuda.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay deuda generada el día de hoy.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Desglose de Deuda de Hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: ticketsDeuda.length,
                  itemBuilder: (context, index) {
                    final t = ticketsDeuda[index];
                    final saldo = t.totalVenta - t.totalAbonado;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Folio: ${t.folio ?? "S/F"}'),
                      trailing: Text(currencyFormat.format(saldo), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 16)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDetalleVentasSemana(BuildContext context, Map<String, double> ventasPorDia) {
    if (ventasPorDia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos de ventas para esta semana.')),
      );
      return;
    }

    final list = ventasPorDia.entries.toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ventas por Día (Esta Semana)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: Text(currencyFormat.format(item.value), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16)),
                    );
                  },
                ),
              ),
            ],
          ),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    ));
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
              'Productos Más Vendidos (Hoy)',
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
                Text(
                  _censurarDatos 
                      ? 'Vendidos: ***' 
                      : title == 'Carnicería' 
                          ? 'Vendidos: ${entry.value.toStringAsFixed(1)} kg' 
                          : 'Vendidos: ${entry.value.toInt()} pzas',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
