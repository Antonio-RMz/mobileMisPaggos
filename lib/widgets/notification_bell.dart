import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../screens/pedidos_programados_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                color: unreadCount > 0 ? AppTheme.accent : AppTheme.textDark,
                size: 24,
              ),
              onPressed: () => _mostrarNotificaciones(context, provider),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _mostrarNotificaciones(BuildContext context, NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final notifications = provider.notifications;

            return Container(
              height: MediaQuery.of(context).size.height * 0.70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Alertas de Entrega',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        if (notifications.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              provider.markAllAsRead();
                              setModalState(() {});
                            },
                            child: const Text('Leer todas', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.bellOff, size: 36, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Sin notificaciones pendientes',
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Te avisaremos cuando falten 30 min para una entrega.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final item = notifications[index];
                              final formattedTime = DateFormat('hh:mm a').format(item.timestamp);

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: item.isRead ? Colors.grey.shade100 : AppTheme.accent.withOpacity(0.3),
                                    width: item.isRead ? 1.0 : 1.5,
                                  ),
                                ),
                                color: item.isRead ? Colors.white : AppTheme.accent.withOpacity(0.02),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: item.isRead ? Colors.grey.shade100 : Colors.amber.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item.isRead ? LucideIcons.bell : LucideIcons.bellRing,
                                      color: item.isRead ? Colors.grey : Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontWeight: item.isRead ? FontWeight.bold : FontWeight.w900,
                                          fontSize: 14,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      item.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: item.isRead ? AppTheme.textLight : AppTheme.textDark,
                                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    provider.markAsRead(item.id);
                                    Navigator.pop(modalContext); // Cierra modal
                                    
                                    // Navegar a la pantalla de programados
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PedidosProgramadosScreen()),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
