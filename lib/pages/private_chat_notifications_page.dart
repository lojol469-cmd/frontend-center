import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../theme/theme_provider.dart';
import 'chat_conversation_page.dart';

class PrivateChatNotificationsPage extends StatefulWidget {
  const PrivateChatNotificationsPage({super.key});

  @override
  State<PrivateChatNotificationsPage> createState() => _PrivateChatNotificationsPageState();
}

class _PrivateChatNotificationsPageState extends State<PrivateChatNotificationsPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _unreadConversations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUnreadConversations();
    _listenToWebSocket();

    // Rafraîchir les conversations toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadConversations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _listenToWebSocket() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.webSocketStream.listen((message) {
      if (!mounted) return;

      if (message['type'] == 'new_message') {
        // Un nouveau message a été envoyé, rafraîchir les conversations
        _loadUnreadConversations();
      }
    });
  }

  Future<void> _loadUnreadConversations() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      final result = await ApiService.getMessageConversations(token);
      if (mounted) {
        final conversations = List<Map<String, dynamic>>.from(result['conversations'] ?? []);
        // Filtrer seulement les conversations avec des messages non lus
        setState(() {
          _unreadConversations = conversations.where((conv) => (conv['unreadCount'] ?? 0) > 0).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement conversations non lues: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeProvider.primaryColor.withValues(alpha: 0.9),
                themeProvider.primaryColor.withValues(alpha: 0.7),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications de chat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
            onPressed: _loadUnreadConversations,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeProvider.primaryColor.withValues(alpha: 0.1),
              themeProvider.backgroundColor,
              themeProvider.backgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Espace pour l'app bar transparente
            const SizedBox(height: kToolbarHeight + 20),

            // Contenu principal
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          color: themeProvider.primaryColor,
                        ),
                      ),
                    )
                  : _unreadConversations.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadUnreadConversations,
                          color: themeProvider.primaryColor,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _unreadConversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _unreadConversations[index];
                              return _buildNotificationTile(conversation);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> conversation) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userName = conversation['userName'] ?? 'Utilisateur';
    final userImage = conversation['userImage'] ?? '';
    final lastMessage = conversation['lastMessage'] ?? '';
    final lastMessageTime = conversation['lastMessageTime'];
    final unreadCount = conversation['unreadCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    themeProvider.primaryColor.withValues(alpha: 0.8),
                    themeProvider.secondaryColor.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: userImage.isNotEmpty ? NetworkImage(userImage) : null,
                backgroundColor: Colors.transparent,
                child: userImage.isEmpty
                    ? Text(
                        userName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
            ),
            // Badge avec le nombre de messages non lus
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          userName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Preview du dernier message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                lastMessage.length > 100
                    ? '${lastMessage.substring(0, 100)}...'
                    : lastMessage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (lastMessageTime != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatTime(lastMessageTime),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeProvider.primaryColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble,
            color: Colors.white,
            size: 20,
          ),
        ),
        onTap: () {
          // Naviguer vers la conversation de chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationPage(
                userId: conversation['userId'],
                userName: userName,
                userImage: userImage,
              ),
            ),
          ).then((_) => _loadUnreadConversations());
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeProvider.primaryColor.withValues(alpha: 0.2),
                    themeProvider.secondaryColor.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: themeProvider.primaryColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune notification',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous n\'avez pas de nouveaux messages privés',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final date = timestamp is String
          ? DateTime.parse(timestamp)
          : DateTime.fromMillisecondsSinceEpoch(timestamp);

      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'À l\'instant';
      }
      if (diff.inHours < 1) {
        return '${diff.inMinutes} min';
      }
      if (diff.inDays < 1) {
        return '${diff.inHours}h';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays}j';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}