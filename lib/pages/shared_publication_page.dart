import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import '../pages/main_page.dart';
import '../components/post_card.dart';

/// Page pour afficher une publication partagée via un lien
/// Redirige vers inscription/connexion si l'utilisateur n'est pas connecté
class SharedPublicationPage extends StatefulWidget {
  final String publicationId;

  const SharedPublicationPage({
    super.key,
    required this.publicationId,
  });

  @override
  State<SharedPublicationPage> createState() => _SharedPublicationPageState();
}

class _SharedPublicationPageState extends State<SharedPublicationPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _publication;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadPublication();
  }

  Future<void> _checkAuthAndLoadPublication() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // Vérifier si l'utilisateur est connecté
    if (appProvider.currentUser == null) {
      // Pas connecté, rediriger vers inscription
      if (mounted) {
        _showAuthDialog();
      }
      return;
    }

    // Utilisateur connecté, charger la publication
    await _loadPublication();
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Connexion requise',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pour voir ce contenu partagé, vous devez vous connecter ou créer un compte.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00FF88),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le contenu sera disponible après connexion',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Retour à l'écran précédent
            },
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAuth();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Se connecter / S\'inscrire',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainPage(),
      ),
    ).then((_) {
      // Après connexion, recharger la publication
      _checkAuthAndLoadPublication();
    });
  }

  Future<void> _loadPublication() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.getPublicationById(widget.publicationId);
      
      if (response['success']) {
        setState(() {
          _publication = response['publication'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Publication introuvable';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement publication: $e');
      setState(() {
        _error = 'Erreur de chargement';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Publication partagée',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF00FF88)),
            onPressed: () => _sharePublication(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00FF88),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPublication,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_publication == null) {
      return const Center(
        child: Text(
          'Publication introuvable',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _buildPublicationCard();
  }

  Widget _buildPublicationCard() {
    final pub = _publication!;
    final userId = pub['userId'] as Map<String, dynamic>?;
    
    // Extraire les données
    final userName = userId?['name'] ?? 'Utilisateur';
    final userEmail = userId?['email'] ?? '';
    final userAvatar = userId?['profileImage'] ?? '';
    final content = pub['content'] ?? '';
    final likes = (pub['likes'] as List?)?.length ?? 0;
    final comments = (pub['comments'] as List?)?.length ?? 0;
    final media = pub['media'] as List?;
    final createdAt = pub['createdAt'];
    
    // Gérer le média
    String? mediaUrl;
    String? mediaType;
    if (media != null && media.isNotEmpty) {
      final firstMedia = media[0];
      if (firstMedia is Map) {
        mediaUrl = firstMedia['url'] ?? firstMedia['path'];
        mediaType = firstMedia['type'] ?? 'image';
        
        // Détection par extension
        if ((mediaType == null || mediaType.isEmpty) && mediaUrl != null) {
          final urlLower = mediaUrl.toLowerCase();
          if (urlLower.endsWith('.mp4') || urlLower.endsWith('.avi') ||
              urlLower.endsWith('.mov') || urlLower.endsWith('.wmv') ||
              urlLower.endsWith('.flv') || urlLower.endsWith('.webm') ||
              urlLower.endsWith('.mkv')) {
            mediaType = 'video';
          }
        }
      }
    }
    
    // Géolocalisation
    final location = pub['location'] as Map<String, dynamic>?;
    double? latitude;
    double? longitude;
    if (location != null) {
      if (location.containsKey('latitude') && location.containsKey('longitude')) {
        latitude = (location['latitude'] as num?)?.toDouble();
        longitude = (location['longitude'] as num?)?.toDouble();
      }
    }
    
    // Calculer le temps écoulé
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PostCard(
          userName: userName,
          userRole: userEmail,
          timeAgo: timeAgo,
          content: content,
          likes: likes,
          comments: comments,
          shares: 0,
          imageUrl: mediaUrl,
          mediaType: mediaType,
          userAvatar: userAvatar,
          latitude: latitude,
          longitude: longitude,
          onLike: () {
            // Géré dans le composant
          },
          onComment: () {
            // Géré dans le composant
          },
          onShare: _sharePublication,
          isSaved: false,
          isOwner: false,
        ),
      ),
    );
  }

  void _sharePublication() {
    // Logique de partage (déjà implémentée dans ShareHelper)
    debugPrint('📤 Partage de la publication ${widget.publicationId}');
  }
}
