import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api_service.dart';
import '../main.dart';
import 'comments_page.dart';
import 'dart:async';

class TrendsPage extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;

  const TrendsPage({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Initialiser la première vidéo
    _initializeVideo(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Nettoyer tous les contrôleurs
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeVideo(int index) async {
    if (_controllers.containsKey(index)) {
      await _controllers[index]!.play();
      return;
    }

    final video = widget.videos[index];
    debugPrint('\n═══════════════════════════════════════');
    debugPrint('🎥 Initialisation vidéo $index');
    debugPrint('   Publication ID: ${video['_id']}');
    debugPrint('   Publication complète: $video');
    debugPrint('   Media raw: ${video['media']}');
    debugPrint('   Media type: ${video['media'].runtimeType}');
    
    final videoUrl = _getVideoUrl(video);
    debugPrint('📍 URL retournée par _getVideoUrl: "$videoUrl"');
    debugPrint('   Type: ${videoUrl.runtimeType}');
    debugPrint('   Longueur: ${videoUrl.length}');
    
    if (videoUrl.isEmpty) {
      debugPrint('⚠️ URL vide, abandon du chargement');
      debugPrint('═══════════════════════════════════════\n');
      return;
    }

    try {
      debugPrint('📡 Création du contrôleur VideoPlayer');
      debugPrint('   URL qui sera parsée: "$videoUrl"');
      
      final uri = Uri.parse(videoUrl);
      debugPrint('   URI parsé: $uri');
      debugPrint('   URI scheme: ${uri.scheme}');
      debugPrint('   URI host: ${uri.host}');
      debugPrint('   URI path: ${uri.path}');
      
      final controller = VideoPlayerController.networkUrl(uri);
      _controllers[index] = controller;

      await controller.initialize();
      if (mounted && _currentIndex == index) {
        controller.setLooping(true);
        controller.play();
        setState(() {});
        debugPrint('✅ Vidéo $index initialisée et en lecture');
      }
      debugPrint('═══════════════════════════════════════\n');
    } catch (e) {
      debugPrint('❌ ERREUR initialisation vidéo $index: $e');
      debugPrint('   URL problématique: "$videoUrl"');
      debugPrint('═══════════════════════════════════════\n');
    }
  }

  void _pauseVideo(int index) {
    if (_controllers.containsKey(index)) {
      _controllers[index]!.pause();
    }
  }

  String _getVideoUrl(Map<String, dynamic> publication) {
    final media = publication['media'];
    
    debugPrint('🔍 DEBUG _getVideoUrl:');
    debugPrint('   Type de media: ${media.runtimeType}');
    
    if (media == null) {
      debugPrint('⚠️ media est null');
      return '';
    }
    
    // ✅ UTILISER LA MÊME LOGIQUE QUE social_page.dart
    String? imageUrl;
    
    if (media is List && media.isNotEmpty) {
      final firstMedia = media[0];
      debugPrint('   → media[0] type: ${firstMedia.runtimeType}');
      
      if (firstMedia is String) {
        imageUrl = firstMedia;
        debugPrint('   ✅ Extrait comme String: $imageUrl');
      } else if (firstMedia is Map) {
        // ✅ EXTRACTION SIMPLE COMME social_page.dart
        imageUrl = firstMedia['url']?.toString() ?? firstMedia['path']?.toString();
        debugPrint('   ✅ Extrait du Map: $imageUrl');
        debugPrint('   → firstMedia clés: ${firstMedia.keys.toList()}');
      }
    } else if (media is String) {
      imageUrl = media;
      debugPrint('   ✅ media est String: $imageUrl');
    } else if (media is Map) {
      imageUrl = media['url']?.toString() ?? media['path']?.toString();
      debugPrint('   ✅ Extrait du Map direct: $imageUrl');
    }
    
    if (imageUrl == null || imageUrl.isEmpty) {
      debugPrint('❌ URL non trouvée dans media');
      return '';
    }
    
    final fullUrl = _getFullUrl(imageUrl);
    debugPrint('✅ URL vidéo finale: $fullUrl');
    return fullUrl;
  }

  String _getFullUrl(String? url) {
    if (url == null || url.isEmpty) {
      debugPrint('⚠️ _getFullUrl: URL vide ou null');
      return '';
    }
    
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUrl = ApiService.baseUrl;
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanUrl';
  }

  void _onPageChanged(int index) {
    // Pause l'ancienne vidéo
    _pauseVideo(_currentIndex);
    
    // Met à jour l'index
    setState(() {
      _currentIndex = index;
    });
    
    // Lance la nouvelle vidéo
    _initializeVideo(index);
    
    // Précharge les vidéos suivantes
    if (index + 1 < widget.videos.length) {
      _initializeVideo(index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          final publication = widget.videos[index];
          final controller = _controllers[index];
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail en arrière-plan (comme dans post_card.dart)
              _VideoThumbnailBackground(
                videoUrl: _getVideoUrl(publication),
              ),
              
              // Vidéo en plein écran par-dessus
              if (controller != null && controller.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              
              // Gradient overlay en bas
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 300,
                child: Container(
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
              
              // Overlay des informations
              _buildInfoOverlay(publication, controller),
              
              // Bouton retour en haut
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoOverlay(Map<String, dynamic> publication, VideoPlayerController? controller) {
    final userId = publication['userId'];
    final userName = userId is Map ? (userId['name'] ?? 'Anonyme') : 'Anonyme';
    final userAvatar = userId is Map ? (userId['profileImage'] ?? '') : '';
    final description = publication['description'] ?? '';
    final likesCount = (publication['likes'] as List?)?.length ?? 0;
    final commentsCount = (publication['comments'] as List?)?.length ?? 0;
    final isLiked = publication['isLiked'] ?? false;

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Informations à gauche
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Auteur
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: userAvatar.isNotEmpty
                            ? NetworkImage(_getFullUrl(userAvatar))
                            : null,
                        child: userAvatar.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // Barre de progression
                  if (controller != null && controller.value.isInitialized) ...[
                    const SizedBox(height: 12),
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        backgroundColor: Colors.white24,
                        bufferedColor: Colors.white54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Actions à droite
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause
                if (controller != null && controller.value.isInitialized)
                  _buildActionButton(
                    icon: controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    onTap: () {
                      setState(() {
                        if (controller.value.isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                      });
                    },
                  ),
                
                const SizedBox(height: 20),
                
                // Like
                _buildActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _formatCount(likesCount),
                  color: isLiked ? Colors.red : Colors.white,
                  onTap: () => _toggleLike(publication),
                ),
                
                const SizedBox(height: 20),
                
                // Commentaires
                _buildActionButton(
                  icon: Icons.comment,
                  label: _formatCount(commentsCount),
                  onTap: () => _openComments(publication),
                ),
                
                const SizedBox(height: 20),
                
                // Partager
                _buildActionButton(
                  icon: Icons.share,
                  onTap: () => _sharePublication(publication),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    String? label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _openComments(Map<String, dynamic> publication) {
    final pubId = publication['_id'];
    final content = publication['description'] ?? '';
    
    if (pubId == null) return;
    
    // Mettre la vidéo en pause
    final controller = _controllers[_currentIndex];
    controller?.pause();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          publicationId: pubId,
          publicationContent: content,
        ),
      ),
    ).then((_) {
      // Relancer la vidéo au retour
      controller?.play();
    });
  }

  Future<void> _sharePublication(Map<String, dynamic> publication) async {
    final content = publication['description'] ?? '';
    final userName = publication['userId'] is Map 
        ? (publication['userId']['name'] ?? 'Quelqu\'un') 
        : 'Quelqu\'un';
    
    // Récupérer l'URL de la vidéo
    final videoUrl = _getVideoUrl(publication);
    final fullVideoUrl = videoUrl.isNotEmpty ? _getFullUrl(videoUrl) : '';
    
    // Construire le message de partage
    final shareText = '''
🎬 Vidéo de $userName

${content.isNotEmpty ? content : 'Découvre cette vidéo !'}

${fullVideoUrl.isNotEmpty ? '📹 Vidéo: $fullVideoUrl' : ''}

Partagé depuis CENTER
    '''.trim();
    
    try {
      // Partager avec share_plus
      await Share.share(
        shareText,
        subject: 'Vidéo partagée depuis CENTER',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> publication) async {
    final pubId = publication['_id'];
    if (pubId == null) return;
    
    try {
      // Récupérer le token depuis le provider
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;
      if (token == null) return;
      
      await ApiService.toggleLike(token, pubId);
      setState(() {
        publication['isLiked'] = !(publication['isLiked'] ?? false);
        final likes = publication['likes'] as List? ?? [];
        if (publication['isLiked']) {
          likes.add('current_user');
        } else {
          likes.remove('current_user');
        }
        publication['likes'] = likes;
      });
    } catch (e) {
      debugPrint('❌ Erreur toggle like: $e');
    }
  }
}

// Widget pour afficher l'image de caption (preview) pendant le chargement de la vidéo
class _VideoThumbnailBackground extends StatelessWidget {
  final String videoUrl;

  const _VideoThumbnailBackground({
    required this.videoUrl,
  });

  // Essayer de trouver une image de preview associée à la vidéo
  String? _getThumbnailUrl() {
    // Si l'URL contient .mp4, remplacer par .jpg pour chercher le thumbnail
    if (videoUrl.contains('.mp4')) {
      return videoUrl.replaceAll('.mp4', '_thumb.jpg');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = _getThumbnailUrl();
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            const Color(0xFF0F3460),
            const Color(0xFF000000),
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Essayer de charger l'image thumbnail depuis le serveur
          if (thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black87,
              ),
              errorWidget: (context, url, error) {
                debugPrint('❌ Thumbnail non trouvé: $thumbnailUrl');
                return Container(color: Colors.black87);
              },
            )
          else
            Container(color: Colors.black87),
          
          // Pattern de fond léger
          Opacity(
            opacity: 0.05,
            child: CustomPaint(
              painter: _GridPatternPainter(),
            ),
          ),
          
          // Overlay pour améliorer le contraste
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          
          // Icône play au centre avec glow effect
          Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00FF88).withValues(alpha: 0.4),
                    const Color(0xFF00FF88).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00FF88).withValues(alpha: 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 80,
                  color: Color(0xFF00FF88),
                ),
              ),
            ),
          ),
          
          // Loading indicator en bas
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF00FF88),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chargement de la vidéo...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter pour le pattern de grille
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    const spacing = 50.0;
    
    // Lignes verticales
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Lignes horizontales
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}