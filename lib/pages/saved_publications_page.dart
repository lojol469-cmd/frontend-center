import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'video_player_page.dart';

class SavedPublicationsPage extends StatefulWidget {
  const SavedPublicationsPage({super.key});

  @override
  State<SavedPublicationsPage> createState() => _SavedPublicationsPageState();
}

class _SavedPublicationsPageState extends State<SavedPublicationsPage> {
  List<dynamic> _savedPublications = [];
  bool _isLoading = true;

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

      final result = await ApiService.getSavedPublications(token);
      
      setState(() {
        _savedPublications = result['publications'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading saved publications: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _unsavePublication(String publicationId) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final token = appProvider.accessToken;

      if (token == null) {
        throw Exception('Non authentifié');
      }

      await ApiService.unsavePublication(token, publicationId);
      
      setState(() {
        _savedPublications.removeWhere((pub) => pub['_id'] == publicationId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication retirée des sauvegardées')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Publications sauvegardées',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            )
          : _savedPublications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune publication sauvegardée',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appuyez sur l\'icône 🔖 pour sauvegarder',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedPublications,
                  color: Colors.blue,
                  backgroundColor: Colors.grey[900],
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _savedPublications.length,
                    itemBuilder: (context, index) {
                      final pub = _savedPublications[index];
                      return _buildPublicationCard(pub);
                    },
                  ),
                ),
    );
  }

  Widget _buildPublicationCard(Map<String, dynamic> pub) {
    final user = pub['userId'] as Map<String, dynamic>?;
    final mediaList = pub['media'] as List<dynamic>? ?? [];
    final media = mediaList.map((m) => m.toString()).toList();
    final content = pub['content'] as String? ?? '';
    final likesCount = (pub['likes'] as List<dynamic>?)?.length ?? 0;
    final commentsCount = (pub['comments'] as List<dynamic>?)?.length ?? 0;
    final createdAt = pub['createdAt'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  radius: 20,
                  backgroundColor: Colors.blue,
                  backgroundImage: user?['profileImage'] != null && user!['profileImage'].toString().isNotEmpty
                      ? NetworkImage(user['profileImage'])
                      : null,
                  child: user?['profileImage'] == null || user!['profileImage'].toString().isEmpty
                      ? Text(
                          (user?['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
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
                        user?['name'] ?? 'Utilisateur',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark, color: Colors.blue),
                  onPressed: () => _showUnsaveDialog(pub['_id']),
                  tooltip: 'Retirer des sauvegardées',
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),

          // Médias
          if (media.isNotEmpty)
            SizedBox(
              height: 300,
              child: media.length == 1
                  ? _buildMediaItem(media[0])
                  : PageView.builder(
                      itemCount: media.length,
                      itemBuilder: (context, index) => _buildMediaItem(media[index]),
                    ),
            ),

          // Barre d'actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$likesCount',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(width: 20),
                Icon(Icons.comment, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$commentsCount',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(String mediaUrl) {
    final isVideo = mediaUrl.toLowerCase().contains('.mp4') ||
        mediaUrl.toLowerCase().contains('.mov') ||
        mediaUrl.toLowerCase().contains('.avi') ||
        mediaUrl.toLowerCase().contains('.mkv') ||
        mediaUrl.toLowerCase().contains('.webm');

    return Container(
      color: Colors.black,
      child: isVideo
          ? _buildVideoPlayer(mediaUrl)
          : Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[850],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.blue,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          size: 60,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image non disponible',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    debugPrint('🎥 Creating video player for: $videoUrl');
    
    // Thumbnail vidéo avec bouton play (évite les crashes de chargement)
    return GestureDetector(
      onTap: () => _playVideoInDialog(videoUrl),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Essayer d'afficher une miniature de la vidéo
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[900],
              child: const Icon(
                Icons.videocam,
                size: 60,
                color: Colors.white24,
              ),
            ),
            // Bouton play
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(20),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),
            // Nom du fichier
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.video_library, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        videoUrl.split('/').last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playVideoInDialog(String videoUrl) {
    // Naviguer vers le lecteur vidéo HTML5 dédié
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: videoUrl,
          title: 'Lecture vidéo',
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

  void _showUnsaveDialog(String publicationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Retirer des sauvegardées',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Voulez-vous retirer cette publication de vos sauvegardées ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unsavePublication(publicationId);
            },
            child: const Text(
              'Retirer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
