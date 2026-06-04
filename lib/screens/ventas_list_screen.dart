import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';
import '../theme/app_theme.dart';
import 'pos_screen.dart';

class VentasListScreen extends StatefulWidget {
  const VentasListScreen({super.key});

  @override
  State<VentasListScreen> createState() => _VentasListScreenState();
}

class _VentasListScreenState extends State<VentasListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final dateFormat = DateFormat('dd MMM, HH:mm');
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<Ticket>> _getTicketsStream() {
    return FirebaseFirestore.instance
        .collection('tickets')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Ticket.fromMap(doc.id, doc.data())).toList();
      list.sort((a, b) => (b.fecha ?? Timestamp.now()).compareTo(a.fecha ?? Timestamp.now()));
      return list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Ventas', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.download, size: 18),
            label: const Text('Descargar Ventas'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textDark),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
            },
            icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
            label: const Text('Crear', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 60),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Filtrar por cliente, folio...',
                            prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Todas'),
                    Tab(text: 'Pagos Pendientes'),
                    Tab(text: 'No Entregadas'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Ticket>>(
        stream: _getTicketsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay ventas registradas.'));
          }

          var allTickets = snapshot.data!;
          if (_searchQuery.isNotEmpty) {
            allTickets = allTickets.where((t) =>
                t.clienteNombre.toLowerCase().contains(_searchQuery) ||
                (t.folio?.toLowerCase().contains(_searchQuery) ?? false)).toList();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(allTickets),
              _buildList(allTickets.where((t) => t.saldoRestante > 0).toList()),
              _buildList(allTickets.where((t) => t.estadoEntrega != 'Entregado' && t.tipoEntrega == 'Domicilio').toList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Ticket> tickets) {
    if (tickets.isEmpty) return const Center(child: Text('No hay resultados.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final t = tickets[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '#${t.folio ?? "S/F"}   ${t.clienteNombre}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            currencyFormat.format(t.totalVenta), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.fecha != null ? dateFormat.format(t.fecha!.toDate()) : 'Sin fecha', 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          if (t.saldoRestante > 0)
                            Text(
                              'Deuda: ${currencyFormat.format(t.saldoRestante)}', 
                              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildBadge(
                            t.saldoRestante > 0 ? 'Deuda' : 'Pagado',
                            t.saldoRestante > 0 ? Colors.red.shade100 : Colors.green.shade100,
                            t.saldoRestante > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          _buildBadge(
                            t.tipoEntrega == 'Domicilio' ? t.estadoEntrega : 'Tienda',
                            Colors.blue.shade50,
                            Colors.blue.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
