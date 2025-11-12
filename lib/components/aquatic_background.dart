import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Widget pour afficher un fond vidéo aquatique en arrière-plan
/// Supporte les vidéos depuis assets ou network
class AquaticBackground extends StatefulWidget {
  /// URL ou chemin de la vidéo (ex: 'assets/videos/aquarium.mp4' ou URL réseau)
  final String videoSource;
  
  /// Si true, la vidéo provient des assets, sinon d'une URL réseau
  final bool isAsset;
  
  /// Opacité du fond (0.0 à 1.0)
  final double opacity;
  
  /// Si true, ajoute un dégradé sombre pour améliorer la lisibilité
  final bool withGradient;
  
  /// Couleur du dégradé (si withGradient = true)
  final Color gradientColor;
  
  /// Enfant à afficher au-dessus du fond
  final Widget child;

  const AquaticBackground({
    super.key,
    required this.videoSource,
    this.isAsset = true,
    this.opacity = 0.3,
    this.withGradient = true,
    this.gradientColor = Colors.black,
    required this.child,
  });

  @override
  State<AquaticBackground> createState() => _AquaticBackgroundState();
}

class _AquaticBackgroundState extends State<AquaticBackground> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Créer le contrôleur selon la source
      if (widget.isAsset) {
        _controller = VideoPlayerController.asset(widget.videoSource);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoSource),
        );
      }

      // Configuration du contrôleur
      _controller.setLooping(true); // Lecture en boucle
      _controller.setVolume(0.0); // Muet

      // Initialiser et démarrer
      await _controller.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
        await _controller.play();
      }
    } catch (e) {
      debugPrint('❌ Erreur initialisation vidéo aquatique: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond de secours (si vidéo pas chargée ou erreur)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF001a33), // Bleu océan foncé
                const Color(0xFF000814), // Noir profond
              ],
            ),
          ),
        ),

        // Vidéo aquatique
        if (_isInitialized && !_hasError)
          Opacity(
            opacity: widget.opacity,
            child: Transform.scale(
              scale: 1.0, // Pas de zoom pour garder la qualité
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),

        // Dégradé TRÈS LÉGER pour améliorer la lisibilité
        if (widget.withGradient)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.gradientColor.withValues(alpha: 0.15), // Plus léger
                  widget.gradientColor.withValues(alpha: 0.35), // Plus léger
                ],
              ),
            ),
          ),

        // Contenu de la page
        widget.child,
      ],
    );
  }
}
