import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import 'user_provider.dart';
import '../services/local_notification_service.dart';

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final Ticket ticket;
  bool isRead;

  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.ticket,
    this.isRead = false,
  });
}

class NotificationProvider with ChangeNotifier {
  UserProvider? _userProvider;
  String? _lastEmpresaId;
  List<InAppNotification> _notifications = [];
  Set<String> _notifiedTicketIds = {};
  Set<String> _notified10MinTicketIds = {};
  StreamSubscription<QuerySnapshot>? _ticketsSubscription;
  Timer? _timer;
  List<Ticket> _activeScheduledTickets = [];

  List<InAppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _loadNotifiedIds();
    // Revisar los pedidos programados periódicamente cada 30 segundos
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkScheduledTickets());
  }

  void updateUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    if (_lastEmpresaId != userProvider.empresaId) {
      _lastEmpresaId = userProvider.empresaId;
      _notifications.clear();
      _ticketsSubscription?.cancel();
      if (userProvider.empresaId.isNotEmpty) {
        _listenToScheduledTickets(userProvider.empresaId);
      }
    }
  }

  Future<void> _loadNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_scheduled_tickets') ?? [];
      _notifiedTicketIds = list.toSet();

      final list10 = prefs.getStringList('notified_10min_scheduled_tickets') ?? [];
      _notified10MinTicketIds = list10.toSet();
    } catch (e) {
      debugPrint("Error loading notified IDs: $e");
    }
  }

  Future<void> _saveNotifiedId(String id) async {
    _notifiedTicketIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notified_scheduled_tickets', _notifiedTicketIds.toList());
    } catch (e) {
      debugPrint("Error saving notified ID: $e");
    }
  }

  Future<void> _save10MinNotifiedId(String id) async {
    _notified10MinTicketIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notified_10min_scheduled_tickets', _notified10MinTicketIds.toList());
    } catch (e) {
      debugPrint("Error saving 10min notified ID: $e");
    }
  }

  void _listenToScheduledTickets(String empresaId) {
    _ticketsSubscription = FirebaseFirestore.instance
        .collection('tickets')
        .where('empresaId', isEqualTo: empresaId)
        .where('estadoEntrega', isEqualTo: 'Programado')
        .snapshots()
        .listen((snapshot) {
      _activeScheduledTickets = snapshot.docs.map((doc) {
        return Ticket.fromMap(doc.id, doc.data());
      }).toList();

      // Limpiar notificaciones si los tickets ya no están en estado 'Programado'
      final activeTicketIds = _activeScheduledTickets.map((t) => t.id).toSet();
      _notifications.removeWhere((n) => !activeTicketIds.contains(n.ticket.id));

      _checkScheduledTickets();
      notifyListeners();
    });
  }

  void _checkScheduledTickets() {
    if (_activeScheduledTickets.isEmpty) return;

    final now = DateTime.now();
    bool updated = false;

    for (var ticket in _activeScheduledTickets) {
      if (ticket.fechaEntregaProgramada == null) continue;

      final deliveryTime = ticket.fechaEntregaProgramada!.toDate();
      final difference = deliveryTime.difference(now);

      // Alertar si faltan 10 minutos o menos, y hasta 60 minutos después (si el app se abre tarde)
      if (difference.inMinutes <= 10 && difference.inMinutes >= -60) {
        if (!_notified10MinTicketIds.contains(ticket.id)) {
          final timeStr = DateFormat('hh:mm a').format(deliveryTime);
          
          _notifications.insert(
            0,
            InAppNotification(
              id: "NOT_10M_${ticket.id}_${DateTime.now().millisecondsSinceEpoch}",
              title: "¡Pedido a 10 Minutos!",
              message: "¡ALERTA! El pedido de ${ticket.clienteNombre} programado para las $timeStr está a solo 10 minutos de su entrega.",
              timestamp: now,
              ticket: ticket,
            ),
          );
          
          LocalNotificationService.showAlarmNotification(
            id: ticket.id.hashCode + 1,
            title: "🚨 ¡Pedido a 10 Minutos!",
            body: "El pedido de ${ticket.clienteNombre} ($timeStr) está a solo 10 minutos de su entrega.",
          );

          _save10MinNotifiedId(ticket.id);
          updated = true;
        }
      }

      // Alertar si faltan 30 minutos o menos, y hasta 60 minutos después (si el app se abre tarde)
      if (difference.inMinutes <= 30 && difference.inMinutes >= -60) {
        if (!_notifiedTicketIds.contains(ticket.id)) {
          final timeStr = DateFormat('hh:mm a').format(deliveryTime);
          
          _notifications.insert(
            0,
            InAppNotification(
              id: "NOT_${ticket.id}_${DateTime.now().millisecondsSinceEpoch}",
              title: "Pedido Próximo a Entregar",
              message: "El pedido de ${ticket.clienteNombre} programado para las $timeStr está a 30 minutos o menos de su entrega.",
              timestamp: now,
              ticket: ticket,
            ),
          );
          
          LocalNotificationService.showAlarmNotification(
            id: ticket.id.hashCode,
            title: "⏰ Pedido Próximo a Entregar",
            body: "El pedido de ${ticket.clienteNombre} programado para las $timeStr está a 30 minutos o menos de su entrega.",
          );

          _saveNotifiedId(ticket.id);
          updated = true;
        }
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticketsSubscription?.cancel();
    super.dispose();
  }
}
