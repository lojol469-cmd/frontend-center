import 'package:flutter/material.dart';
import '../utils/share_helper.dart';

/// Page de test pour le système de partage avancé
class ShareTestPage extends StatelessWidget {
  const ShareTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Test de Partage'),
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFF00FF88),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test 1: Partage de vidéo
            _buildTestCard(
              context,
              title: '🎬 Partage Vidéo',
              description: 'Partage une vidéo avec rich preview',
              buttonText: 'Partager la vidéo',
              onPressed: () {
                ShareHelper.sharePublication(
                  context: context,
                  mediaUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                  userName: 'Demo User',
                  content: 'Découvre cette vidéo incroyable ! 🎥',
                  mediaType: 'video',
                );
              },
            ),

            const SizedBox(height: 20),

            // Test 2: Partage d'image
            _buildTestCard(
              context,
              title: '📸 Partage Image',
              description: 'Partage une image avec rich preview',
              buttonText: 'Partager l\'image',
              onPressed: () {
                ShareHelper.sharePublication(
                  context: context,
                  mediaUrl: 'https://picsum.photos/800/1200',
                  userName: 'Photo Pro',
                  content: 'Magnifique photo du jour ! 📷✨',
                  mediaType: 'image',
                );
              },
            ),

            const SizedBox(height: 20),

            // Test 3: Partage texte
            _buildTestCard(
              context,
              title: '💬 Partage Texte',
              description: 'Partage uniquement du texte',
              buttonText: 'Partager le texte',
              onPressed: () {
                ShareHelper.shareText(
                  context: context,
                  userName: 'Philosophe',
                  content: 'La vie est un voyage, pas une destination. Profite de chaque instant ! 🌟',
                );
              },
            ),

            const SizedBox(height: 20),

            // Test 4: Partage multiple
            _buildTestCard(
              context,
              title: '📸📸 Partage Multiple',
              description: 'Partage plusieurs images',
              buttonText: 'Partager 3 images',
              onPressed: () {
                ShareHelper.shareMultipleMedia(
                  context: context,
                  mediaUrls: [
                    'https://picsum.photos/800/1200?random=1',
                    'https://picsum.photos/800/1200?random=2',
                    'https://picsum.photos/800/1200?random=3',
                  ],
                  userName: 'Gallery Master',
                  content: 'Ma collection de photos du jour ! 🖼️',
                );
              },
            ),

            const SizedBox(height: 40),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF00FF88), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoText('• Appuie sur un bouton pour tester le partage'),
                  _buildInfoText('• Un dialog de chargement apparaîtra'),
                  _buildInfoText('• Le média sera téléchargé en cache'),
                  _buildInfoText('• Le sélecteur de partage s\'ouvrira'),
                  _buildInfoText('• Le média s\'affichera en preview !'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Features
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00FF88).withValues(alpha: 0.2),
                    const Color(0xFF00D4FF).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFF00FF88), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Fonctionnalités',
                        style: TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeature('✅', 'Rich Preview dans les apps'),
                  _buildFeature('✅', 'Téléchargement automatique'),
                  _buildFeature('✅', 'Fallback intelligent'),
                  _buildFeature('✅', 'Auto-nettoyage des fichiers'),
                  _buildFeature('✅', 'Support multi-formats'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00FF88).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFeature(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
