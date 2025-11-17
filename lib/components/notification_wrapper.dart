import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../components/notification_badge.dart';
import '../services/notification_service.dart';

/// Wrapper pour gérer les notifications et l'effet de scintillement
class NotificationWrapper extends StatefulWidget {
  final Widget child;
  
  const NotificationWrapper({
    super.key,
    required this.child,
  });

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  StreamSubscription? _webSocketSubscription;
  bool _notificationServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _listenToWebSocket();
  }
  
  /// Initialiser le service de notifications
  Future<void> _initializeNotifications() async {
    if (_notificationServiceInitialized) return;
    
    try {
      final notificationService = NotificationService();
      await notificationService.initialize(context);
      _notificationServiceInitialized = true;
      debugPrint('✅ NotificationService initialisé dans NotificationWrapper');
    } catch (e) {
      debugPrint('❌ Erreur initialisation NotificationService: $e');
    }
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  void _listenToWebSocket() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final notificationService = NotificationService();
    
    _webSocketSubscription = appProvider.webSocketStream.listen((message) {
      debugPrint('🔔 Message WebSocket reçu: ${message['type']}');
      
      // Gérer les différents types de messages
      switch (message['type']) {
        case 'new_message':
        case 'new_group_message':
          // Incrémenter le compteur de messages non lus
          appProvider.incrementUnreadMessages();
          debugPrint('📬 Nouveau message - Total non lus: ${appProvider.unreadMessagesCount}');
          
          // Mettre à jour le badge sur l'icône de l'app
          notificationService.updateAppBadge(appProvider.unreadMessagesCount);
          break;
          
        case 'new_comment':
        case 'new_publication':
        case 'new_like':
          // Notifier mais ne pas compter comme message non lu
          debugPrint('🔔 Nouvelle notification: ${message['type']}');
          break;
          
        case 'message_read':
        case 'messages_read':
          // Décrémenter ou réinitialiser selon le nombre de messages lus
          final readCount = message['count'] as int? ?? 1;
          final currentCount = appProvider.unreadMessagesCount;
          final newCount = (currentCount - readCount).clamp(0, 9999);
          appProvider.setUnreadMessagesCount(newCount);
          debugPrint('✅ Messages lus - Restants: $newCount');
          
          // Mettre à jour le badge sur l'icône de l'app
          notificationService.updateAppBadge(newCount);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return GlowingBorder(
          isGlowing: appProvider.hasUnreadNotifications,
          glowColor: const Color(0xFF00D4FF),
          borderRadius: 0, // Bordure de l'écran
          child: widget.child,
        );
      },
    );
  }
}
