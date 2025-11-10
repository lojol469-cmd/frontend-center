import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'futuristic_card.dart';
import 'media_player.dart';

class PostCard extends StatefulWidget {
  final String userName;
  final String userRole;
  final String timeAgo;
  final String content;
  final int likes;
  final int comments;
  final int shares;
  final String? imageUrl;
  final String? userAvatar;
  final String? mediaType; // 'image' ou 'video'
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onVideoTap; // Callback pour ouvrir le mode Trends
  final bool isSaved;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final bool isOwner;

  const PostCard({
    super.key,
    required this.userName,
    required this.userRole,
    required this.timeAgo,
    required this.content,
    required this.likes,
    required this.comments,
    required this.shares,
    this.imageUrl,
    this.userAvatar,
    this.mediaType,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onVideoTap,
    this.isSaved = false,
    this.onSave,
    this.onDelete,
    this.isOwner = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  bool _isLiked = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _likeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FuturisticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildContent(),
          if (widget.imageUrl != null) _buildMedia(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
              ),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.userAvatar!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF00FF88),
                        child: Center(
                          child: Text(
                            widget.userName.isNotEmpty 
                                ? widget.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('❌ Erreur chargement avatar: $error');
                        debugPrint('📸 URL avatar: $url');
                        return Container(
                          color: const Color(0xFF00FF88),
                          child: Center(
                            child: Text(
                              widget.userName.isNotEmpty 
                                  ? widget.userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFF00FF88),
                      child: Center(
                        child: Text(
                          widget.userName.isNotEmpty 
                              ? widget.userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${widget.userRole} • ${widget.timeAgo}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showPostOptions(),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        widget.content,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildMedia() {
    // Si c'est une vidéo, ouvrir le mode Trends au tap
    if (widget.mediaType == 'video') {
      return GestureDetector(
        onTap: () {
          // Si onVideoTap est défini, l'utiliser (mode Trends)
          if (widget.onVideoTap != null) {
            widget.onVideoTap!();
          } else {
            // Sinon, ouvrir l'ancien lecteur vidéo
            _showVideoPlayer(context, widget.imageUrl!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          child: Stack(
            children: [
              _VideoThumbnailWidget(
                key: ValueKey('video_thumb_${widget.imageUrl}'), // Key unique pour chaque vidéo
                videoUrl: widget.imageUrl!,
                content: widget.content,
              ),
              // Icône play au centre
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Sinon, afficher l'image normalement
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.black.withValues(alpha: 0.05),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00FF88),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.black.withValues(alpha: 0.05),
            child: const Icon(
              Icons.image_not_supported_rounded,
              color: Colors.black54,
              size: 50,
            ),
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            // MediaPlayer comme dans les stories
            Center(
              child: MediaPlayer(
                url: videoUrl,
                type: MediaType.video,
                autoPlay: true,
                loop: false,
                showControls: true,
                aspectRatio: 9 / 16,
                onFinished: () {
                  debugPrint('✅ Vidéo terminée');
                },
                onError: () {
                  debugPrint('❌ Erreur lecture vidéo');
                },
              ),
            ),
            
            // Caption overlay si présent
            if (widget.content.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Bouton fermer
            Positioned(
              top: 40,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(dialogContext),
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
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _likeAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _likeAnimation.value,
                    child: _buildActionButton(
                      icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: widget.likes.toString(),
                      color: _isLiked ? Colors.red : Colors.black54,
                      onTap: _handleLike,
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: widget.comments.toString(),
                color: Colors.black54,
                onTap: widget.onComment,
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: widget.shares.toString(),
                color: Colors.black54,
                onTap: widget.onShare,
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onSave,
                icon: Icon(
                  widget.isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                  color: widget.isSaved ? Colors.blue : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
    
    widget.onLike();
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionItem(Icons.bookmark_rounded, 'Enregistrer', () {
              if (widget.onSave != null) widget.onSave!();
            }),
            _buildOptionItem(Icons.link_rounded, 'Copier le lien', () {}),
            if (widget.isOwner) ...[
              const Divider(color: Colors.white24, height: 32),
              _buildOptionItem(
                Icons.delete_rounded, 
                'Supprimer', 
                () {
                  if (widget.onDelete != null) widget.onDelete!();
                },
                color: Colors.red,
              ),
            ],
            if (!widget.isOwner) ...[
              _buildOptionItem(Icons.report_rounded, 'Signaler', () {}),
              _buildOptionItem(Icons.block_rounded, 'Masquer', () {}),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    final itemColor = color ?? Colors.white.withValues(alpha: 0.8);
    return ListTile(
      leading: Icon(
        icon,
        color: itemColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

// Widget pour afficher un thumbnail vidéo avec icône play
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final String content;

  const _VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    required this.content,
  });

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(_VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si l'URL de la vidéo a changé, régénérer le thumbnail
    if (oldWidget.videoUrl != widget.videoUrl) {
      debugPrint('🔄 URL changée, régénération du thumbnail');
      setState(() {
        _thumbnailData = null;
        _isLoading = true;
        _hasError = false;
      });
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    try {
      debugPrint('🎬 Génération thumbnail pour: ${widget.videoUrl}');
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 75,
      );
      
      if (mounted) {
        setState(() {
          _thumbnailData = uint8list;
          _isLoading = false;
        });
        debugPrint('✅ Thumbnail généré: ${uint8list?.length} bytes');
      }
    } catch (e) {
      debugPrint('❌ Erreur génération thumbnail: $e');
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        height: 200,
        color: Colors.black87,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail en fond
            if (_thumbnailData != null)
              Image.memory(
                _thumbnailData!,
                fit: BoxFit.cover,
              )
            else if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00FF88),
                ),
              )
            else if (_hasError)
              const Center(
                child: Icon(
                  Icons.video_library_rounded,
                  color: Colors.white54,
                  size: 80,
                ),
              ),
            
            // Overlay sombre
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            
            // Icône play centrée
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 40,
                ),
              ),
            ),
            
            // Badge "VIDÉO" en haut à gauche
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00FF88),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      color: Color(0xFF00FF88),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'VIDÉO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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
}
