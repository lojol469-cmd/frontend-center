import 'package:flutter/material.dart';
import '../components/media_player.dart';

class VideoPlayerPage extends StatelessWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: MediaPlayer(
          url: videoUrl,
          type: MediaType.video,
          autoPlay: true,
          loop: false,
          showControls: true,
          aspectRatio: 16 / 9,
          onFinished: () {
            debugPrint('Video finished');
            Navigator.pop(context);
          },
          onError: () {
            debugPrint('Video error');
          },
        ),
      ),
    );
  }
}
