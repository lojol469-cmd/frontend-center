import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../components/post_card.dart';
import '../components/story_circle.dart';
import 'create_publication_page.dart';
import 'map_view_page.dart';
import 'comments_page.dart';
import 'all_stories_page.dart';
import 'create_story_page.dart';
import 'story_view_page.dart';
import 'saved_publications_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  bool _showFab = true;

  // État de chargement et données depuis l'API
  bool _isLoading = false;
  List<dynamic> _publications = [];
  List<Map<String, dynamic>> _stories = [];
  bool _isLoadingStories = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  Set<String> _savedPublicationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fabAnimationController.forward();
    
    _scrollController.addListener(() {
      if (_scrollController.offset > 100 && _showFab) {
        setState(() => _showFab = false);
        _fabAnimationController.reverse();
      } else if (_scrollController.offset <= 100 && !_showFab) {
        setState(() => _showFab = true);
        _fabAnimationController.forward();
      }

      // Infinite scroll
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMorePublications();
      }
    });

    _loadPublications();
    _loadStories();
    _loadSavedPublications();
    _listenToWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Recharger quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed) {
      _loadPublications();
      _loadStories();
    }
  }

  void _listenToWebSocket() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.webSocketStream.listen((message) {
      // Recharger les publications quand un nouveau commentaire est ajouté
      if (message['type'] == 'new_comment') {
        _loadPublications();
      }
      // Recharger aussi pour les nouvelles publications
      if (message['type'] == 'new_publication') {
        _loadPublications();
      }
      // Recharger les stories quand une nouvelle est créée
      if (message['type'] == 'new_story') {
        _loadStories();
      }
    });
  }

  Future<void> _loadPublications() async {
    if (_isLoading) {
      debugPrint('⏳ Chargement déjà en cours, skip');
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      debugPrint('❌ Token absent');
      setState(() {
        _error = 'Non authentifié';
        _isLoading = false;
      });
      return;
    }

    debugPrint('🔄 Début chargement publications...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getPublications(token, page: 1, limit: 20);
      debugPrint('📦 Publications reçues: ${result['publications']?.length ?? 0}');
      
      if (mounted) {
        setState(() {
          _publications = result['publications'] ?? [];
          _currentPage = 1;
          _hasMore = (result['pagination']?['currentPage'] ?? 1) < (result['pagination']?['totalPages'] ?? 1);
          _isLoading = false;
        });
        debugPrint('✅ État mis à jour avec ${_publications.length} publications');
      } else {
        debugPrint('⚠️ Widget non monté, pas de mise à jour');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement publications: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStories() async {
    if (_isLoadingStories) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    setState(() {
      _isLoadingStories = true;
    });

    try {
      final result = await ApiService.getStories(token);
      debugPrint('📊 Stories reçues: ${result['stories']?.length ?? 0}');
      debugPrint('📊 Données: $result');
      
      if (mounted) {
        setState(() {
          _stories = (result['stories'] as List<dynamic>?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ?? [];
          _isLoadingStories = false;
          
          debugPrint('📊 Stories stockées: ${_stories.length}');
          if (_stories.isNotEmpty) {
            debugPrint('📊 Première story: ${_stories[0]}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStories = false;
        });
      }
      debugPrint('❌ Erreur chargement stories: $e');
    }
  }

  Future<void> _loadMorePublications() async {
    if (_isLoading || !_hasMore) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final nextPage = _currentPage + 1;
      final result = await ApiService.getPublications(token, page: nextPage, limit: 20);
      if (mounted) {
        final newPubs = result['publications'] ?? [];
        setState(() {
          _publications.addAll(newPubs);
          _currentPage = nextPage;
          _hasMore = (result['pagination']?['currentPage'] ?? nextPage) < (result['pagination']?['totalPages'] ?? nextPage);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Erreur chargement plus de publications: $e');
    }
  }

  Future<void> _likePublication(String publicationId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    if (token == null) return;

    try {
      await ApiService.toggleLike(token, publicationId);
      // Recharger les publications pour voir le like
      _loadPublications();
    } catch (e) {
      debugPrint('Erreur like publication: $e');
    }
  }

  Future<void> _loadSavedPublications() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    if (token == null) return;

    try {
      final result = await ApiService.getSavedPublications(token);
      final publications = result['publications'] as List<dynamic>?;
      if (publications != null) {
        setState(() {
          _savedPublicationIds = publications
              .map((pub) => pub['_id'] as String)
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement publications sauvegardées: $e');
    }
  }

  Future<void> _toggleSavePublication(String publicationId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    if (token == null) return;

    try {
      if (_savedPublicationIds.contains(publicationId)) {
        await ApiService.unsavePublication(token, publicationId);
        setState(() {
          _savedPublicationIds.remove(publicationId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publication retirée des sauvegardées'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await ApiService.savePublication(token, publicationId);
        setState(() {
          _savedPublicationIds.add(publicationId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publication sauvegardée'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde publication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePublication(String publicationId) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Supprimer la publication',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Voulez-vous vraiment supprimer cette publication ? Cette action est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    if (token == null) return;

    try {
      await ApiService.deletePublication(token, publicationId);
      
      if (!mounted) return;
      
      setState(() {
        _publications.removeWhere((pub) => pub['_id'] == publicationId);
        _savedPublicationIds.remove(publicationId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publication supprimée'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur suppression publication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToSavedPublications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedPublicationsPage(),
      ),
    );
  }

  Future<void> _navigateToCreatePublication() async {
    debugPrint('📝 Navigation vers création publication...');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePublicationPage()),
    );

    debugPrint('📝 Retour de création publication: $result');

    // Si une publication a été créée, recharger
    if (result == true) {
      debugPrint('📝 Rechargement des publications...');
      try {
        await _loadPublications();
        debugPrint('✅ Publications rechargées avec succès');
      } catch (e) {
        debugPrint('❌ Erreur rechargement publications: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de rechargement: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  void _showCommentsDialog(String publicationId, String publicationContent) async {
    // Naviguer vers la page des commentaires et attendre le retour
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          publicationId: publicationId,
          publicationContent: publicationContent,
        ),
      ),
    );
    
    // Recharger les publications après avoir quitté la page des commentaires
    _loadPublications();
  }

  void _sharePublication(String publicationId) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partage en cours de développement'),
        backgroundColor: Color(0xFF00D4FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToAllStories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllStoriesPage(),
      ),
    );
  }

  void _navigateToCreateStory() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    
    if (token == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStoryPage(token: token),
      ),
    ).then((result) {
      if (result == true) {
        // Recharger les stories si une nouvelle a été créée
        _loadStories();
      }
    });
  }

  Future<void> _navigateToViewStory(int index) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    
    if (token == null) return;
    
    try {
      // Charger les stories depuis l'API
      final result = await ApiService.getStories(token);
      final stories = (result['stories'] as List<dynamic>?)
          ?.map((s) => s as Map<String, dynamic>)
          .toList() ?? [];
      
      if (stories.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune story disponible'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewPage(
              token: token,
              stories: List.from(stories), // Créer une copie pour éviter les problèmes
              initialIndex: index < stories.length ? index : 0,
            ),
          ),
        ).then((result) {
          // Recharger les stories après visualisation/suppression
          debugPrint('📥 Retour de StoryViewPage, rechargement...');
          _loadStories();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteStoryFromBubble(String storyId) async {
    // Récupérer les données avant l'opération async
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    // Demander confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Supprimer la story',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Voulez-vous vraiment supprimer cette story ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      debugPrint('🗑️ Suppression de la story: $storyId');
      await ApiService.deleteStory(token, storyId);
      
      if (mounted) {
        // Recharger les stories
        await _loadStories();
        
        // Vérifier mounted à nouveau après l'opération async
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Story supprimée avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              Color(0xFF001122),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(),
              _buildStoriesSection(),
              _buildPostsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Bouton Carte
              FloatingActionButton(
                heroTag: 'map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapViewPage()),
                  );
                },
                backgroundColor: Colors.green,
                child: const Icon(Icons.map_rounded, color: Colors.white),
              ),
              const SizedBox(height: 12),
              // Bouton Créer Publication
              AnimatedBuilder(
                animation: _fabAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _fabAnimation.value,
                    child: FloatingActionButton.extended(
                      heroTag: 'create',
                      onPressed: _navigateToCreatePublication,
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: Colors.black,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text(
                        'Publier',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = (screenHeight * 0.12).clamp(80.0, 110.0); // 12% de la hauteur d'écran, entre 80 et 110
    
    return SliverAppBar(
      expandedHeight: appBarHeight,
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
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Réseau Social',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Connectez-vous avec votre équipe',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _navigateToSavedPublications,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bookmark,
                        color: Color(0xFFFF6B35),
                        size: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFFF6B35),
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

  Widget _buildStoriesSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final storiesHeight = (screenHeight * 0.15).clamp(100.0, 140.0); // 15% de la hauteur d'écran, entre 100 et 140
    
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stories',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _navigateToAllStories,
                    icon: const Icon(Icons.list_rounded, color: Color(0xFF00D4FF), size: 20),
                    label: const Text(
                      'Voir tout',
                      style: TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: storiesHeight,
              child: _isLoadingStories
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D4FF),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _stories.length + 1, // +1 pour "Votre Story"
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Premier cercle : créer sa story
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: StoryCircle(
                              name: 'Votre Story',
                              imageUrl: '',
                              isOwn: true,
                              hasStory: false,
                              onTap: _navigateToCreateStory,
                            ),
                          );
                        }

                        final story = _stories[index - 1];
                        final user = story['user'] as Map<String, dynamic>?;
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        
                        // Vérifier ownership - extraire l'ID correctement
                        final storyUserIdData = story['userId'];
                        String? storyUserId;
                        
                        // Si userId est un objet (populate), extraire l'_id
                        if (storyUserIdData is Map) {
                          storyUserId = storyUserIdData['_id'] as String?;
                        } else if (storyUserIdData is String) {
                          storyUserId = storyUserIdData;
                        }
                        
                        final currentUserId = appProvider.currentUser?['_id'] as String?;
                        final isOwnStory = storyUserId != null && currentUserId != null && storyUserId == currentUserId;
                        
                        debugPrint('🔍 Story ownership check:');
                        debugPrint('   Story userId data: $storyUserIdData (type: ${storyUserIdData.runtimeType})');
                        debugPrint('   Story userId extracted: $storyUserId');
                        debugPrint('   Current user ID: $currentUserId');
                        debugPrint('   Is own story: $isOwnStory');
                        
                        // Récupérer le nom de l'utilisateur
                        String userName = 'Utilisateur';
                        if (user != null) {
                          userName = user['name'] as String? ?? '';
                          
                          // Si le nom est vide, utiliser l'email
                          if (userName.isEmpty) {
                            final email = user['email'] as String? ?? '';
                            userName = email.isNotEmpty ? email.split('@')[0] : 'Utilisateur';
                          }
                        }
                        
                        debugPrint('👤 Story user: ${user?['name']} / ${user?['email']}');
                        
                        // Déterminer l'URL de preview selon le type de story
                        String previewUrl = '';
                        final mediaType = story['mediaType'] ?? story['type'] ?? '';
                        if (mediaType == 'image' || mediaType == 'video') {
                          previewUrl = story['mediaUrl'] ?? '';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildStoryBubble(
                            userName: userName,
                            previewUrl: previewUrl,
                            backgroundColor: mediaType == 'text' 
                                ? Color(int.parse(story['backgroundColor']?.replaceAll('#', '0xFF') ?? '0xFF1A1A2E'))
                                : null,
                            hasViewed: story['viewedBy']?.contains(user?['_id']) ?? false,
                            onTap: () => _navigateToViewStory(index - 1),
                            storyId: story['_id'] as String?,
                            isOwnStory: isOwnStory,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryBubble({
    required String userName,
    required String previewUrl,
    Color? backgroundColor,
    required bool hasViewed,
    required VoidCallback onTap,
    String? storyId,
    bool isOwnStory = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasViewed
                        ? LinearGradient(
                            colors: [Colors.grey.shade600, Colors.grey.shade400],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: hasViewed 
                            ? Colors.grey.withValues(alpha: 0.2)
                            : const Color(0xFFFF6B35).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: backgroundColor ?? const Color(0xFF1A1A2E),
                      image: previewUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(previewUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: previewUrl.isEmpty && backgroundColor == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 35,
                          )
                        : null,
                  ),
                ),
                // TEMPORAIRE: Bouton de suppression TOUJOURS visible pour test
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      debugPrint('🗑️ Bouton suppression cliqué pour story: $storyId');
                      debugPrint('   isOwnStory: $isOwnStory');
                      if (storyId != null) {
                        _deleteStoryFromBubble(storyId);
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isOwnStory ? Colors.red.shade600 : Colors.orange.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isOwnStory ? Icons.close : Icons.info,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsSection() {
    if (_isLoading && _publications.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D4FF),
          ),
        ),
      );
    }

    if (_error != null && _publications.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur: $_error',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPublications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_publications.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'Aucune publication',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _publications.length) {
              // Loading indicator at bottom
              return _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            }

            final pub = _publications[index];
            final userId = pub['userId'] ?? {};
            final publicationUserId = userId['_id'] ?? '';
            
            // 🔍 LOGS DE DEBUG
            debugPrint('📊 Publication data: ${pub.toString()}');
            debugPrint('👤 userId: ${userId.toString()}');
            debugPrint('📝 Keys in userId: ${userId.keys?.toList()}');
            
            // Récupérer le nom depuis le champ 'name' ou extraire de l'email
            String userName = 'Utilisateur';
            if (userId['name'] != null && userId['name'].toString().isNotEmpty) {
              userName = userId['name'].toString();
            } else {
              // Fallback sur email si name est vide
              final email = userId['email']?.toString() ?? '';
              if (email.isNotEmpty) {
                userName = email.split('@')[0]; // Prendre la partie avant @
              }
            }
            debugPrint('✅ userName final: $userName');
            
            // Récupérer la photo de profil depuis profileImage
            final userAvatar = userId['profileImage'];
            debugPrint('📸 userAvatar: $userAvatar');
            
            final userEmail = userId['email'] ?? '';
            final content = pub['content'] ?? '';
            final likes = (pub['likes'] as List?)?.length ?? 0;
            final comments = (pub['comments'] as List?)?.length ?? 0;
            final media = pub['media'] as List?;
            
            // Gérer imageUrl (peut être String ou Map)
            String? imageUrl;
            if (media != null && media.isNotEmpty) {
              final firstMedia = media[0];
              if (firstMedia is String) {
                imageUrl = firstMedia;
              } else if (firstMedia is Map) {
                imageUrl = firstMedia['url'] ?? firstMedia['path'];
              }
            }
            
            final createdAt = pub['createdAt'];
            final publicationId = pub['_id'] ?? '';
            
            // Vérifier si l'utilisateur est le propriétaire de la publication
            final appProvider = Provider.of<AppProvider>(context, listen: false);
            final currentUserId = appProvider.currentUser?['_id'] ?? '';
            final isOwner = publicationUserId == currentUserId;

            // Calculate time ago
            String timeAgo = 'maintenant';
            if (createdAt != null) {
              try {
                final date = DateTime.parse(createdAt);
                final diff = DateTime.now().difference(date);
                if (diff.inDays > 0) {
                  timeAgo = '${diff.inDays}j';
                } else if (diff.inHours > 0) {
                  timeAgo = '${diff.inHours}h';
                } else if (diff.inMinutes > 0) {
                  timeAgo = '${diff.inMinutes}min';
                }
              } catch (e) {
                debugPrint('Erreur parse date: $e');
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PostCard(
                userName: userName,
                userRole: userEmail,
                timeAgo: timeAgo,
                content: content,
                likes: likes,
                comments: comments,
                shares: 0, // Backend doesn't have shares yet
                imageUrl: imageUrl,
                userAvatar: userAvatar,
                onLike: () => _likePublication(publicationId),
                onComment: () => _showCommentsDialog(publicationId, content),
                onShare: () => _sharePublication(publicationId),
                isSaved: _savedPublicationIds.contains(publicationId),
                onSave: () => _toggleSavePublication(publicationId),
                isOwner: isOwner,
                onDelete: () => _deletePublication(publicationId),
              ),
            );
          },
          childCount: _publications.length + (_isLoading ? 1 : 0),
        ),
      ),
    );
  }
}
