import 'dart:math';

/// Gestionnaire centralisé des images de background HD
class BackgroundImageManager {
  static final BackgroundImageManager _instance = BackgroundImageManager._internal();
  factory BackgroundImageManager() => _instance;
  BackgroundImageManager._internal();

  final Random _random = Random();

  /// Liste de toutes les images HD disponibles (sauf le logo)
  static const List<String> _allImages = [
    'assets/images/pexels-bess-hamiti-83687-36487.jpg',
    'assets/images/pexels-francesco-ungaro-2325447.jpg',
    'assets/images/pexels-iriser-1086584.jpg',
    'assets/images/pexels-m-venter-792254-1659438.jpg',
    'assets/images/pexels-pawelkalisinski-1076758.jpg',
    'assets/images/pexels-pixabay-158063.jpg',
    'assets/images/pexels-pixabay-259915.jpg',
    'assets/images/pexels-sebastian-palomino-933481-1955134.jpg',
    'assets/images/pexels-todd-trapani-488382-1420440.jpg',
  ];

  /// Toutes les images disponibles
  List<String> get allImages => _allImages;

  /// Obtenir une image aléatoire
  String getRandomImage() {
    return _allImages[_random.nextInt(_allImages.length)];
  }

  /// Obtenir plusieurs images aléatoires différentes
  List<String> getRandomImages(int count) {
    final shuffled = List<String>.from(_allImages)..shuffle(_random);
    return shuffled.take(count.clamp(1, _allImages.length)).toList();
  }

  /// Obtenir une image différente de celle fournie
  String getRandomImageExcept(String currentImage) {
    final available = _allImages.where((img) => img != currentImage).toList();
    if (available.isEmpty) return getRandomImage();
    return available[_random.nextInt(available.length)];
  }

  /// Obtenir une image aléatoire pour une page spécifique
  String getImageForPage(String pageName) {
    // Retourner une image aléatoire (chaque ouverture de page = nouvelle image)
    return getRandomImage();
  }
}
