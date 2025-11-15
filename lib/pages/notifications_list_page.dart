import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../components/futuristic_card.dart';
import 'package:intl/intl.dart';
import 'social_page.dart';
import 'profile_page.dart';

class NotificationsListPage extends StatefulWidget {
  const NotificationsListPage({super.key});

  @override
  State<NotificationsListPage> createState() => _NotificationsListPageState();
}

class _NotificationsListPageState extends State<NotificationsListPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;
      
      if (token == null) return;

      final result = await ApiService.getNotifications(token);
      
      if (result['success'] == true && mounted) {
        setState(() {
          _notifications = result['notifications'] ?? [];
          _unreadCount = result['unreadCount'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement notifications: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;
      
      if (token == null) return;

      final result = await ApiService.markNotificationAsRead(token, notificationId);
      
      if (result['success'] == true && mounted) {
        // Mettre à jour localement
        setState(() {
          final index = _notifications.indexWhere((n) => n['_id'] == notificationId);
          if (index != -1) {
            _notifications[index]['read'] = true;
            if (_unreadCount > 0) _unreadCount--;
          }
        });
        
        // Mettre à jour le badge de l'app
        _updateAppBadge();
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage notification: $e');
    }
  }

  /// Mettre à jour le badge sur l'icône de l'app
  /// Note: Sur Android, les badges sont gérés automatiquement par les notifications
  Future<void> _updateAppBadge() async {
    try {
      debugPrint('🔴 Badge count: $_unreadCount notifications non lues');
      // Le badge est géré automatiquement par le système Android
    } catch (e) {
      debugPrint('❌ Erreur mise à jour badge: $e');
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'À l\'instant';
      } else if (diff.inMinutes < 60) {
        return 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Il y a ${diff.inHours}h';
      } else if (diff.inDays < 7) {
        return 'Il y a ${diff.inDays}j';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follower':
        return Icons.person_add;
      case 'message':
        return Icons.message;
      case 'publication':
        return Icons.article;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return const Color(0xFF00FF88);
      case 'follower':
        return Colors.blue;
      case 'message':
        return Colors.purple;
      case 'publication':
        return const Color(0xFF00CC66);
      default:
        return const Color(0xFF00FF88);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vous êtes à jour !',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF00FF88),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isRead = notification['read'] == true;
                      final type = notification['data']?['type'] ?? 'default';
                      final title = notification['title'] ?? '';
                      final body = notification['body'] ?? '';
                      final createdAt = notification['createdAt'] ?? '';
                      final notificationId = notification['_id'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FuturisticCard(
                          child: InkWell(
                            onTap: () {
                              if (!isRead) {
                                _markAsRead(notificationId);
                              }
                              
                              // Navigation selon le type de notification
                              final notifData = notification['data'];
                              final type = notifData?['type'] ?? '';
                              
                              switch (type) {
                                case 'like':
                                case 'publication':
                                  // Navigation vers la page sociale (liste des publications)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SocialPage(),
                                    ),
                                  );
                                  break;
                                  
                                case 'comment':
                                  // Navigation vers la page sociale (pour l'instant)
                                  // Car CommentsPage nécessite publicationContent qu'on n'a pas ici
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SocialPage(),
                                    ),
                                  );
                                  break;
                                  
                                case 'follower':
                                  // Navigation vers votre profil (ProfilePage n'a pas de paramètre userId)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfilePage(),
                                    ),
                                  );
                                  break;
                                  
                                case 'message':
                                  // Pour les messages, afficher un message pour l'instant
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Fonctionnalité de chat à venir'),
                                      backgroundColor: Colors.purple,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  break;
                                  
                                default:
                                  // Type inconnu, ne rien faire
                                  break;
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : const Color(0xFF00FF88).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icône
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(type).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _getNotificationColor(type).withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(type),
                                      color: _getNotificationColor(type),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Contenu
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(left: 8),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00FF88),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          body,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDate(createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
