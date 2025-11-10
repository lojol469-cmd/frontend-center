import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service.dart';

class CreateStoryPage extends StatefulWidget {
  final String token;

  const CreateStoryPage({super.key, required this.token});

  @override
  State<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedMedia;
  String _mediaType = 'text'; // 'text', 'image', 'video'
  Color _backgroundColor = const Color(0xFF00D4FF);
  bool _isUploading = false;
  int _duration = 5; // Durée en secondes

  // Couleurs prédéfinies pour stories texte
  final List<Color> _backgroundColors = [
    const Color(0xFF00D4FF), // Cyan
    const Color(0xFFFF006E), // Rose
    const Color(0xFF8338EC), // Violet
    const Color(0xFFFFBE0B), // Jaune
    const Color(0xFFFB5607), // Orange
    const Color(0xFF3A86FF), // Bleu
    const Color(0xFF06FFA5), // Vert
    const Color(0xFFFF006E), // Rose foncé
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedMedia = File(image.path);
          _mediaType = 'image';
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (video != null) {
        setState(() {
          _selectedMedia = File(video.path);
          _mediaType = 'video';
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de la vidéo: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedMedia = File(photo.path);
          _mediaType = 'image';
        });
      }
    } catch (e) {
      _showError('Erreur lors de la prise de photo: $e');
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedMedia = null;
      _mediaType = 'text';
    });
  }

  Future<void> _createStory() async {
    if (_contentController.text.trim().isEmpty && _selectedMedia == null) {
      _showError('Ajoutez du contenu ou un média pour créer une story');
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ApiService.createStory(
        widget.token,
        content: _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
        mediaFile: _selectedMedia,
        mediaType: _mediaType == 'text' ? null : _mediaType,
        backgroundColor: _mediaType == 'text' ? '#${_backgroundColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}' : null,
        duration: _duration,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story publiée avec succès!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Retourner true pour indiquer le succès
      }
    } catch (e) {
      _showError('Erreur lors de la publication: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mediaType == 'text' ? _backgroundColor : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _createStory,
              child: const Text(
                'Publier',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Contenu principal
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Fermer le clavier si ouvert
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _mediaType == 'text' ? _backgroundColor : Colors.black,
                    ),
                    child: _buildContent(),
                  ),
                ),
              ),

              // Barre d'outils en bas
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sélecteur de durée
                    if (_mediaType != 'video')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Durée:',
                              style: TextStyle(color: Colors.white),
                            ),
                            Expanded(
                              child: Slider(
                                value: _duration.toDouble(),
                                min: 3,
                                max: 15,
                                divisions: 12,
                                label: '${_duration}s',
                                activeColor: Colors.white,
                                onChanged: (value) {
                                  setState(() => _duration = value.toInt());
                                },
                              ),
                            ),
                            Text(
                              '${_duration}s',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                    // Boutons d'action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Galerie photo
                        _buildToolButton(
                          icon: Icons.photo_library,
                          label: 'Photo',
                          onTap: _pickImage,
                        ),
                        // Caméra
                        _buildToolButton(
                          icon: Icons.camera_alt,
                          label: 'Caméra',
                          onTap: _takePhoto,
                        ),
                        // Vidéo
                        _buildToolButton(
                          icon: Icons.videocam,
                          label: 'Vidéo',
                          onTap: _pickVideo,
                        ),
                        // Supprimer média
                        if (_selectedMedia != null)
                          _buildToolButton(
                            icon: Icons.delete,
                            label: 'Effacer',
                            onTap: _removeMedia,
                            color: Colors.red,
                          ),
                      ],
                    ),

                    // Sélecteur de couleur de fond (seulement pour stories texte)
                    if (_mediaType == 'text' && _selectedMedia == null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _backgroundColors.length,
                          itemBuilder: (context, index) {
                            final color = _backgroundColors[index];
                            final isSelected = color.toARGB32() == _backgroundColor.toARGB32();
                            return GestureDetector(
                              onTap: () {
                                setState(() => _backgroundColor = color);
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Indicateur de chargement
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Publication en cours...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedMedia != null) {
      // Afficher l'image ou la vidéo sélectionnée
      if (_mediaType == 'image') {
        return Stack(
          children: [
            Center(
              child: Image.file(
                _selectedMedia!,
                fit: BoxFit.contain,
              ),
            ),
            if (_contentController.text.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _contentController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      } else if (_mediaType == 'video') {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Vidéo sélectionnée',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedMedia!.path.split('/').last,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    }

    // Story texte
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: TextField(
          controller: _contentController,
          maxLines: null,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 2,
                offset: Offset(0, 0),
              ),
            ],
          ),
          decoration: const InputDecoration(
            hintText: 'Écrivez quelque chose...',
            hintStyle: TextStyle(
              color: Colors.black54,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {}); // Pour mettre à jour l'aperçu
          },
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
