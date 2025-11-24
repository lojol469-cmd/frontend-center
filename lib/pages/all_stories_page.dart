import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../main.dart';
import '../api_service.dart';
import 'create_story_page.dart';
import 'story_view_page.dart';

class AllStoriesPage extends StatefulWidget {
  const AllStoriesPage({super.key});

  @override
  State<AllStoriesPage> createState() => _AllStoriesPageState();
}

class _AllStoriesPageState extends State<AllStoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _stories = [];
  List<Map<String, dynamic>> _filteredStories = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await ApiService.getStories(token);
      if (mounted) {
        final storiesList = result['stories'] as List?;
        setState(() {
          _stories = storiesList?.cast<Map<String, dynamic>>() ?? [];
          _filteredStories = _stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Erreur chargement stories: $e');
    }
  }

  void _filterStories(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStories = _stories;
      } else {
        _filteredStories = _stories.where((story) {
          final user = story['user'] as Map<String, dynamic>?;
          final userName = user?['name'] as String? ?? '';
          final email = user?['email'] as String? ?? '';
          final searchName = userName.isEmpty ? email.split('@')[0] : userName;
          return searchName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Toutes les Stories',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00D4FF)),
            onPressed: () {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final token = appProvider.accessToken;
              
              if (token == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Non connecté')),
                );
                return;
              }
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateStoryPage(token: token),
                ),
              ).then((_) => _loadStories());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStories,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une story...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00D4FF)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _filterStories('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          // Liste des stories
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
                  )
                : _filteredStories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucune story disponible'
                                  : 'Aucun résultat trouvé',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _filteredStories.length,
                        itemBuilder: (context, index) {
                          final story = _filteredStories[index];
                          return _buildStoryCard(story, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(Map<String, dynamic> story, int index) {
    final user = story['user'] as Map<String, dynamic>?;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // Vérifier si c'est la story de l'utilisateur actuel
    final storyUserIdData = story['userId'];
    String? storyUserId;
    if (storyUserIdData is Map) {
      storyUserId = storyUserIdData['_id'] as String?;
    } else if (storyUserIdData is String) {
      storyUserId = storyUserIdData;
    }
    final currentUserId = appProvider.currentUser?['_id'] as String?;
    final isOwnStory = storyUserId != null && currentUserId != null && storyUserId == currentUserId;
    
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
    
    debugPrint('👤 Story user: ${user?['name']} / ${user?['email']} -> $userName');
    
    final profileImage = user?['profileImage'] as String? ?? '';
    final mediaType = story['mediaType'] ?? story['type'] ?? 'text';
    final mediaUrl = story['mediaUrl'] ?? '';
    final storyId = story['_id'] as String?;
    
    final timeAgo = _formatTimeAgo(story['createdAt']);
    final isViewed = story['isViewed'] ?? false;
    final backgroundColor = story['backgroundColor'] ?? '#00D4FF';

    return GestureDetector(
      onTap: () {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        final token = appProvider.accessToken;
        
        if (token == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Non connecté')),
          );
          return;
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewPage(
              token: token,
              stories: List.from(_filteredStories), // Créer une copie pour éviter les problèmes
              initialIndex: index,
            ),
          ),
        ).then((result) {
          // Recharger les stories après la visualisation/suppression
          debugPrint('📥 Retour de StoryViewPage, rechargement...');
          _loadStories();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isViewed
                ? Colors.grey.withValues(alpha: 0.3)
                : const Color(0xFF00D4FF),
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image ou vidéo de fond
              if (mediaType == 'video' && mediaUrl.isNotEmpty)
                // Miniature vidéo générée automatiquement
                Stack(
                  fit: StackFit.expand,
                  children: [
                    _StoryVideoThumbnailWidget(
                      videoUrl: mediaUrl,
                      fallbackImage: profileImage,
                    ),
                    // Icône play pour les vidéos
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4FF).withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF00D4FF),
                          size: 48,
                        ),
                      ),
                    ),
                  ],
                )
              else if (mediaType == 'image' && mediaUrl.isNotEmpty)
                // Image de la story
                Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF00D4FF).withValues(alpha: 0.3),
                            const Color(0xFF9C27B0).withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white54,
                        size: 48,
                      ),
                    );
                  },
                )
              else
                // Story texte avec fond dégradé
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(int.tryParse(backgroundColor.replaceAll('#', '0xFF')) ?? 0xFF00D4FF).withValues(alpha: 0.5),
                        const Color(0xFF9C27B0).withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      story['content'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),

              // User info
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF00D4FF),
                      backgroundImage: profileImage.isNotEmpty
                          ? NetworkImage(profileImage)
                          : null,
                      child: profileImage.isEmpty
                          ? Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Viewed indicator
              if (isViewed)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Vu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Bouton supprimer pour les propres stories
              if (isOwnStory && storyId != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _deleteStory(storyId),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStory(String storyId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    final messenger = ScaffoldMessenger.of(context);

    if (token == null) return;

    debugPrint('🗑️ ALL_STORIES_PAGE: Suppression de la story: $storyId');
    debugPrint('🔑 ALL_STORIES_PAGE: Token disponible: ${token.isNotEmpty}');
    debugPrint('🔑 ALL_STORIES_PAGE: Token length: ${token.length}');

    // Demander confirmation
    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
      debugPrint('📡 ALL_STORIES_PAGE: Appel de ApiService.deleteStory...');
      await ApiService.deleteStory(token, storyId);
      debugPrint('✅ ALL_STORIES_PAGE: Suppression réussie');
      
      if (mounted) {
        // Recharger les stories
        await _loadStories();
        
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Story supprimée avec succès'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ALL_STORIES_PAGE: Erreur suppression story: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(dynamic createdAt) {
    if (createdAt == null) return 'Maintenant';
    
    try {
      final date = DateTime.parse(createdAt.toString());
      final diff = DateTime.now().difference(date);
      
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (e) {
      return 'Maintenant';
    }
  }
}

// Widget pour afficher la miniature d'une vidéo story
class _StoryVideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final String? fallbackImage;

  const _StoryVideoThumbnailWidget({
    required this.videoUrl,
    this.fallbackImage,
  });

  @override
  State<_StoryVideoThumbnailWidget> createState() => _StoryVideoThumbnailWidgetState();
}

class _StoryVideoThumbnailWidgetState extends State<_StoryVideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 90,
      );

      if (mounted) {
        setState(() {
          _thumbnailData = thumbnailData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur génération miniature story vidéo: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D4FF),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_hasError || _thumbnailData == null) {
      // Afficher l'image de profil en fallback
      if (widget.fallbackImage != null && widget.fallbackImage!.isNotEmpty) {
        return Image.network(
          widget.fallbackImage!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00D4FF).withValues(alpha: 0.3),
                    const Color(0xFF9C27B0).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.videocam_off,
                color: Colors.white54,
                size: 48,
              ),
            );
          },
        );
      }

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00D4FF).withValues(alpha: 0.3),
              const Color(0xFF9C27B0).withValues(alpha: 0.3),
            ],
          ),
        ),
        child: const Icon(
          Icons.videocam_off,
          color: Colors.white54,
          size: 48,
        ),
      );
    }

    return Image.memory(
      _thumbnailData!,
      fit: BoxFit.cover,
    );
  }
}
