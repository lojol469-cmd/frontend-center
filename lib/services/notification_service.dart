import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../pages/social_page.dart';
import '../pages/comments_page.dart';
import '../pages/profile_page.dart';

/// Service de gestion des notifications push (WebSocket + Notifications Locales)
/// Les notifications arrivent du backend via WebSocket et sont affichées localement
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  DateTime? _lastCheckTime;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  BuildContext? _appContext;

  /// Initialiser les notifications
  Future<void> initialize(BuildContext context) async {
    _appContext = context;

    try {
      // Demander la permission (Android 13+)
      await _requestPermission();

      // Configurer les notifications locales
      await _setupLocalNotifications();

      // Vérifier que le context est toujours monté
      if (!context.mounted) return;

      // ✅ Écouter les notifications du backend via WebSocket
      _setupWebSocketListener(context);

      debugPrint('✅ NotificationService initialisé (WebSocket + Notifications Locales)');
      debugPrint('📡 En attente des notifications du backend...');
      debugPrint('🔔 Les notifications s\'afficheront dans la barre de notification Android');

      // Envoyer une notification de test après 3 secondes pour vérifier
      Future.delayed(const Duration(seconds: 3), () {
        _showTestNotification();
      });
    } catch (e) {
      debugPrint('❌ Erreur initialisation NotificationService: $e');
    }
  }

  /// Afficher une notification de test pour vérifier le fonctionnement
  Future<void> _showTestNotification() async {
    await _showLocalNotification({
      'title': '✅ Notifications activées',
      'body': 'Vous recevrez les notifications ici même quand l\'app est fermée',
      'data': {'type': 'test'},
    });
    debugPrint('🧪 Notification de test envoyée');
  }

  /// Écouter les notifications via WebSocket
  void _setupWebSocketListener(BuildContext context) {
    if (!context.mounted) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    appProvider.webSocketStream.listen((data) async {
      final type = data['type'] as String?;

      debugPrint('📨 WebSocket message reçu: $type');

      // Afficher les nouvelles notifications reçues via WebSocket
      if (type == 'notification_update') {
        final notification = data['notification'] as Map<String, dynamic>?;
        if (notification != null) {
          debugPrint('🔔 Affichage notification: ${notification['title']}');
          await _showLocalNotification(notification);
        }
      }

      // Aussi afficher pour les likes, commentaires, messages
      else if (type == 'new_like') {
        await _handleNewLike(data);
      }
      else if (type == 'new_comment') {
        await _handleNewComment(data);
      }
      else if (type == 'new_message') {
        _showLocalNotification({
          'title': '📩 Nouveau message',
          'message': data['message'] ?? 'Vous avez reçu un nouveau message',
          'data': data,
        });
      }
    });

  }

  /// Gérer les nouveaux likes avec preview
  Future<void> _handleNewLike(Map<String, dynamic> data) async {
    try {
      final publicationId = data['publicationId'] as String?;
      if (publicationId == null) {
        // Fallback simple
        _showLocalNotification({
          'title': '❤️ Nouveau like',
          'message': data['message'] ?? 'Quelqu\'un a aimé votre publication',
          'data': data,
        });
        return;
      }

      // Récupérer les détails de la publication pour la preview
      final appProvider = Provider.of<AppProvider>(_appContext!, listen: false);
      final token = appProvider.accessToken;

      if (token == null) return;

      final publicationResult = await ApiService.getPublication(token, publicationId);

      if (publicationResult['success'] == true) {
        final publication = publicationResult['publication'] as Map<String, dynamic>;
        final content = publication['content'] as String? ?? '';
        final media = publication['media'] as List? ?? [];

        // Créer la notification avec preview
        final notificationData = {
          'title': '❤️ Nouveau like',
          'body': _buildLikeNotificationMessage(data, content, media),
          'data': {
            'type': 'like',
            'publicationId': publicationId,
            'publication': publication, // Inclure les détails pour la preview
          },
        };

        // Ajouter l'image de preview si disponible
        if (media.isNotEmpty) {
          final firstMedia = media[0] as Map<String, dynamic>;
          final mediaUrl = firstMedia['url'] as String?;
          if (mediaUrl != null) {
            (notificationData['data'] as Map<String, dynamic>)['imageUrl'] = mediaUrl;
          }
        }

        await _showLocalNotification(notificationData);
      } else {
        // Fallback si échec de récupération
        _showLocalNotification({
          'title': '❤️ Nouveau like',
          'message': data['message'] ?? 'Quelqu\'un a aimé votre publication',
          'data': data,
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur _handleNewLike: $e');
      // Fallback
      _showLocalNotification({
        'title': '❤️ Nouveau like',
        'message': data['message'] ?? 'Quelqu\'un a aimé votre publication',
        'data': data,
      });
    }
  }

  /// Gérer les nouveaux commentaires avec preview
  Future<void> _handleNewComment(Map<String, dynamic> data) async {
    try {
      final publicationId = data['publicationId'] as String?;
      final commentId = data['commentId'] as String?;

      if (publicationId == null) {
        // Fallback simple
        _showLocalNotification({
          'title': '💬 Nouveau commentaire',
          'message': data['message'] ?? 'Nouveau commentaire sur votre publication',
          'data': data,
        });
        return;
      }

      // Récupérer les détails de la publication pour la preview
      final appProvider = Provider.of<AppProvider>(_appContext!, listen: false);
      final token = appProvider.accessToken;

      if (token == null) return;

      final publicationResult = await ApiService.getPublication(token, publicationId);

      if (publicationResult['success'] == true) {
        final publication = publicationResult['publication'] as Map<String, dynamic>;
        final content = publication['content'] as String? ?? '';
        final media = publication['media'] as List? ?? [];

        // Récupérer le contenu du commentaire si possible
        String commentPreview = '';
        if (commentId != null) {
          try {
            final commentsResult = await ApiService.getPublicationComments(token, publicationId);
            if (commentsResult['success'] == true) {
              final comments = commentsResult['comments'] as List;
              final comment = comments.cast<Map<String, dynamic>>().firstWhere(
                (c) => c['_id'] == commentId,
                orElse: () => {},
              );
              if (comment.isNotEmpty) {
                commentPreview = comment['content'] as String? ?? '';
                // Limiter la longueur du commentaire
                if (commentPreview.length > 50) {
                  commentPreview = '${commentPreview.substring(0, 47)}...';
                }
              }
            }
          } catch (e) {
            debugPrint('❌ Erreur récupération commentaire: $e');
          }
        }

        // Créer la notification avec preview
        final notificationData = {
          'title': '💬 Nouveau commentaire',
          'body': _buildCommentNotificationMessage(data, content, commentPreview, media),
          'data': {
            'type': 'comment',
            'publicationId': publicationId,
            'commentId': commentId,
            'publication': publication, // Inclure les détails pour la preview
          },
        };

        // Ajouter l'image de preview si disponible
        if (media.isNotEmpty) {
          final firstMedia = media[0] as Map<String, dynamic>;
          final mediaUrl = firstMedia['url'] as String?;
          if (mediaUrl != null) {
            (notificationData['data'] as Map<String, dynamic>)['imageUrl'] = mediaUrl;
          }
        }

        await _showLocalNotification(notificationData);
      } else {
        // Fallback si échec de récupération
        _showLocalNotification({
          'title': '💬 Nouveau commentaire',
          'message': data['message'] ?? 'Nouveau commentaire sur votre publication',
          'data': data,
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur _handleNewComment: $e');
      // Fallback
      _showLocalNotification({
        'title': '💬 Nouveau commentaire',
        'message': data['message'] ?? 'Nouveau commentaire sur votre publication',
        'data': data,
      });
    }
  }

  /// Démarrer le polling des notifications
  void startPolling() {
    _lastCheckTime = DateTime.now().subtract(const Duration(hours: 1)); // Vérifier 1h en arrière au démarrage

    // Vérifier immédiatement
    _checkNewNotifications();

    // Puis vérifier toutes les 30 secondes
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkNewNotifications();
    });

    debugPrint('🔄 Polling des notifications démarré');
  }

  /// Arrêter le polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('⏹️ Polling des notifications arrêté');
  }

  /// Vérifier les nouvelles notifications
  Future<void> _checkNewNotifications() async {
    if (_appContext == null || !_appContext!.mounted) return;

    try {
      final appProvider = Provider.of<AppProvider>(_appContext!, listen: false);
      final token = appProvider.accessToken;

      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = data['notifications'] as List? ?? [];

        // Compter les notifications non lues
        final unreadCount = notifications.where((notif) => notif['read'] != true).length;

        // Mettre à jour le badge sur l'icône de l'app
        await updateAppBadge(unreadCount);

        // Filtrer les notifications non lues créées après le dernier check
        final newNotifications = notifications.where((notif) {
          if (notif['read'] == true) return false;
          if (_lastCheckTime == null) return true;

          final createdAt = DateTime.parse(notif['createdAt']);
          return createdAt.isAfter(_lastCheckTime!);
        }).toList();

        // Afficher les nouvelles notifications
        for (var notif in newNotifications) {
          await _showLocalNotification(notif);
        }

        if (newNotifications.isNotEmpty) {
          _lastCheckTime = DateTime.now();
          debugPrint('📬 ${newNotifications.length} nouvelles notifications affichées');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur check notifications: $e');
    }
  }

  /// Mettre à jour le badge sur l'icône de l'application
  Future<void> updateAppBadge(int count) async {
    try {
      // Note: Le badge natif sur l'icône de l'app nécessite un package compatible
      // Pour l'instant, seul le badge in-app (navigation bar) est actif
      debugPrint('🔴 Badge count: $count notifications non lues');
    } catch (e) {
      debugPrint('❌ Erreur mise à jour badge: $e');
    }
  }

  /// Retirer le badge de l'icône de l'application
  Future<void> clearAppBadge() async {
    try {
      debugPrint('✅ Badge effacé');
    } catch (e) {
      debugPrint('❌ Erreur effacement badge: $e');
    }
  }

  /// Demander la permission pour les notifications
  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidImplementation?.requestNotificationsPermission();

      if (granted == true) {
        debugPrint('✅ Permission notifications accordée');
      } else {
        debugPrint('❌ Permission notifications refusée');
      }
    }
  }

  /// Configurer les notifications locales
  Future<void> _setupLocalNotifications() async {
    // Configuration Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    // Configuration iOS (si nécessaire)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer le canal Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'center_notifications',
        'Notifications CENTER',
        description: 'Notifications pour les publications, likes, commentaires, messages',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Canal de notification créé');
    }
  }

  /// Afficher une notification locale
  Future<void> _showLocalNotification(Map<String, dynamic> notificationData) async {
    try {
      final title = notificationData['title'] ?? 'Nouvelle notification';
      final body = notificationData['body'] ?? notificationData['message'] ?? '';
      final id = notificationData['_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final details = _getNotificationDetails(notificationData);

      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: json.encode(notificationData['data'] ?? {}),
      );

      debugPrint('📩 Notification affichée EXTERNE: $title');
      debugPrint('   Message: $body');
    } catch (e) {
      debugPrint('❌ Erreur affichage notification: $e');
    }
  }

  /// Obtenir les détails de la notification selon le type
  NotificationDetails _getNotificationDetails(Map<String, dynamic> notificationData) {
    final type = notificationData['data']?['type'] ?? 'default';
    final imageUrl = notificationData['data']?['imageUrl'];

    // Style de base
    AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
      'center_notifications',
      'Notifications CENTER',
      channelDescription: 'Notifications pour les publications, likes, commentaires, messages',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'CENTER',
      enableVibration: true,
      playSound: true,
      showWhen: true,
      color: Color(0xFF00FF88),
      colorized: true,
    );

    // Adapter selon le type
    if (type == 'publication' && imageUrl != null) {
      // Style avec image pour les publications
      androidDetails = AndroidNotificationDetails(
        'center_notifications',
        'Notifications CENTER',
        channelDescription: 'Notifications pour les publications',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(imageUrl),
          contentTitle: notificationData['title'],
          summaryText: notificationData['body'],
        ),
        color: const Color(0xFF00FF88),
        colorized: true,
      );
    } else if (type == 'comment' || type == 'message') {
      // Style avec texte étendu pour les messages
      androidDetails = AndroidNotificationDetails(
        'center_notifications',
        'Notifications CENTER',
        channelDescription: 'Notifications pour les messages',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          notificationData['body'] ?? '',
          contentTitle: notificationData['title'],
        ),
        color: const Color(0xFF00FF88),
        colorized: true,
      );
    }

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Gérer le clic sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = json.decode(response.payload!);
      final type = data['type'] as String?;

      debugPrint('🔔 Notification cliquée: $type');

      // Navigation selon le type
      switch (type) {
        case 'like':
        case 'publication':
          final publicationId = data['publicationId'] as String?;
          if (publicationId != null) {
            _navigateToPublication(publicationId);
          }
          break;

        case 'comment':
          final publicationId = data['publicationId'] as String?;
          if (publicationId != null) {
            _navigateToComments(publicationId);
          }
          break;

        case 'follower':
          final userId = data['userId'] as String?;
          if (userId != null) {
            _navigateToProfile(userId);
          }
          break;

        case 'message':
          final chatId = data['chatId'] as String?;
          if (chatId != null) {
            _navigateToChat(chatId);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ Erreur traitement notification: $e');
    }
  }

  /// Naviguer vers une publication
  void _navigateToPublication(String publicationId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    debugPrint('📱 Navigation vers publication: $publicationId');

    // Naviguer vers SocialPage (qui affichera toutes les publications)
    // L'utilisateur pourra scroll pour trouver la publication
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SocialPage()),
      (route) => false,
    );
  }

  /// Naviguer vers les commentaires
  void _navigateToComments(String publicationId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    debugPrint('💬 Navigation vers commentaires: $publicationId');

    // Naviguer vers la page des commentaires
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommentsPage(
          publicationId: publicationId,
          publicationContent: '', // Sera chargé depuis l'API
        ),
      ),
    );
  }

  /// Naviguer vers un profil
  void _navigateToProfile(String userId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    debugPrint('👤 Navigation vers profil: $userId');

    // Naviguer vers la page de profil
    // Note: Si c'est le profil de l'utilisateur connecté, on va vers ProfilePage
    // Sinon, il faudrait une page UserProfilePage (à créer)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  /// Naviguer vers un chat
  void _navigateToChat(String chatId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    debugPrint('💬 Navigation vers chat: $chatId');

    // Note: La fonctionnalité de chat n'est pas encore implémentée
    // Pour l'instant, afficher un message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💬 La messagerie sera bientôt disponible'),
        backgroundColor: Color(0xFF00FF88),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Envoyer une notification de test
  Future<void> sendTestNotification() async {
    final testNotification = {
      '_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'title': '🧪 Notification de test',
      'body': 'Ceci est une notification de test du système CENTER',
      'data': {
        'type': 'test',
      },
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _showLocalNotification(testNotification);
  }

  /// Disposer les ressources
  void dispose() {
    stopPolling();
    _appContext = null;
  }

  /// Construire le message de notification pour un like avec preview
  String _buildLikeNotificationMessage(Map<String, dynamic> data, String content, List media) {
    final userName = data['userName'] as String? ?? 'Quelqu\'un';
    final previewText = content.isNotEmpty ? content : 'votre publication';

    // Limiter la longueur du contenu
    final truncatedContent = previewText.length > 30
        ? '${previewText.substring(0, 27)}...'
        : previewText;

    final hasMedia = media.isNotEmpty;
    final mediaType = hasMedia ? '📹 ' : '';

    return '$userName a aimé $mediaType"$truncatedContent"';
  }

  /// Construire le message de notification pour un commentaire avec preview
  String _buildCommentNotificationMessage(Map<String, dynamic> data, String content, String commentPreview, List media) {
    final userName = data['userName'] as String? ?? 'Quelqu\'un';
    final previewText = content.isNotEmpty ? content : 'votre publication';

    // Limiter la longueur du contenu
    final truncatedContent = previewText.length > 30
        ? '${previewText.substring(0, 27)}...'
        : previewText;

    final hasMedia = media.isNotEmpty;
    final mediaType = hasMedia ? '📹 ' : '';

    if (commentPreview.isNotEmpty) {
      return '$userName a commenté $mediaType"$truncatedContent": "$commentPreview"';
    } else {
      return '$userName a commenté $mediaType"$truncatedContent"';
    }
  }
}
