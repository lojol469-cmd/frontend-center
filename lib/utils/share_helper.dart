import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ShareHelper {
  /// Partage une publication avec média (image ou vidéo)
  /// Télécharge le média en cache et le partage pour une prévisualisation enrichie
  static Future<void> sharePublication({
    required BuildContext context,
    required String mediaUrl,
    required String userName,
    required String content,
    String mediaType = 'image', // 'image' ou 'video'
  }) async {
    if (mediaUrl.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Impossible de partager : média introuvable');
      }
      return;
    }

    // Afficher un dialog de chargement
    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      // Télécharger le média
      final response = await http.get(Uri.parse(mediaUrl)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Délai d\'attente dépassé');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Échec du téléchargement (${response.statusCode})');
      }

      // Obtenir le répertoire de cache temporaire
      final directory = await getTemporaryDirectory();
      final extension = mediaType == 'video' ? 'mp4' : 'jpg';
      final fileName = 'share_${mediaType}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${directory.path}/$fileName';

      // Sauvegarder le média localement
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Fermer le dialog de chargement
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Construire le message de partage enrichi
      final emoji = mediaType == 'video' ? '🎬' : '📸';
      final mediaLabel = mediaType == 'video' ? 'Vidéo' : 'Photo';
      
      final shareText = '''
$emoji $mediaLabel de $userName sur CENTER

${content.isNotEmpty ? content : 'Découvre ce contenu !'}

📱 Télécharge CENTER pour voir plus de contenus
🌐 $mediaUrl
      '''.trim();

      // Partager le média avec le fichier pour rich preview
      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: '$emoji $mediaLabel de $userName - CENTER',
      );

      // Nettoyer le fichier après un délai (pour laisser le temps au partage)
      Future.delayed(const Duration(seconds: 30), () {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      });

    } catch (e) {
      // Fermer le dialog de chargement si encore ouvert
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        
        // Fallback: partage simple avec lien si le téléchargement échoue
        await _shareFallback(context, mediaUrl, userName, content, mediaType);
      }
    }
  }

  /// Partage simple avec lien (fallback)
  static Future<void> _shareFallback(
    BuildContext context,
    String mediaUrl,
    String userName,
    String content,
    String mediaType,
  ) async {
    final emoji = mediaType == 'video' ? '🎬' : '📸';
    final mediaLabel = mediaType == 'video' ? 'Vidéo' : 'Photo';
    
    final fallbackText = '''
$emoji $mediaLabel de $userName

${content.isNotEmpty ? content : 'Découvre ce contenu !'}

🔗 Voir le contenu : $mediaUrl

Partagé depuis CENTER
    '''.trim();

    try {
      await Share.share(
        fallbackText,
        subject: '$emoji Contenu partagé depuis CENTER',
      );
    } catch (shareError) {
      if (context.mounted) {
        _showError(context, 'Erreur lors du partage: $shareError');
      }
    }
  }

  /// Partage du texte uniquement (publications sans média)
  static Future<void> shareText({
    required BuildContext context,
    required String userName,
    required String content,
  }) async {
    if (content.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Aucun contenu à partager');
      }
      return;
    }

    final shareText = '''
💬 Publication de $userName sur CENTER

$content

📱 Rejoins-nous sur CENTER
    '''.trim();

    try {
      await Share.share(
        shareText,
        subject: 'Publication de $userName - CENTER',
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors du partage: $e');
      }
    }
  }

  /// Partage multiple de médias
  static Future<void> shareMultipleMedia({
    required BuildContext context,
    required List<String> mediaUrls,
    required String userName,
    required String content,
  }) async {
    if (mediaUrls.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Aucun média à partager');
      }
      return;
    }

    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      final directory = await getTemporaryDirectory();
      final files = <XFile>[];

      // Télécharger tous les médias
      for (int i = 0; i < mediaUrls.length; i++) {
        final response = await http.get(Uri.parse(mediaUrls[i])).timeout(
          const Duration(seconds: 30),
        );

        if (response.statusCode == 200) {
          final fileName = 'share_media_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          files.add(XFile(filePath));
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (files.isEmpty) {
        throw Exception('Aucun média téléchargé');
      }

      final shareText = '''
📸 ${files.length} photo${files.length > 1 ? 's' : ''} de $userName sur CENTER

${content.isNotEmpty ? content : 'Découvre ces photos !'}

📱 Télécharge CENTER pour voir plus
      '''.trim();

      await Share.shareXFiles(
        files,
        text: shareText,
        subject: '📸 Photos de $userName - CENTER',
      );

      // Nettoyer les fichiers
      Future.delayed(const Duration(seconds: 30), () {
        for (final xFile in files) {
          try {
            final file = File(xFile.path);
            if (file.existsSync()) {
              file.deleteSync();
            }
          } catch (_) {}
        }
      });

    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        _showError(context, 'Erreur lors du partage: $e');
      }
    }
  }

  /// Affiche un dialog de chargement
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Préparation du partage...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Téléchargement du média',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche un message d'erreur
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
