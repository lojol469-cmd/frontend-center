import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../components/media_player.dart';

class StoryViewPage extends StatefulWidget {
  final String token;
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewPage({
    super.key,
    required this.token,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> {
  late PageController _pageController;
  int _currentStoryIndex = 0;
  Timer? _timer;
  bool _isPaused = false;
  double _currentProgress = 0.0; // Progression pour le cercle de fermeture

  final Map<int, bool> _viewedStories = {}; // Track viewed stories

  // Helper pour transformer les URLs relatives en URLs complètes
  String _getFullUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Si l'URL commence déjà par http:// ou https://, la retourner telle quelle
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // Sinon, ajouter le baseUrl
    final baseUrl = ApiService.baseUrl;
    // Enlever le slash au début de l'URL si présent
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanUrl';
  }

  @override
  void initState() {
    super.initState();
    _currentStoryIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentStoryIndex);
    _startStoryTimer();
    _markStoryAsViewed(_currentStoryIndex);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startStoryTimer() {
    _timer?.cancel();
    
    final currentStory = widget.stories[_currentStoryIndex];
    final mediaType = currentStory['mediaType'] ?? 'text';
    int duration = currentStory['duration'] ?? 5;

    // Pour les vidéos, le timer sera géré par le callback onFinished
    if (mediaType == 'video') {
      // Pour les vidéos, ne pas mettre à jour la progression (performance)
      setState(() {
        _currentProgress = 0.0;
      });
      return;
    }

    // Réinitialiser la progression
    setState(() {
      _currentProgress = 0.0;
    });

    // Timer périodique pour mettre à jour la progression (optimisé à 200ms)
    const tickDuration = Duration(milliseconds: 300); // 3 fois par seconde (encore plus optimisé)
    int elapsedMilliseconds = 0;
    int totalMilliseconds = duration * 1000;

    _timer = Timer.periodic(tickDuration, (timer) {
      if (_isPaused) return;
      
      elapsedMilliseconds += tickDuration.inMilliseconds;
      
      if (mounted) {
        setState(() {
          _currentProgress = elapsedMilliseconds / totalMilliseconds;
        });
      }
      
      if (elapsedMilliseconds >= totalMilliseconds) {
        timer.cancel();
        if (mounted && !_isPaused) {
          _nextStory();
        }
      }
    });
  }

  void _nextStory() {
    if (_currentStoryIndex < widget.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _markStoryAsViewed(_currentStoryIndex);
      _startStoryTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStoryTimer();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _timer?.cancel();
      } else {
        _startStoryTimer();
      }
    });
  }

  Future<void> _markStoryAsViewed(int index) async {
    final storyId = widget.stories[index]['_id'];
    
    // Ne pas marquer deux fois
    if (_viewedStories[index] == true) return;
    
    _viewedStories[index] = true;

    try {
      await ApiService.viewStory(widget.token, storyId);
    } catch (e) {
      debugPrint('Error marking story as viewed: $e');
    }
  }

