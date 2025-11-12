import 'package:flutter/material.dart';

/// Widget pour afficher un fond d'image HD en arrière-plan
/// L'image prend toute la page, est responsive et non coupée
class ImageBackground extends StatelessWidget {
  /// Chemin de l'image (ex: 'assets/images/photo.jpg')
  final String imagePath;
  
  /// Opacité du fond (0.0 à 1.0)
  final double opacity;
  
  /// Si true, ajoute un dégradé pour améliorer la lisibilité
  final bool withGradient;
  
  /// Couleur du dégradé (si withGradient = true)
  final Color gradientColor;
  
  /// Enfant à afficher au-dessus du fond
  final Widget child;

  const ImageBackground({
    super.key,
    required this.imagePath,
    this.opacity = 0.4,
    this.withGradient = true,
    this.gradientColor = Colors.black,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image HD en arrière-plan - BoxFit.cover pour responsive sans coupure
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover, // Couvre tout l'écran sans déformation
              errorBuilder: (context, error, stackTrace) {
                // Image de secours en cas d'erreur
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF001a33),
                        Color(0xFF000814),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Dégradé TRÈS LÉGER pour améliorer la lisibilité
        if (withGradient)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    gradientColor.withValues(alpha: 0.1),
                    gradientColor.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

        // Contenu de la page
        child,
      ],
    );
  }
}
