import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lecteur média universel pour vidéos et audio
/// Gère automatiquement l'initialisation, la lecture, et la libération des ressources
class MediaPlayer extends StatefulWidget {
  final String url;
  final MediaType type;
  final bool autoPlay;
  final bool loop;
  final bool showControls;
  final double aspectRatio;
  final VoidCallback? onFinished;
  final VoidCallback? onError;

  const MediaPlayer({
    super.key,
    required this.url,
    required this.type,
    this.autoPlay = true,
    this.loop = false,
    this.showControls = true,
    this.aspectRatio = 16 / 9,
    this.onFinished,
    this.onError,
  });

  @override
  State<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends State<MediaPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _hasCalledOnFinished = false; // Protection contre appels multiples

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing media player');
    _controlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      debugPrint('🎬 Initializing media player: ${widget.url}');
      
      // Vérifier la plateforme
      String platformInfo = kIsWeb ? 'Web' : Platform.operatingSystem;
      debugPrint('🖥️ Platform: $platformInfo');
      
      // Clean URL and ensure proper format
      String cleanUrl = widget.url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        throw Exception('URL invalide: doit commencer par http:// ou https://');
      }
      
      Uri videoUri = Uri.parse(cleanUrl);
      debugPrint('📍 Parsed URI: $videoUri');
      
      // Configuration spécifique selon la plateforme
      VideoPlayerOptions playerOptions = VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      );
      
      // Sur Windows, on peut avoir besoin de configurations spéciales
      if (!kIsWeb && Platform.isWindows) {
        debugPrint('🪟 Configuring for Windows platform');
        playerOptions = VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        );
      }
      
      _controller = VideoPlayerController.networkUrl(
        videoUri,
        videoPlayerOptions: playerOptions,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      debugPrint('⏳ Waiting for initialization...');
      await _controller!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: La vidéo met trop de temps à charger');
        },
      );
      
      if (!mounted) return;
      
      debugPrint('✅ Controller initialized - Dimensions: ${_controller!.value.size}');
      
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      _controller!.addListener(_videoListener);

      if (widget.loop) {
        _controller!.setLooping(true);
      }

      if (widget.autoPlay) {
        debugPrint('▶️ Auto-playing video...');
        await _controller!.play();
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      }

      // Auto-hide controls after 3 seconds
      if (widget.showControls) {
        _startControlsTimer();
      }
      
      debugPrint('✅ Media player fully initialized and playing: $_isPlaying');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing media player: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _getFriendlyErrorMessage(e.toString());
        });
        widget.onError?.call();
      }
    }
  }

  String _getFriendlyErrorMessage(String error) {
    String platformInfo = kIsWeb ? 'Web' : Platform.operatingSystem;
    
    if (error.contains('Timeout')) {
      return 'La vidéo met trop de temps à charger. Vérifiez votre connexion.';
    } else if (error.contains('404')) {
      return 'Vidéo introuvable sur le serveur.';
    } else if (error.contains('network') || error.contains('Network')) {
      return 'Erreur réseau. Vérifiez votre connexion internet.';
    } else if (error.contains('format') || error.contains('codec')) {
      if (platformInfo == 'windows' || platformInfo == 'linux' || platformInfo == 'macos') {
        return 'Format vidéo non supporté sur $platformInfo.\nEssayez de convertir en MP4 H.264.';
      }
      return 'Format vidéo non supporté.';
    } else if (error.contains('PlatformException') || error.contains('MissingPluginException')) {
      return 'Plugin vidéo non configuré pour $platformInfo.\nContactez le support technique.';
    } else {
      return 'Erreur lors du chargement de la vidéo.\nPlateforme: $platformInfo';
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    try {
      // Check for errors
      if (_controller!.value.hasError) {
        debugPrint('❌ Video player error: ${_controller!.value.errorDescription}');
        setState(() {
          _hasError = true;
          _errorMessage = _getFriendlyErrorMessage(_controller!.value.errorDescription ?? 'Erreur inconnue');
        });
        return;
      }

      // Check if video finished - avec tolérance de 500ms
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      
      // Vérifier que la durée est valide et que la position est vraiment à la fin
      if (duration > Duration.zero && position.inMilliseconds > 0) {
        final remaining = duration.inMilliseconds - position.inMilliseconds;
        
        // La vidéo est considérée terminée seulement si il reste moins de 500ms
        if (remaining < 500 && remaining >= 0 && !_hasCalledOnFinished) {
          if (!widget.loop && !_controller!.value.isPlaying) {
            debugPrint('✅ Video reached end (${position.inSeconds}s/${duration.inSeconds}s), calling onFinished');
            _hasCalledOnFinished = true;
            widget.onFinished?.call();
          }
        }
      }

      // Update playing state
      if (_controller!.value.isPlaying != _isPlaying) {
        setState(() => _isPlaying = _controller!.value.isPlaying);
      }
    } catch (e) {
      debugPrint('❌ Error in video listener: $e');
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });

    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTapScreen() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return widget.type == MediaType.video
        ? _buildVideoPlayer()
        : _buildAudioPlayer();
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Erreur de lecture',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = '';
                });
                _initializePlayer();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _onTapScreen,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

            // Controls overlay
            if (widget.showControls && _showControls)
              _buildControlsOverlay(),

            // Play/Pause button (center)
            if (!_isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
                  onPressed: _togglePlayPause,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon audio
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.audiotrack,
              size: 48,
              color: Color(0xFF00D4FF),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Progress bar
          _buildProgressBar(),
          
          const SizedBox(height: 8),
          
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_controller!.value.position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(_controller!.value.duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final newPosition = _controller!.value.position - const Duration(seconds: 10);
                  _controller!.seekTo(newPosition);
                },
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final newPosition = _controller!.value.position + const Duration(seconds: 10);
                  _controller!.seekTo(newPosition);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            _buildProgressBar(),
            
            const SizedBox(height: 8),
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_controller!.value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    IconButton(
                      icon: Icon(
                        _controller!.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller!.setVolume(_controller!.value.volume > 0 ? 0 : 1);
                        });
                      },
                    ),
                  ],
                ),
                Text(
                  _formatDuration(_controller!.value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: Stream.periodic(const Duration(milliseconds: 100), (_) {
        return _controller?.value.position ?? Duration.zero;
      }),
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _controller?.value.duration ?? Duration.zero;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            activeColor: const Color(0xFF00D4FF),
            inactiveColor: Colors.white30,
            onChanged: (value) {
              final newPosition = duration * value;
              _controller?.seekTo(newPosition);
            },
          ),
        );
      },
    );
  }
}

enum MediaType {
  video,
  audio,
}
