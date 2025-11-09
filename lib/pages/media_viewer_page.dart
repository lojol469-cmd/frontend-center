import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/media_player.dart';

/// Page de visualisation plein écran pour vidéos et audio
class MediaViewerPage extends StatefulWidget {
  final String url;
  final MediaType type;
  final String? title;
  final String? description;

  const MediaViewerPage({
    super.key,
    required this.url,
    required this.type,
    this.title,
    this.description,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  @override
  void initState() {
    super.initState();
    // Mode plein écran pour les vidéos
    if (widget.type == MediaType.video) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    // Restaurer les paramètres système
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Lecteur média
          Center(
            child: MediaPlayer(
              url: widget.url,
              type: widget.type,
              autoPlay: true,
              showControls: true,
              onFinished: () {
                debugPrint('✅ Lecture terminée');
              },
              onError: () {
                debugPrint('❌ Erreur de lecture');
              },
            ),
          ),

          // Bouton retour
          SafeArea(
            child: Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Titre et description (pour audio)
          if (widget.type == MediaType.audio && 
              (widget.title != null || widget.description != null))
            SafeArea(
              child: Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