  Future<void> _deleteStory(int index) async {
    if (index < 0 || index >= widget.stories.length) {
      debugPrint('❌ Index invalide pour suppression: $index');
      return;
    }
    
    final storyId = widget.stories[index]['_id'];
    debugPrint('🗑️ Suppression de la story: $storyId (index: $index)');
    
    try {
      await ApiService.deleteStory(widget.token, storyId);
      debugPrint('✅ Story supprimée du serveur');
      
      if (!mounted) return;
      
      // Retirer la story de la liste
      widget.stories.removeAt(index);
      debugPrint('📝 Stories restantes: ${widget.stories.length}');
      
      // Si c'était la dernière story, fermer la page
      if (widget.stories.isEmpty) {
        debugPrint('🚪 Plus de stories, fermeture de la page');
        Navigator.pop(context, true);
        return;
      }
      
      // Ajuster l'index si nécessaire
      if (_currentStoryIndex >= widget.stories.length) {
        _currentStoryIndex = widget.stories.length - 1;
        debugPrint('📍 Index ajusté à: $_currentStoryIndex');
      }
      
      if (mounted) {
        // Afficher le message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Story supprimée'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Réinitialiser les controllers
        _timer?.cancel();
        
        // Forcer le rebuild et redémarrer
        setState(() {});
        
        // Attendre un frame avant de redémarrer
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _pageController.jumpToPage(_currentStoryIndex);
            _startStoryTimer();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Afficher la liste des utilisateurs qui ont vu la story
  Future<void> _showStoryViewers(String storyId) async {
    try {
      _togglePause(); // Mettre en pause pendant la consultation
      
      final result = await ApiService.getStoryViews(widget.token, storyId);
      
      if (!mounted) return;
      
      final viewers = result['viewers'] as List<dynamic>? ?? [];
      final viewCount = result['viewCount'] ?? 0;
      
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.visibility, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Text(
                'Vues ($viewCount)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: viewers.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune vue pour le moment',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = viewers[index];
                      final name = viewer['name'] ?? 'Utilisateur';
                      final email = viewer['email'] ?? '';
                      final profilePic = viewer['profilePicture'] ?? '';
                      final viewedAt = viewer['viewedAt'];
                      final timeAgo = _formatTimeAgo(viewedAt);
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.3),
                          backgroundImage: profilePic.isNotEmpty
                              ? NetworkImage(_getFullUrl(profilePic))
                              : null,
                          child: profilePic.isEmpty
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          timeAgo,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _togglePause(); // Reprendre la lecture
              },
              child: const Text(
                'Fermer',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur récupération vues: $e');
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

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text(
              'Supprimer la story ?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Cette action est irréversible. Votre story sera définitivement supprimée.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteStory(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Supprimer',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getUserIdFromToken() {
    try {
      // Décoder le JWT pour extraire l'ID utilisateur
      final parts = widget.token.split('.');
      if (parts.length != 3) return null;
      
      // Décoder la partie payload (partie 2)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payloadMap = json.decode(decoded);
      
      return payloadMap['userId'] ?? payloadMap['id'] ?? payloadMap['sub'];
    } catch (e) {
      debugPrint('Erreur lors du décodage du token: $e');
      return null;
    }
  }

  bool _isOwner(Map<String, dynamic> story) {
    // Vérifier si l'utilisateur connecté est le propriétaire de la story
    final currentUserId = _getUserIdFromToken();
    debugPrint('🔍 Current user ID: $currentUserId');
    
    if (currentUserId == null) {
      debugPrint('❌ No current user ID found');
      return false;
    }
    
    final storyUserId = story['userId'] ?? story['user'];
    debugPrint('📖 Story userId data: $storyUserId');
    
    // Si userId est un objet (populate), extraire l'_id
    if (storyUserId is Map) {
      final storyUserIdString = storyUserId['_id'] ?? storyUserId['id'];
      debugPrint('👤 Story owner ID: $storyUserIdString');
      final isOwner = storyUserIdString == currentUserId;
      debugPrint('✅ Is owner: $isOwner');
      return isOwner;
    }
    
    // Si c'est juste l'ID en string
    debugPrint('👤 Story owner ID (string): $storyUserId');
    final isOwner = storyUserId == currentUserId;
    debugPrint('✅ Is owner: $isOwner');
    return isOwner;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // GestureDetector pour navigation entre stories
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                final tapPosition = details.globalPosition.dx;
                final tapY = details.globalPosition.dy;
                
                // Ignorer les taps dans la zone du header (150px du haut pour SafeArea + header)
                if (tapY < 150) {
                  debugPrint('🚫 Tap ignored (header zone at y: $tapY)');
                  return;
                }
                
                if (tapPosition < screenWidth / 3) {
                  _previousStory();
                } else if (tapPosition > screenWidth * 2 / 3) {
                  _nextStory();
                } else {
                  _togglePause();
                }
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const ClampingScrollPhysics(), // Physique optimisée
                pageSnapping: true,
                allowImplicitScrolling: false, // Désactiver le pré-chargement implicite
                onPageChanged: (index) {
                  setState(() {
                    _currentStoryIndex = index;
                  });
                  _markStoryAsViewed(index);
                  _startStoryTimer();
                },
                itemCount: widget.stories.length,
                itemBuilder: (context, index) {
                  // Ne construire que la page actuelle et les adjacentes immédiates
                  if ((index - _currentStoryIndex).abs() > 1) {
                    return const SizedBox.shrink(); // Page vide pour les autres
                  }
                  // RepaintBoundary pour isoler chaque story et éviter les repaints globaux
                  return RepaintBoundary(
                    key: ValueKey('story_$index'),
                    child: _buildStoryContent(widget.stories[index]),
                  );
                },
              ),
            ),
          ),

          // Barre de progression et header (au-dessus du GestureDetector)
          SafeArea(
            child: Column(
              children: [
                _buildProgressBar(),
                _buildHeader(),
              ],
            ),
          ),

          // Indicateur de pause
          if (_isPaused)
            const Center(
              child: Icon(
                Icons.pause_circle_filled,
                size: 80,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(
          widget.stories.length,
          (index) => Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: index < _currentStoryIndex
                    ? Colors.white
                    : index == _currentStoryIndex
                        ? Colors.white70
                        : Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final story = widget.stories[_currentStoryIndex];
    
    debugPrint('🔍 Building header for story $_currentStoryIndex');
    debugPrint('   Story keys: ${story.keys.toList()}');
    debugPrint('   Story user: ${story['user']}');
    debugPrint('   Story userId: ${story['userId']}');
    
    // Essayer d'abord 'user', puis 'userId' comme fallback
    Map<String, dynamic>? user;
    
    // Priorité 1: story['user'] (données complètes)
    if (story['user'] is Map<String, dynamic>) {
      user = story['user'] as Map<String, dynamic>;
      debugPrint('✅ User data from story["user"]: $user');
    } 
    // Priorité 2: story['userId'] si c'est un objet (populate)
    else if (story['userId'] is Map<String, dynamic>) {
      user = story['userId'] as Map<String, dynamic>;
      debugPrint('✅ User data from story["userId"] (Map): $user');
    }
    // Priorité 3: userId est juste une string ID
    else {
      user = null;
      debugPrint('⚠️ No user data available, only ID: ${story['userId']}');
    }
    
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
      
    debugPrint('👤 Final userName: $userName');
    
    final rawProfileImage = user?['profileImage'] as String? ?? '';
    final profileImage = _getFullUrl(rawProfileImage); // Transformer l'URL
    final createdAt = story['createdAt'];
    final timeAgo = _formatTimeAgo(createdAt);
    final viewCount = story['viewCount'] ?? 0;
    final isOwner = _isOwner(story);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : null,
            child: profileImage.isEmpty
                ? Text(
                    userName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (isOwner && viewCount > 0) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showStoryViewers(story['_id']),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$viewCount',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Menu trois points toujours visible
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 22,
              ),
            ),
            offset: const Offset(0, 50),
            color: const Color(0xFF2A2A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            onSelected: (value) {
              debugPrint('🔘 Menu option selected: $value');
              if (value == 'delete') {
                debugPrint('🗑️ Launching delete confirmation');
                _showDeleteConfirmation(_currentStoryIndex);
              }
            },
            itemBuilder: (context) {
              debugPrint('📋 Building menu items. Is owner: ${_isOwner(story)}');
              return [
                // Option Supprimer uniquement pour le propriétaire
                if (_isOwner(story))
                  const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Supprimer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
          // Bouton fermer avec cercle de progression
          Positioned(
            top: 8,
            right: 16,
            child: GestureDetector(
              onTap: () {
                debugPrint('❌ Close button tapped');
                Navigator.pop(context);
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  children: [
                    // Cercle de progression (seulement pour images/texte, pas pour vidéos)
                    if (story['mediaType'] != 'video')
                      CircularProgressIndicator(
                        value: _currentProgress,
                        strokeWidth: 3,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    // Icône X au centre
                    Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(Map<String, dynamic> story) {
    final mediaType = story['mediaType'] ?? 'text';
    final rawMediaUrl = story['mediaUrl'] ?? '';
    final mediaUrl = _getFullUrl(rawMediaUrl); // Transformer l'URL
    final content = story['content'] ?? '';
    final backgroundColor = story['backgroundColor'] ?? '#00D4FF';

    // Logs pour debug URL (temporaire)
    if (mediaType == 'video') {
      debugPrint('🎬 Video Story Debug:');
      debugPrint('   Raw URL: $rawMediaUrl');
      debugPrint('   Full URL: $mediaUrl');
      debugPrint('   Starts with http: ${mediaUrl.startsWith('http')}');
    }

    if (mediaType == 'image' && mediaUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ Error loading image: $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
          if (content.isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    } else if (mediaType == 'video' && mediaUrl.isNotEmpty) {
      // Logs minimaux pour les vidéos (performance)
      debugPrint('🎥 Video story at index: $_currentStoryIndex');
      
      // Clé unique basée sur l'URL ET l'index pour forcer reconstruction
      final playerKey = Key('video_${_currentStoryIndex}_$mediaUrl');
      return Stack(
        fit: StackFit.expand,
        children: [
          // Widget avec clé unique pour forcer dispose/init complet
          _StoryVideoPlayer(
            key: playerKey,
            videoUrl: mediaUrl,
            storyIndex: _currentStoryIndex,
            onFinished: () {
              debugPrint('✅ Video finished, going to next story');
              if (mounted && !_isPaused) {
                _nextStory();
              }
            },
            onError: () {
              debugPrint('❌ Video error, going to next story');
              if (mounted) {
                _nextStory();
              }
            },
          ),
          if (content.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      // Story texte
      Color bgColor;
      try {
        bgColor = Color(int.parse(backgroundColor.replaceFirst('#', '0xFF')));
      } catch (e) {
        bgColor = const Color(0xFF00D4FF);
      }

      return Container(
        color: bgColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
  }

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return 'Maintenant';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else {
        return 'Il y a ${difference.inDays}j';
      }
    } catch (e) {
      return 'Maintenant';
    }
  }
}

// Widget isolé pour gérer le cycle de vie des vidéos
class _StoryVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final int storyIndex;
  final VoidCallback onFinished;
  final VoidCallback onError;

  const _StoryVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.storyIndex,
    required this.onFinished,
    required this.onError,
  });

  @override
  State<_StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<_StoryVideoPlayer> {
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 _StoryVideoPlayer initState for story ${widget.storyIndex}');
  }

  @override
  void dispose() {
    debugPrint('🗑️ _StoryVideoPlayer dispose for story ${widget.storyIndex}');
    super.dispose();
  }

  void _handleFinished() {
    if (_hasFinished) return;
    _hasFinished = true;
    debugPrint('✅ Video ${widget.storyIndex} finished callback');
    widget.onFinished();
  }

  void _handleError() {
    if (_hasFinished) return;
    _hasFinished = true;
    debugPrint('❌ Video ${widget.storyIndex} error callback');
    widget.onError();
  }

  @override
  Widget build(BuildContext context) {
    return MediaPlayer(
      url: widget.videoUrl,
      type: MediaType.video,
      autoPlay: true,
      loop: false,
      showControls: false,
      aspectRatio: 9 / 16,
      onFinished: _handleFinished,
      onError: _handleError,
    );
  }
}