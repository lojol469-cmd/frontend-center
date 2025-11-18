import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
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

import 'create/create_employee_page.dart';
import 'comments_page.dart';
import 'private_chat_notifications_page.dart';
import 'private_chat_page.dart';

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
  
  // Publications récentes pour les commentaires
  List<Map<String, dynamic>> _recentPublications = [];
  bool _isLoadingPublications = false;
  
  // Timer pour auto-refresh des publications
  Timer? _publicationsRefreshTimer;
  
  // Cache des thumbnails vidéo
  final Map<String, Uint8List?> _videoThumbnails = {};

  @override
  void initState() {
    super.initState();
    // Sélectionner une image aléatoire au démarrage
    _selectedImage = _imageManager.getImageForPage('home');

    // Charger les statistiques et les publications récentes
    _loadStats();
    _loadRecentPublications();
    
    // Auto-refresh des publications toutes les 30 secondes
    _publicationsRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadRecentPublications(),
    );
  }
  
  @override
  void dispose() {
    _publicationsRefreshTimer?.cancel();
    super.dispose();
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

      // Charger les notifications de chat privées
      try {
        final conversationsResult = await ApiService.getMessageConversations(token);
        if (conversationsResult['success'] == true && mounted) {
          final conversations = List<Map<String, dynamic>>.from(conversationsResult['conversations'] ?? []);
          // Compter les messages non lus dans toutes les conversations
          final unreadCount = conversations.fold<int>(0, (sum, conv) => sum + ((conv['unreadCount'] ?? 0) as int));
          setState(() {
            _notificationsCount = unreadCount;
          });
        }
      } catch (e) {
        debugPrint('❌ Erreur chargement notifications chat: $e');
      }

    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  /// Charger les publications récentes pour la section commentaires
  Future<void> _loadRecentPublications() async {
    if (!mounted) return;
    
    setState(() => _isLoadingPublications = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;
      
      if (token == null) {
        debugPrint('⚠️ Token manquant');
        return;
      }

      // Charger les publications récentes de tous les utilisateurs
      try {
        final result = await ApiService.getPublications(token, page: 1, limit: 5);
        debugPrint('📊 Publications reçues RAW: $result');
        debugPrint('📊 Type: ${result.runtimeType}');
        debugPrint('📊 Keys: ${result.keys}');
        debugPrint('📊 Success: ${result['success']}');
        
        if (mounted) {
          // Vérifier si on a des publications
          if (result.containsKey('publications')) {
            final pubs = result['publications'] as List? ?? [];
            debugPrint('✅ Nombre de publications: ${pubs.length}');
            
            if (pubs.isNotEmpty) {
              debugPrint('📄 Première publication: ${pubs[0]}');
            }
            
            setState(() {
              _recentPublications = pubs.take(5).map((p) => p as Map<String, dynamic>).toList();
            });
            
            debugPrint('✅ Publications chargées dans _recentPublications: ${_recentPublications.length}');
          } else {
            debugPrint('⚠️ Pas de clé "publications" dans le résultat');
          }
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Erreur chargement publications récentes: $e');
        debugPrint('Stack: $stackTrace');
      }

    } finally {
      if (mounted) {
        setState(() => _isLoadingPublications = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360 || screenHeight < 640;
    final isVerySmallScreen = screenWidth < 320 || screenHeight < 568;

    return Scaffold(
      body: Stack(
        children: [
          ImageBackground(
            imagePath: _selectedImage,
            opacity: 0.30,
            withGradient: false,
            child: RefreshIndicator(
              onRefresh: _loadStats,
              color: themeProvider.primaryColor,
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomScrollView(
                      slivers: [
                        _buildAppBar(),
                        SliverPadding(
                          padding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 16 : 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildWelcomeSection(),
                              SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24),
                              _buildStatsSection(),
                              SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24),
                              _buildQuickActions(),
                              SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24),
                              _buildRecentPublications(),
                              // Bottom padding with safe area consideration to prevent overflow
                              SizedBox(height: max(24.0, MediaQuery.of(context).padding.bottom + 16.0)),
                            ]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Boutons flottants dans le footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bouton chat personnel avec design bulle transparente
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FloatingActionButton(
                          heroTag: 'chat_button',
                          mini: true,
                          backgroundColor: themeProvider.primaryColor.withValues(alpha: 0.1),
                          elevation: 4,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivateChatPage(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: themeProvider.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: themeProvider.primaryColor.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              // Effet bulle de chat
                              boxShadow: [
                                BoxShadow(
                                  color: themeProvider.primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: themeProvider.primaryColor,
                              size: 18,
                            ),
                          ),
                        ),
                        // Petite bulle décorative pour ressembler à une bulle de chat
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: themeProvider.primaryColor.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton notifications avec badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      FloatingActionButton(
                        heroTag: 'notifications_button',
                        mini: true,
                        backgroundColor: themeProvider.primaryColor.withValues(alpha: 0.1),
                        elevation: 4,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivateChatNotificationsPage(),
                            ),
                          ).then((_) {
                            // Recharger les stats après retour de la page notifications
                            _loadStats();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: themeProvider.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: themeProvider.primaryColor,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.notifications_rounded,
                            color: themeProvider.primaryColor,
                            size: 16,
                          ),
                        ),
                      ),
                      // Badge avec le nombre de notifications (style moderne)
                      if (_notificationsCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [themeProvider.secondaryColor, themeProvider.accentColor],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: themeProvider.surfaceColor,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _notificationsCount > 99 ? '99+' : _notificationsCount.toString(),
                              style: TextStyle(
                                color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                                fontSize: 9,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360 || screenHeight < 640;
        final isVerySmallScreen = screenWidth < 320 || screenHeight < 568;

        // Ajuster les tailles pour éviter que les boutons soient trop petits
        final buttonSize = isVerySmallScreen ? 44.0 : isSmallScreen ? 48.0 : 52.0;
        final iconSize = isVerySmallScreen ? 22.0 : isSmallScreen ? 24.0 : 26.0;
        final fontSize = isVerySmallScreen ? 9.5 : isSmallScreen ? 10.5 : 11.0;
        final spacing = isVerySmallScreen ? 10.0 : isSmallScreen ? 12.0 : 16.0;

        return SliverAppBar(
          expandedHeight: isVerySmallScreen ? 90 : isSmallScreen ? 105 : 120,
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
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmallScreen ? 12 : isSmallScreen ? 16 : 24,
                vertical: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 16,
              ),
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
                            width: buttonSize,
                            height: buttonSize,
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
                      SizedBox(width: spacing),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bouton Hub
                              _buildCenterButton(
                                icon: Icons.device_hub,
                                label: 'Hub',
                                onTap: () {
                                  debugPrint('Navigation vers Hub');
                                },
                                size: buttonSize,
                                iconSize: iconSize,
                                fontSize: fontSize,
                              ),
                              SizedBox(width: spacing),
                              // Bouton Live
                              _buildCenterButton(
                                icon: Icons.live_tv,
                                label: 'Live',
                                onTap: () {
                                  debugPrint('Navigation vers Live');
                                },
                                size: buttonSize,
                                iconSize: iconSize,
                                fontSize: fontSize,
                              ),
                              SizedBox(width: spacing),
                              // Bouton Création
                              _buildCenterButton(
                                icon: Icons.create,
                                label: 'Création',
                                onTap: () {
                                  debugPrint('Navigation vers Création');
                                },
                                size: buttonSize,
                                iconSize: iconSize,
                                fontSize: fontSize,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Boutons supprimés de l'app bar - déplacés vers le footer flottant

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
                          color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? Colors.grey[300] : Colors.grey[800],
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
                          color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? Colors.grey[200] : Colors.grey[700],
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
                          color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? Colors.grey[300] : Colors.grey[700],
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
                color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? Colors.grey[200] : Colors.grey[800],
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

  Widget _buildRecentPublications() {
    // Prendre seulement la première publication (la plus récente)
    final latestPublication = _recentPublications.isNotEmpty ? _recentPublications.first : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Publications récentes',
              style: TextStyle(
                color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? Colors.grey[200] : Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (latestPublication != null)
              TextButton.icon(
                onPressed: _loadRecentPublications,
                icon: Icon(
                  Icons.refresh,
                  color: Color(0xFF00D4FF),
                  size: 18,
                ),
                label: Text(
                  'Actualiser',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FuturisticCard(
          child: _isLoadingPublications
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00D4FF),
                    ),
                  ),
                )
              : latestPublication == null
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
                              'Aucune publication',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadRecentPublications,
                              child: Text(
                                'Réessayer',
                                style: TextStyle(color: Color(0xFF00D4FF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildPublicationPreview(latestPublication),
        ),
      ],
    );
  }
  
  /// Générer un thumbnail pour une vidéo
  Future<Uint8List?> _generateVideoThumbnail(String videoUrl) async {
    // Vérifier le cache
    if (_videoThumbnails.containsKey(videoUrl)) {
      return _videoThumbnails[videoUrl];
    }

    try {
      debugPrint('🎬 Génération thumbnail pour: $videoUrl');
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 85,
      );
      
      if (thumbnail != null) {
        debugPrint('✅ Thumbnail généré: ${thumbnail.length} bytes');
        _videoThumbnails[videoUrl] = thumbnail;
      }
      
      return thumbnail;
    } catch (e) {
      debugPrint('❌ Erreur génération thumbnail: $e');
      _videoThumbnails[videoUrl] = null;
      return null;
    }
  }
  
  /// Widget pour afficher la preview d'une publication
  Widget _buildPublicationPreview(Map<String, dynamic> publication) {
    final publicationId = publication['_id'] ?? 'unknown';
    final content = publication['content'] ?? publication['text'] ?? '';
    final userId = publication['userId'];
    final userName = userId is Map ? userId['name'] ?? 'Utilisateur' : 'Utilisateur';
    final profileImage = userId is Map ? userId['profileImage'] ?? '' : '';
    final media = publication['media'] as List? ?? [];
    final hasMedia = media.isNotEmpty;
    final firstMedia = hasMedia ? media[0] as Map<String, dynamic> : null;
    final mediaType = firstMedia?['type'] ?? '';
    final mediaUrl = firstMedia?['url'] ?? '';
    final commentsCount = (publication['comments'] as List?)?.length ?? 0;
    final likesCount = (publication['likes'] as List?)?.length ?? 0;
    final createdAt = publication['createdAt'] != null
        ? DateTime.parse(publication['createdAt'])
        : DateTime.now();
    final timeAgo = _formatTimeAgo(createdAt);
    
    return InkWell(
      onTap: () {
        debugPrint('🔗 Navigation vers publication: $publicationId');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommentsPage(
              publicationId: publicationId,
              publicationContent: content,
            ),
          ),
        ).then((_) => _loadRecentPublications());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview média en grand (si disponible)
          if (hasMedia)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: Colors.black87,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: mediaType == 'image' && mediaUrl.isNotEmpty
                        ? Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              child: Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.black26,
                              ),
                            ),
                          )
                        : mediaType == 'video' && mediaUrl.isNotEmpty
                            ? FutureBuilder<Uint8List?>(
                                future: _generateVideoThumbnail(mediaUrl),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      color: Colors.black87,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF00D4FF),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        ),
                                        // Overlay play button
                                        Container(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          child: Center(
                                            child: Container(
                                              padding: EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.play_arrow,
                                                size: 48,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  
                                  // Fallback si pas de thumbnail
                                  return Container(
                                    color: Colors.black87,
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        size: 64,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.black12,
                                child: Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.black26,
                                ),
                              ),
                  ),
                  // Gradient overlay pour le texte
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Compteur de médias si plusieurs
                  if (media.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.collections,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${media.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Badge "NOUVEAU"
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'NOUVEAU',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Informations de la publication
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête: avatar + nom + temps
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: profileImage.isNotEmpty
                          ? NetworkImage(profileImage)
                          : null,
                      backgroundColor: const Color(0xFF00D4FF),
                      child: profileImage.isEmpty
                          ? const Icon(Icons.person, size: 20, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF00D4FF),
                      size: 18,
                    ),
                  ],
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: hasMedia ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                // Actions: likes + commentaires
                Row(
                  children: [
                    if (likesCount > 0) ...[
                      Icon(Icons.favorite, size: 18, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        likesCount.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                    Icon(
                      Icons.chat_bubble,
                      size: 18,
                      color: Color(0xFF00D4FF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      commentsCount > 0
                          ? '$commentsCount ${commentsCount > 1 ? "commentaires" : "commentaire"}'
                          : 'Commenter',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF00D4FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF00D4FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Voir plus',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00D4FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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

  /// Widget pour créer un bouton centré avec design transparent
  Widget _buildCenterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double size = 50,
    double iconSize = 24,
    double fontSize = 10,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeProvider.primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: themeProvider.primaryColor,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: themeProvider.primaryColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
