import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../components/futuristic_card.dart';
import '../components/stats_card.dart';
import '../components/quick_action_card.dart';
import '../components/image_background.dart';
import '../utils/background_image_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late String _selectedImage;
  final BackgroundImageManager _imageManager = BackgroundImageManager();

  @override
  void initState() {
    super.initState();
    // Sélectionner une image aléatoire au démarrage
    _selectedImage = _imageManager.getImageForPage('home');
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ImageBackground(
        imagePath: _selectedImage,
        opacity: 0.35, // Augmenté pour plus de vivacité
        withGradient: true,
        gradientColor: Colors.white,
        child: SafeArea(
          bottom: false, // Ne pas appliquer SafeArea en bas, on le gère manuellement
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
                    SizedBox(height: 100 + MediaQuery.of(context).padding.bottom), // Padding bottom système
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
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
                Colors.white,
                Colors.white.withValues(alpha: 0.9),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF88).withValues(alpha: _pulseAnimation.value),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.dashboard_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tableau de bord',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Vue d\'ensemble de votre activité',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00FF88),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFF00FF88),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final user = appProvider.currentUser;
        final userName = user?['name'] ?? 'Utilisateur';
        
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques en temps réel',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Employés',
                value: '142',
                icon: Icons.groups_rounded,
                color: const Color(0xFF00FF88),
                trend: '+12%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatsCard(
                title: 'Publications',
                value: '89',
                icon: Icons.article_rounded,
                color: const Color(0xFF00CC66),
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
                value: '24',
                icon: Icons.location_on_rounded,
                color: const Color(0xFF009944),
                trend: '+3%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatsCard(
                title: 'Messages',
                value: '356',
                icon: Icons.chat_rounded,
                color: const Color(0xFF00FF88),
                trend: '+24%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
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
          childAspectRatio: 1.5,
          children: [
            QuickActionCard(
              title: 'Nouveau\nEmployé',
              icon: Icons.person_add_rounded,
              color: const Color(0xFF00FF88),
              onTap: () {},
            ),
            QuickActionCard(
              title: 'Publier\nContenu',
              icon: Icons.edit_rounded,
              color: const Color(0xFF00CC66),
              onTap: () {},
            ),
            QuickActionCard(
              title: 'Ajouter\nMarqueur',
              icon: Icons.add_location_rounded,
              color: const Color(0xFF009944),
              onTap: () {},
            ),
            QuickActionCard(
              title: 'Rapport\nAnalyse',
              icon: Icons.analytics_rounded,
              color: const Color(0xFF00FF88),
              onTap: () {},
            ),
          ],
        ),
      ],
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
          child: Column(
            children: [
              _buildActivityItem(
                icon: Icons.person_add_rounded,
                title: 'Nouvel employé ajouté',
                subtitle: 'Marie Dubois - Développeuse',
                time: 'Il y a 2h',
                color: const Color(0xFF00FF88),
              ),
              Divider(color: Colors.black.withValues(alpha: 0.1)),
              _buildActivityItem(
                icon: Icons.article_rounded,
                title: 'Publication mise à jour',
                subtitle: 'Réunion équipe du lundi',
                time: 'Il y a 4h',
                color: const Color(0xFF00CC66),
              ),
              Divider(color: Colors.black.withValues(alpha: 0.1)),
              _buildActivityItem(
                icon: Icons.location_on_rounded,
                title: 'Nouveau marqueur créé',
                subtitle: 'Salle de conférence B',
                time: 'Il y a 6h',
                color: const Color(0xFF009944),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
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
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
