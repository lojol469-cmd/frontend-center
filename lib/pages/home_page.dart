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
import 'setraf_landing_page.dart';

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
                    // Responsive breakpoints
                    final isSmallScreen = constraints.maxWidth < 360 || constraints.maxHeight < 640;
                    final isVerySmallScreen = constraints.maxWidth < 320 || constraints.maxHeight < 568;
                    final isTablet = constraints.maxWidth >= 600;
                    
                    return CustomScrollView(
                      slivers: [
                        _buildAppBar(constraints, isSmallScreen, isVerySmallScreen, isTablet),
                        SliverPadding(
                          padding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 16 : isTablet ? 32 : 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildWelcomeSection(constraints, isSmallScreen, isVerySmallScreen, isTablet),
                              SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : isTablet ? 32 : 24),
                              _buildStatsSection(constraints, isSmallScreen, isVerySmallScreen, isTablet),
                              SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : isTablet ? 32 : 24),
                              _buildQuickActions(constraints, isSmallScreen, isVerySmallScreen, isTablet),
                              SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 20 : isTablet ? 32 : 24),
                              _buildRecentPublications(constraints, isSmallScreen, isVerySmallScreen, isTablet),
                              // Bottom padding with safe area consideration to prevent overflow
                              SizedBox(height: max(24.0, MediaQuery.of(context).padding.bottom + (isVerySmallScreen ? 12 : isSmallScreen ? 16 : 16.0))),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 360 || constraints.maxHeight < 640;
                final isVerySmallScreen = constraints.maxWidth < 320 || constraints.maxHeight < 568;
                
                // Calculer la hauteur de la BottomNavigationBar (environ 56-80px selon la plateforme)
                // et ajouter le padding de safe area
                final bottomNavBarHeight = isVerySmallScreen ? 56 : isSmallScreen ? 60 : 64;
                final safeAreaBottom = MediaQuery.of(context).padding.bottom;
                final totalBottomOffset = bottomNavBarHeight + safeAreaBottom + (isVerySmallScreen ? 8 : isSmallScreen ? 12 : 16);
                
                return Container(
                  margin: EdgeInsets.only(bottom: totalBottomOffset),
                  padding: EdgeInsets.only(
                    bottom: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                    left: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24,
                    right: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24,
                    top: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bouton chat personnel avec design bulle transparente
                      Container(
                        margin: EdgeInsets.only(right: isVerySmallScreen ? 6 : isSmallScreen ? 7 : 8),
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
                                padding: EdgeInsets.all(isVerySmallScreen ? 6 : isSmallScreen ? 7 : 8),
                                decoration: BoxDecoration(
                                  color: themeProvider.primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12),
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
                                  size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                                ),
                              ),
                            ),
                            // Petite bulle décorative pour ressembler à une bulle de chat
                            Positioned(
                              top: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6,
                              right: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6,
                              child: Container(
                                width: isVerySmallScreen ? 4 : isSmallScreen ? 4.5 : 5,
                                height: isVerySmallScreen ? 4 : isSmallScreen ? 4.5 : 5,
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
                              padding: EdgeInsets.all(isVerySmallScreen ? 5 : isSmallScreen ? 6 : 6),
                              decoration: BoxDecoration(
                                color: themeProvider.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : isSmallScreen ? 9 : 10),
                                border: Border.all(
                                  color: themeProvider.primaryColor,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_rounded,
                                color: themeProvider.primaryColor,
                                size: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                              ),
                            ),
                          ),
                          // Badge avec le nombre de notifications (style moderne)
                          if (_notificationsCount > 0)
                            Positioned(
                              right: isVerySmallScreen ? 3 : isSmallScreen ? 3.5 : 4,
                              top: isVerySmallScreen ? 3 : isSmallScreen ? 3.5 : 4,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 3 : isSmallScreen ? 3.5 : 4,
                                  vertical: isVerySmallScreen ? 1 : isSmallScreen ? 1 : 1,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [themeProvider.secondaryColor, themeProvider.accentColor],
                                  ),
                                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : isSmallScreen ? 7 : 8),
                                  border: Border.all(
                                    color: themeProvider.surfaceColor,
                                    width: isVerySmallScreen ? 1 : isSmallScreen ? 1.2 : 1.5,
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 16,
                                  minHeight: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 16,
                                ),
                                child: Text(
                                  _notificationsCount > 99 ? '99+' : _notificationsCount.toString(),
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                                    fontSize: isVerySmallScreen ? 7.5 : isSmallScreen ? 8 : 9,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BoxConstraints constraints, bool isSmallScreen, bool isVerySmallScreen, bool isTablet) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Ajuster les tailles pour éviter que les boutons soient trop petits
        final buttonSize = isVerySmallScreen ? 40.0 : isSmallScreen ? 44.0 : isTablet ? 56.0 : 48.0;
        final iconSize = isVerySmallScreen ? 18.0 : isSmallScreen ? 20.0 : isTablet ? 28.0 : 22.0;
        final fontSize = isVerySmallScreen ? 8.5 : isSmallScreen ? 9.5 : isTablet ? 12.0 : 10.0;
        final spacing = isVerySmallScreen ? 8.0 : isSmallScreen ? 10.0 : isTablet ? 18.0 : 12.0;

        return SliverAppBar(
          expandedHeight: isVerySmallScreen ? 80 : isSmallScreen ? 90 : isTablet ? 130 : 105,
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
                horizontal: isVerySmallScreen ? 10 : isSmallScreen ? 14 : isTablet ? 32 : 20,
                vertical: isVerySmallScreen ? 8 : isSmallScreen ? 10 : isTablet ? 18 : 12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // Logo SETRAF dans un cercle avec badge de notification
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SetrafLandingPage(),
                            ),
                          );
                        },
                        child: Stack(
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
                                right: -3,
                                top: -3,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6,
                                    vertical: isVerySmallScreen ? 2 : isSmallScreen ? 2.5 : 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [themeProvider.secondaryColor, themeProvider.accentColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12),
                                    border: Border.all(
                                      color: themeProvider.surfaceColor,
                                      width: isVerySmallScreen ? 2 : isSmallScreen ? 2.2 : 2.5,
                                    ),
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: isVerySmallScreen ? 18 : isSmallScreen ? 20 : 22,
                                    minHeight: isVerySmallScreen ? 18 : isSmallScreen ? 20 : 22,
                                  ),
                                  child: Text(
                                    _notificationsCount > 99 ? '99+' : _notificationsCount.toString(),
                                    style: TextStyle(
                                      color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                                      fontSize: isVerySmallScreen ? 9 : isSmallScreen ? 10 : 11,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildWelcomeSection(BoxConstraints constraints, bool isSmallScreen, bool isVerySmallScreen, bool isTablet) {
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
            padding: EdgeInsets.all(isVerySmallScreen ? 16 : isSmallScreen ? 20 : isTablet ? 32 : 24),
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
                          fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 18 : 16,
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 2 : isSmallScreen ? 3 : 4),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                        ).createShader(bounds),
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 20 : isSmallScreen ? 24 : isTablet ? 36 : 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 6 : isSmallScreen ? 7 : 8),
                      Text(
                        'Prêt à conquérir cette journée ?',
                        style: TextStyle(
                          color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? Colors.grey[200] : Colors.grey[700],
                          fontSize: isVerySmallScreen ? 11 : isSmallScreen ? 12 : isTablet ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: isVerySmallScreen ? 60 : isSmallScreen ? 70 : isTablet ? 100 : 80,
                  height: isVerySmallScreen ? 60 : isSmallScreen ? 70 : isTablet ? 100 : 80,
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
                          size: isVerySmallScreen ? 30 : isSmallScreen ? 35 : isTablet ? 50 : 40,
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

  Widget _buildStatsSection(BoxConstraints constraints, bool isSmallScreen, bool isVerySmallScreen, bool isTablet) {
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
                    fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 18 : isTablet ? 24 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_isLoadingStats)
                  SizedBox(
                    width: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                    height: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                    child: CircularProgressIndicator(
                      strokeWidth: isVerySmallScreen ? 1.5 : isSmallScreen ? 1.8 : 2,
                      valueColor: AlwaysStoppedAnimation<Color>(themeProvider.primaryColor),
                    ),
                  ),
              ],
            ),
            SizedBox(height: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
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
                SizedBox(width: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
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
            SizedBox(height: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
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
                SizedBox(width: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
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

  Widget _buildQuickActions(BoxConstraints constraints, bool isSmallScreen, bool isVerySmallScreen, bool isTablet) {
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
                fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 18 : isTablet ? 24 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isTablet ? 3 : 2,
              crossAxisSpacing: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16,
              mainAxisSpacing: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16,
              childAspectRatio: isTablet ? 1.6 : 1.4,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentPublications(BoxConstraints constraints, bool isSmallScreen, bool isVerySmallScreen, bool isTablet) {
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
                fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 18 : isTablet ? 24 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (latestPublication != null)
              TextButton.icon(
                onPressed: _loadRecentPublications,
                icon: Icon(
                  Icons.refresh,
                  color: Color(0xFF00D4FF),
                  size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                ),
                label: Text(
                  'Actualiser',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: isVerySmallScreen ? 11 : isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
        FuturisticCard(
          child: _isLoadingPublications
              ? Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 24 : isSmallScreen ? 28 : isTablet ? 40 : 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00D4FF),
                    ),
                  ),
                )
              : latestPublication == null
                  ? Padding(
                      padding: EdgeInsets.all(isVerySmallScreen ? 24 : isSmallScreen ? 28 : isTablet ? 40 : 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: isVerySmallScreen ? 36 : isSmallScreen ? 42 : isTablet ? 60 : 48,
                              color: Colors.black26,
                            ),
                            SizedBox(height: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                            Text(
                              'Aucune publication',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                              ),
                            ),
                            SizedBox(height: isVerySmallScreen ? 6 : isSmallScreen ? 7 : 8),
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
                  : _buildPublicationPreview(latestPublication, isSmallScreen, isVerySmallScreen, isTablet),
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
  Widget _buildPublicationPreview(Map<String, dynamic> publication, bool isSmallScreen, bool isVerySmallScreen, bool isTablet) {
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
              height: isVerySmallScreen ? 150 : isSmallScreen ? 180 : isTablet ? 250 : 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                  topRight: Radius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                ),
                color: Colors.black87,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                      topRight: Radius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                    ),
                    child: mediaType == 'image' && mediaUrl.isNotEmpty
                        ? Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              child: Icon(
                                Icons.broken_image,
                                size: isVerySmallScreen ? 32 : isSmallScreen ? 40 : 48,
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
                                              padding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.play_arrow,
                                                size: isVerySmallScreen ? 36 : isSmallScreen ? 42 : 48,
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
                                        size: isVerySmallScreen ? 48 : isSmallScreen ? 56 : 64,
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
                                  size: isVerySmallScreen ? 32 : isSmallScreen ? 40 : 48,
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
                      height: isVerySmallScreen ? 60 : isSmallScreen ? 70 : 80,
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
                      top: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12,
                      right: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 6 : isSmallScreen ? 8 : 10, vertical: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.collections,
                              size: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: isVerySmallScreen ? 3 : isSmallScreen ? 3.5 : 4),
                            Text(
                              '${media.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Badge "NOUVEAU"
                  Positioned(
                    top: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12,
                    left: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 6 : isSmallScreen ? 8 : 10, vertical: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20),
                      ),
                      child: Text(
                        'NOUVEAU',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: isVerySmallScreen ? 9 : isSmallScreen ? 10 : 11,
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
            padding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 14 : isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête: avatar + nom + temps
                Row(
                  children: [
                    CircleAvatar(
                      radius: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                      backgroundImage: profileImage.isNotEmpty
                          ? NetworkImage(profileImage)
                          : null,
                      backgroundColor: const Color(0xFF00D4FF),
                      child: profileImage.isEmpty
                          ? Icon(Icons.person, size: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20, color: Colors.white)
                          : null,
                    ),
                    SizedBox(width: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: isVerySmallScreen ? 13 : isSmallScreen ? 14 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF00D4FF),
                      size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                    ),
                  ],
                ),
                if (content.isNotEmpty) ...[
                  SizedBox(height: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 13 : 14,
                      height: 1.5,
                    ),
                    maxLines: hasMedia ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16),
                // Actions: likes + commentaires
                Row(
                  children: [
                    if (likesCount > 0) ...[
                      Icon(Icons.favorite, size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18, color: Colors.red),
                      SizedBox(width: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6),
                      Text(
                        likesCount.toString(),
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 13 : 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20),
                    ],
                    Icon(
                      Icons.chat_bubble,
                      size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                      color: Color(0xFF00D4FF),
                    ),
                    SizedBox(width: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6),
                    Text(
                      commentsCount > 0
                          ? '$commentsCount ${commentsCount > 1 ? "commentaires" : "commentaire"}'
                          : 'Commenter',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 13 : 14,
                        color: Color(0xFF00D4FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12, vertical: isVerySmallScreen ? 4 : isSmallScreen ? 5 : 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF00D4FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20),
                      ),
                      child: Text(
                        'Voir plus',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 12,
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
