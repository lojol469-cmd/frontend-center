import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Gestionnaire centralisé des thèmes avec sauvegarde persistante
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme_id';
  
  AppTheme _currentTheme = AppTheme.neonGreen;
  bool _isLoading = true;

  AppTheme get currentTheme => _currentTheme;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _currentTheme.isDark;

  ThemeProvider() {
    _loadSavedTheme();
  }

  /// Charger le thème sauvegardé au démarrage
  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeId = prefs.getString(_themeKey);
      
      if (savedThemeId != null) {
        _currentTheme = AppTheme.fromId(savedThemeId);
        debugPrint('✅ Thème chargé: ${_currentTheme.name}');
      } else {
        debugPrint('ℹ️ Aucun thème sauvegardé, utilisation du thème par défaut');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement thème: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Changer le thème et sauvegarder
  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme.id == theme.id) return;

    _currentTheme = theme;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme.id);
      debugPrint('✅ Thème sauvegardé: ${theme.name}');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde thème: $e');
    }
  }

  /// Changer le thème par ID
  Future<void> setThemeById(String themeId) async {
    final theme = AppTheme.fromId(themeId);
    await setTheme(theme);
  }

  /// Basculer entre mode clair et sombre
  Future<void> toggleDarkMode() async {
    if (_currentTheme.isDark) {
      // Passer au mode clair (Vert Néon par défaut)
      await setTheme(AppTheme.neonGreen);
    } else {
      // Passer au mode sombre (Océan Sombre par défaut)
      await setTheme(AppTheme.darkOcean);
    }
  }

  /// Obtenir la couleur primaire
  Color get primaryColor => _currentTheme.primary;
  
  /// Obtenir la couleur secondaire
  Color get secondaryColor => _currentTheme.secondary;
  
  /// Obtenir la couleur d'accent
  Color get accentColor => _currentTheme.accent;
  
  /// Obtenir la couleur de fond
  Color get backgroundColor => _currentTheme.background;
  
  /// Obtenir la couleur de surface
  Color get surfaceColor => _currentTheme.surface;
  
  /// Obtenir la couleur du texte
  Color get textColor => _currentTheme.text;
  
  /// Obtenir la couleur du texte secondaire
  Color get textSecondaryColor => _currentTheme.textSecondary;
  
  /// Obtenir le dégradé principal
  LinearGradient get gradient => _currentTheme.gradient;
  
  /// Obtenir le dégradé des cartes
  LinearGradient get cardGradient => _currentTheme.cardGradient;

  /// Réinitialiser au thème par défaut
  Future<void> resetToDefault() async {
    await setTheme(AppTheme.neonGreen);
  }
}
