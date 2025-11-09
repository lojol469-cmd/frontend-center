import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class StoryVideoPlayer extends StatefulWidget {
  final String url;
  final bool isPaused;
  final VoidCallback? onFinished;
  final VoidCallback? onError;

  const StoryVideoPlayer({
    super.key,
    required this.url,
    this.isPaused = false,
    this.onFinished,
    this.onError,
  });

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  @override
  void initState() {
    super.initState();
    // Sur Windows, notifier immédiatement que la vidéo est "terminée"
    // pour permettre la navigation
    if (!kIsWeb && Platform.isWindows) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          widget.onFinished?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sur Windows, afficher un placeholder avec icône de lecture
    if (!kIsWeb && Platform.isWindows) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Lecture vidéo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Non disponible sur Windows',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.url.split('/').last,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pour les autres plateformes, retourner un message
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}
