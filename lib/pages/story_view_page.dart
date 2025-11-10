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
      return;
    }

    _timer = Timer(Duration(seconds: duration), () {
      if (mounted && !_isPaused) {
        _nextStory();
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

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteStory(index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
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
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;
          
          if (tapPosition < screenWidth / 3) {
            _previousStory();
          } else if (tapPosition > screenWidth * 2 / 3) {
            _nextStory();
          } else {
            _togglePause();
          }
        },
        child: Stack(
          children: [
            // PageView pour swipe
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStoryIndex = index;
                });
                _markStoryAsViewed(index);
                _startStoryTimer();
              },
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                return _buildStoryContent(widget.stories[index]);
              },
            ),

            // Barre de progression en haut
            SafeArea(
              child: Column(
                children: [
                  _buildProgressBar(),
                  _buildHeader(),
                ],
              ),
            ),

            // Boutons de navigation (gauche/droite)
            Positioned.fill(
              child: Row(
                children: [
                  // Zone gauche (reculer)
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _previousStory,
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: _currentStoryIndex > 0
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  
                  // Zone centrale (pause)
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _togglePause,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  
                  // Zone droite (avancer)
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _nextStory,
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: _currentStoryIndex < widget.stories.length - 1
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bouton fermer (en bas à droite)
            Positioned(
              bottom: 32,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
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
                Text(
                  timeAgo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isOwner(story))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmation(_currentStoryIndex);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
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

    debugPrint('🎬 Building story content:');
    debugPrint('   Type: $mediaType');
    debugPrint('   Raw URL: $rawMediaUrl');
    debugPrint('   Full URL: $mediaUrl');
    debugPrint('   Content: $content');
    debugPrint('   Background: $backgroundColor');

    if (mediaType == 'image' && mediaUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            mediaUrl,
            fit: BoxFit.contain,
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
      debugPrint('🎥 Creating video player for: $mediaUrl');
      debugPrint('   Current story index: $_currentStoryIndex');
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
