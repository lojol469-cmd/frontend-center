import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../theme/theme_provider.dart';
import '../components/futuristic_card.dart';
import '../components/stats_card.dart';
import '../components/quick_action_card.dart';
import '../components/image_background.dart';
import '../utils/background_image_manager.dart';
import 'social_page.dart';
import 'map_view_page.dart';
import 'admin_page.dart';
import 'notifications_list_page.dart';
import 'create/create_employee_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late String _selectedImage;
  final BackgroundImageManager _imageManager = BackgroundImageManager();

  // Statistiques dynamiques
  bool _isLoadingStats = false;
  int _employeesCount = 0;
  int _publicationsCount = 0;
  int _markersCount = 0;
  int _notificationsCount = 0;
  List<Map<String, dynamic>> _recentPublications = [];

  @override
  void initState() {
    super.initState();
    // Sélectionner une image aléatoire au démarrage
    _selectedImage = _imageManager.getImageForPage('home');

    // Charger les statistiques
    _loadStats();
  }

  /// Charger toutes les statistiques depuis l'API
  Future<void> _loadStats() async {
    if (!mounted) return;
    
    setState(() => _isLoadingStats = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;
      
      if (token == null) return;

      // Charger les statistiques globales
      try {
        final statsResult = await ApiService.getStats(token);
        if (mounted) {
          setState(() {
            // L'API retourne stats.employees.total, stats.publications.total, etc.
            _employeesCount = statsResult['employees']?['total'] ?? 0;
            _publicationsCount = statsResult['publications']?['total'] ?? 0;
            _markersCount = statsResult['markers']?['total'] ?? 0;
          });
        }
      } catch (e) {
        debugPrint('❌ Erreur chargement stats: $e');
      }

      // Charger les notifications
      try {
        final notifsResult = await ApiService.getNotifications(token);
        if (notifsResult['success'] == true && mounted) {
          setState(() {
            _notificationsCount = notifsResult['unreadCount'] ?? 0;
          });
        }
      } catch (e) {
        debugPrint('❌ Erreur chargement notifications: $e');
      }

      // Charger les publications récentes PERSONNELLES
      try {
        final pubsResult = await ApiService.getMyPublications(token, page: 1, limit: 5);
        if (pubsResult['success'] == true && mounted) {
          final pubs = pubsResult['publications'] as List? ?? [];
          setState(() {
            _recentPublications = pubs.take(5).map((p) => p as Map<String, dynamic>).toList();
          });
        }
      } catch (e) {
        debugPrint('❌ Erreur chargement publications récentes: $e');
      }

    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      body: ImageBackground(
        imagePath: _selectedImage,
        opacity: 0.30,
        withGradient: false,
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: themeProvider.primaryColor,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildWelcomeSection(),
                      const SizedBox(height: 32),
                      _buildStatsSection(),
                      const SizedBox(height: 32),
                      _buildQuickActions(),
                      const SizedBox(height: 32),
                      _buildRecentActivity(),
                      SizedBox(height: 100 + MediaQuery.of(context).padding.bottom),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SliverAppBar(
          expandedHeight: 120,
          floating: true,
          pinned: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeProvider.surfaceColor,
                    themeProvider.surfaceColor.withValues(alpha: 0.9),
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // Logo SETRAF dans un cercle avec badge de notification
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: themeProvider.gradient,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          // Badge de notification style TikTok/Facebook
                          if (_notificationsCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [themeProvider.secondaryColor, themeProvider.accentColor],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: themeProvider.surfaceColor,
                                    width: 2.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 22,
                                  minHeight: 22,
                                ),
                                child: Text(
                                  _notificationsCount > 99 ? '99+' : _notificationsCount.toString(),
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tableau de bord',
                              style: TextStyle(
                                color: themeProvider.textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Vue d\'ensemble de votre activité',
                              style: TextStyle(
                                color: themeProvider.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bouton notifications avec badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsListPage(),
                                ),
                              ).then((_) {
                                // Recharger les stats après retour de la page notifications
                                _loadStats();
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeProvider.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: themeProvider.primaryColor,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_rounded,
                                color: themeProvider.primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                          // Badge avec le nombre de notifications (style moderne)
                          if (_notificationsCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [themeProvider.secondaryColor, themeProvider.accentColor],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: themeProvider.surfaceColor,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Text(
                                  _notificationsCount > 99 ? '99+' : _notificationsCount.toString(),
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final user = appProvider.currentUser;
        final userName = user?['name'] ?? 'Utilisateur';
        final userAvatar = user?['profileImage'];
        
        // Vérifier si l'avatar contient déjà l'URL complète ou juste le chemin
        final avatarUrl = userAvatar != null && userAvatar.isNotEmpty
            ? (userAvatar.startsWith('http') 
                ? userAvatar // URL complète déjà présente
                : '${ApiService.baseUrl}$userAvatar') // Ajouter baseUrl si nécessaire
            : null;
        
        // Debug: afficher les infos utilisateur
        debugPrint('👤 User info: name=$userName, avatar=$avatarUrl');
        
        return FuturisticCard(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour,',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                        ).createShader(bounds),
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Prêt à conquérir cette journée ?',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarUrl == null
                        ? const LinearGradient(
                            colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                          )
                        : null,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                            onError: (exception, stackTrace) {
                              debugPrint('❌ Erreur chargement avatar: $exception');
                            },
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Statistiques en temps réel',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_isLoadingStats)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(themeProvider.primaryColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Employés',
                    value: _employeesCount.toString(),
                    icon: Icons.groups_rounded,
                    color: themeProvider.primaryColor,
                    trend: '+12%',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    title: 'Publications',
                    value: _publicationsCount.toString(),
                    icon: Icons.article_rounded,
                    color: themeProvider.secondaryColor,
                    trend: '+8%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Marqueurs',
                    value: _markersCount.toString(),
                    icon: Icons.location_on_rounded,
                    color: themeProvider.accentColor,
                    trend: '+3%',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    title: 'Notifications',
                    value: _notificationsCount.toString(),
                    icon: Icons.notifications_rounded,
                    color: themeProvider.primaryColor,
                    trend: _notificationsCount > 0 ? 'Nouvelles!' : '',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final user = appProvider.currentUser;
        final isAdmin = user?['role'] == 'admin' || user?['isAdmin'] == true;
        
        // Liste de toutes les actions
        final List<Widget> actions = [
          // Action pour tout le monde: Publier Contenu
          QuickActionCard(
            title: 'Publier\nContenu',
            icon: Icons.edit_rounded,
            color: const Color(0xFF00CC66),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocialPage()),
              );
            },
          ),
          // Action pour tout le monde: Ajouter Marqueur
          QuickActionCard(
            title: 'Ajouter\nMarqueur',
            icon: Icons.add_location_rounded,
            color: const Color(0xFF009944),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapViewPage()),
              );
            },
          ),
        ];

        // Ajouter les actions admin seulement si l'utilisateur est admin
        if (isAdmin) {
          actions.insertAll(0, [
            QuickActionCard(
              title: 'Nouveau\nEmployé',
              icon: Icons.person_add_rounded,
              color: const Color(0xFF00FF88),
              onTap: () {
                final token = appProvider.accessToken;
                if (token != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateEmployeePage()),
                  ).then((_) => _loadStats());
                }
              },
            ),
          ]);
          
          actions.add(
            QuickActionCard(
              title: 'Rapport\nAnalyse',
              icon: Icons.analytics_rounded,
              color: const Color(0xFF00FF88),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                );
              },
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions rapides',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité récente',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        FuturisticCard(
          child: _recentPublications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune activité récente',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: _recentPublications.asMap().entries.map((entry) {
                    final index = entry.key;
                    final pub = entry.value;
                    
                    final userId = pub['userId'];
                    final userName = userId is Map ? userId['name'] ?? 'Utilisateur' : 'Utilisateur';
                    final text = pub['text'] ?? '';
                    final createdAt = pub['createdAt'] != null
                        ? DateTime.parse(pub['createdAt'])
                        : DateTime.now();
                    final timeAgo = _formatTimeAgo(createdAt);
                    final hasLocation = pub['location'] != null;
                    final likesCount = (pub['likes'] as List?)?.length ?? 0;
                    final commentsCount = (pub['comments'] as List?)?.length ?? 0;

                    return Column(
                      children: [
                        if (index > 0) Divider(color: Colors.black.withValues(alpha: 0.1)),
                        _buildActivityItem(
                          icon: hasLocation ? Icons.location_on_rounded : Icons.article_rounded,
                          title: userName,
                          subtitle: text.length > 50 ? '${text.substring(0, 50)}...' : text,
                          time: timeAgo,
                          color: hasLocation ? const Color(0xFF009944) : const Color(0xFF00CC66),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (likesCount > 0) ...[
                                Icon(Icons.favorite, size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  likesCount.toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (commentsCount > 0) ...[
                                Icon(Icons.comment, size: 16, color: Color(0xFF00FF88)),
                                const SizedBox(width: 4),
                                Text(
                                  commentsCount.toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  /// Formater le temps écoulé
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return 'Il y a ${(difference.inDays / 7).floor()}sem';
    }
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(height: 4),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
