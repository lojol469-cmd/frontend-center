import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api_service.dart';
import '../main.dart';
import 'trends_page.dart';
import 'comments_page.dart';
import '../utils/share_helper.dart';

class SavedPublicationsPage extends StatefulWidget {
  const SavedPublicationsPage({super.key});

  @override
  State<SavedPublicationsPage> createState() => SavedPublicationsPageState();
}

class SavedPublicationsPageState extends State<SavedPublicationsPage> {
  bool _isLoading = true;
  List<dynamic> _savedPublications = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPublications();
  }

  Future<void> _loadSavedPublications() async {
    setState(() => _isLoading = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;

      if (token == null) {
        throw Exception('Non authentifié');
      }

      debugPrint('📥 Chargement des publications sauvegardées...');
      final result = await ApiService.getSavedPublications(token);
      final allPublications = result['publications'] as List? ?? [];
      
      debugPrint('📊 Total publications sauvegardées: ${allPublications.length}');

      if (mounted) {
        setState(() {
          _savedPublications = allPublications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement publications sauvegardées: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openTrendsMode(int initialIndex) {
    debugPrint('\n╔═══════════════════════════════════════╗');
    debugPrint('║  OPENING TRENDS MODE                  ║');
    debugPrint('╚═══════════════════════════════════════╝');
    
    // Filtrer uniquement les vidéos
    final videoPublications = _savedPublications.where((pub) {
      // Vérifier mediaType
      final mediaType = pub['mediaType'];
      if (mediaType == 'video') return true;

      // Vérifier dans le tableau media
      final media = pub['media'] as List?;
      if (media != null && media.isNotEmpty) {
        final firstMedia = media[0];
        if (firstMedia is Map) {
          return firstMedia['type'] == 'video';
        } else if (firstMedia is String) {
          return firstMedia.toLowerCase().contains('.mp4');
        }
      }
      
      return false;
    }).map((pub) => pub as Map<String, dynamic>).toList();

    debugPrint('🎥 Vidéos trouvées: ${videoPublications.length}');
    
    // DEBUG: Afficher les vidéos
    for (var i = 0; i < videoPublications.length; i++) {
      final pub = videoPublications[i];
      debugPrint('\n📹 Vidéo $i:');
      debugPrint('   ID: ${pub['_id']}');
      debugPrint('   media type: ${pub['media'].runtimeType}');
      debugPrint('   media content: ${pub['media']}');
      
      if (pub['media'] is List && (pub['media'] as List).isNotEmpty) {
        final firstMedia = (pub['media'] as List)[0];
        debugPrint('   media[0] type: ${firstMedia.runtimeType}');
        debugPrint('   media[0] content: $firstMedia');
        
        if (firstMedia is Map) {
          debugPrint('   media[0][\'url\']: ${firstMedia['url']}');
          debugPrint('   media[0][\'url\'] type: ${firstMedia['url'].runtimeType}');
        }
      }
    }

    if (videoPublications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune vidéo disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Trouver l'index de la vidéo cliquée
    final clickedPubId = _savedPublications[initialIndex]['_id'];
    final videoIndex = videoPublications.indexWhere((pub) => pub['_id'] == clickedPubId);
    
    debugPrint('\n🚀 Navigation vers TrendsPage');
    debugPrint('   Vidéos: ${videoPublications.length}');
    debugPrint('   Index initial: ${videoIndex >= 0 ? videoIndex : 0}');
    debugPrint('╚═══════════════════════════════════════╝\n');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrendsPage(
          videos: videoPublications,
          initialIndex: videoIndex >= 0 ? videoIndex : 0,
        ),
      ),
    ).then((_) => _loadSavedPublications());
  }

  Future<void> _unsavePublication(String publicationId) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;

      if (token == null) return;

      await ApiService.unsavePublication(token, publicationId);
      
      if (mounted) {
        setState(() {
          _savedPublications.removeWhere((pub) => pub['_id'] == publicationId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publication retirée des sauvegardées'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
    }
  }

  Future<void> _toggleLike(String publicationId) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;
      if (token == null) return;

      await ApiService.toggleLike(token, publicationId);
      _loadSavedPublications();
    } catch (e) {
      debugPrint('❌ Erreur: $e');
    }
  }

  void _openComments(String publicationId, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          publicationId: publicationId,
          publicationContent: content,
        ),
      ),
    );
  }

  void _sharePublication(Map<String, dynamic> pub) async {
    final content = pub['content'] ?? '';
    final userId = pub['userId'];
    final userName = userId is Map ? (userId['name'] ?? 'Quelqu\'un') : 'Quelqu\'un';
    
    final media = pub['media'] as List?;
    if (media != null && media.isNotEmpty) {
      final firstMedia = media[0];
      String? mediaUrl;
      String mediaType = 'image';
      
      if (firstMedia is String) {
        mediaUrl = firstMedia;
      } else if (firstMedia is Map) {
        mediaUrl = firstMedia['url'] ?? firstMedia['path'];
        mediaType = firstMedia['type'] ?? 'image';
      }
      
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        final fullMediaUrl = _getFullUrl(mediaUrl);
        
        await ShareHelper.sharePublication(
          context: context,
          mediaUrl: fullMediaUrl,
          userName: userName,
          content: content,
          mediaType: mediaType,
        );
        return;
      }
    }
    
    await ShareHelper.shareText(
      context: context,
      userName: userName,
      content: content,
    );
  }

  String _getFullUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUrl = ApiService.baseUrl;
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Publications sauvegardées',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF88)),
            onPressed: _loadSavedPublications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00FF88)),
                  SizedBox(height: 16),
                  Text(
                    'Chargement...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : _savedPublications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Aucune publication sauvegardée',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vos publications sauvegardées\napparaîtront ici',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedPublications,
                  color: const Color(0xFF00FF88),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _savedPublications.length,
                    itemBuilder: (context, index) {
                      final pub = _savedPublications[index];
                      final user = pub['userId'] as Map<String, dynamic>?;
                      final media = pub['media'] as List<dynamic>? ?? [];
                      final content = pub['content'] as String? ?? '';
                      final likes = pub['likes'] as List<dynamic>? ?? [];
                      final comments = pub['comments'] as List<dynamic>? ?? [];
                      final createdAt = pub['createdAt'] as String?;
                      final publicationId = pub['_id'] as String? ?? '';

                      final appProvider = Provider.of<AppProvider>(context, listen: false);
                      final currentUserId = appProvider.currentUser?['_id'] ?? '';
                      final isLiked = likes.any((like) => 
                        like == currentUserId || (like is Map && like['_id'] == currentUserId)
                      );

                      final userName = user?['name'] as String? ?? 'Utilisateur';
                      final userRole = user?['role'] as String? ?? '';
                      final profileImage = user?['profileImage'] as String?;

                      // Déterminer le type de média
                      String mediaType = 'text';
                      String? mediaUrl;
                      
                      if (media.isNotEmpty) {
                        final firstMedia = media[0];
                        if (firstMedia is Map) {
                          mediaType = firstMedia['type'] ?? 'image';
                          mediaUrl = firstMedia['url'] ?? firstMedia['path'];
                        } else if (firstMedia is String) {
                          mediaType = firstMedia.toLowerCase().contains('.mp4') ? 'video' : 'image';
                          mediaUrl = firstMedia;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[800]!, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête utilisateur
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFF00FF88),
                                    backgroundImage: profileImage != null && profileImage.isNotEmpty
                                        ? CachedNetworkImageProvider(_getFullUrl(profileImage))
                                        : null,
                                    child: profileImage == null || profileImage.isEmpty
                                        ? Text(
                                            userName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (userRole.isNotEmpty)
                                          Text(
                                            userRole,
                                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                          ),
                                        if (createdAt != null)
                                          Text(
                                            _formatDate(createdAt),
                                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.bookmark, color: Color(0xFF00FF88)),
                                    onPressed: () => _unsavePublication(publicationId),
                                    tooltip: 'Retirer',
                                  ),
                                ],
                              ),
                            ),
                            
                            // Contenu texte
                            if (content.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  content,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                ),
                              ),
                            
                            // Média (image ou vidéo)
                            if (mediaUrl != null)
                              GestureDetector(
                                onTap: mediaType == 'video' ? () => _openTrendsMode(index) : null,
                                child: Container(
                                  height: 400,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: _getFullUrl(mediaUrl),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[850],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF00FF88),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[800],
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 60,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      
                                      // Badge vidéo
                                      if (mediaType == 'video')
                                        Center(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00FF88).withValues(alpha: 0.9),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF00FF88).withValues(alpha: 0.5),
                                                  blurRadius: 20,
                                                  spreadRadius: 5,
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(24),
                                            child: const Icon(
                                              Icons.play_arrow,
                                              color: Colors.black,
                                              size: 50,
                                            ),
                                          ),
                                        ),
                                      
                                      // Badge "VIDÉO" en haut à gauche
                                      if (mediaType == 'video')
                                        Positioned(
                                          top: 16,
                                          left: 16,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00FF88),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.play_circle_filled,
                                                  color: Colors.black,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'VIDÉO',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            
                            // Actions (like, comment, share)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => _toggleLike(publicationId),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.grey[400],
                                          size: 22,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${likes.length}',
                                          style: TextStyle(
                                            color: isLiked ? Colors.red : Colors.grey[400],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  InkWell(
                                    onTap: () => _openComments(publicationId, content),
                                    child: Row(
                                      children: [
                                        Icon(Icons.comment, color: Colors.grey[400], size: 22),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${comments.length}',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _sharePublication(pub),
                                    icon: Icon(Icons.share, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inHours < 1) {
        return 'Il y a ${difference.inMinutes}min';
      } else if (difference.inDays < 1) {
        return 'Il y a ${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays}j';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}
