import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

class StoryCircle extends StatefulWidget {
  final String name;
  final String imageUrl;
  final bool isOwn;
  final bool hasStory;
  final VoidCallback onTap;
  final VoidCallback? onDelete; // Callback pour supprimer la story
  final String? mediaUrl; // URL de la vidéo ou image de la story
  final String? mediaType; // 'video', 'image', ou 'text'

  const StoryCircle({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.isOwn,
    required this.hasStory,
    required this.onTap,
    this.onDelete,
    this.mediaUrl,
    this.mediaType,
  });

  @override
  State<StoryCircle> createState() => _StoryCircleState();
}

class _StoryCircleState extends State<StoryCircle> {
  Uint8List? _videoThumbnail;
  bool _isLoadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    // Générer la miniature si c'est une vidéo
    if (widget.hasStory && 
        !widget.isOwn && 
        widget.mediaType == 'video' && 
        widget.mediaUrl != null && 
        widget.mediaUrl!.isNotEmpty) {
      _generateVideoThumbnail();
    }
  }

  @override
  void didUpdateWidget(StoryCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Régénérer la miniature si l'URL de la vidéo a changé
    if (widget.mediaUrl != oldWidget.mediaUrl &&
        widget.hasStory &&
        !widget.isOwn &&
        widget.mediaType == 'video' &&
        widget.mediaUrl != null &&
        widget.mediaUrl!.isNotEmpty) {
      _generateVideoThumbnail();
    }
  }

  Future<void> _generateVideoThumbnail() async {
    if (_isLoadingThumbnail) return;
    
    setState(() {
      _isLoadingThumbnail = true;
    });

    try {
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: widget.mediaUrl!,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 70,
      );

      if (mounted) {
        setState(() {
          _videoThumbnail = thumbnailData;
          _isLoadingThumbnail = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur génération miniature story circle: $e');
      if (mounted) {
        setState(() {
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer quelle image afficher en fond
    ImageProvider? backgroundImageProvider;
    
    // Si c'est une story avec une image, utiliser l'image de la story
    if (widget.hasStory && !widget.isOwn && widget.mediaType == 'image' && widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) {
      backgroundImageProvider = NetworkImage(widget.mediaUrl!);
    }
    // Si c'est une vidéo et qu'on a généré une miniature, l'utiliser
    else if (widget.hasStory && !widget.isOwn && widget.mediaType == 'video' && _videoThumbnail != null) {
      backgroundImageProvider = MemoryImage(_videoThumbnail!);
    }
    // Sinon utiliser l'image de profil
    else if (widget.imageUrl.isNotEmpty) {
      backgroundImageProvider = NetworkImage(widget.imageUrl);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.hasStory || widget.isOwn
                      ? const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFFFF6B35)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: !widget.hasStory && !widget.isOwn
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        )
                      : null,
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    image: backgroundImageProvider != null
                        ? DecorationImage(
                            image: backgroundImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // Icône par défaut si pas d'image
                      if (backgroundImageProvider == null)
                        Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 32,
                          ),
                        ),
                      // Indicateur de chargement pour les vidéos
                      if (_isLoadingThumbnail)
                        Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                            ),
                          ),
                        ),
                      // Icône play pour les vidéos
                      if (widget.mediaType == 'video' && widget.hasStory && !widget.isOwn && !_isLoadingThumbnail)
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF00D4FF),
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Bouton ajouter pour les propres stories
              if (widget.isOwn && !widget.hasStory)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
              // Bouton supprimer pour les propres stories existantes
              if (widget.isOwn && widget.hasStory && widget.onDelete != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              widget.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
