import 'package:flutter/material.dart';

/// Définition des palettes de couleurs disponibles
class AppTheme {
  final String id;
  final String name;
  final String icon;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final LinearGradient gradient;
  final LinearGradient cardGradient;

  const AppTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.gradient,
    required this.cardGradient,
  });

  /// Thème par défaut - Vert Néon (actuel)
  static const neonGreen = AppTheme(
    id: 'neon_green',
    name: 'Vert Néon',
    icon: '💚',
    primary: Color(0xFF00FF88),
    secondary: Color(0xFF00CC66),
    accent: Color(0xFF009944),
    background: Colors.white,
    surface: Color(0xFFF8FFF8),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFF8FFF8)],
    ),
  );

  /// Thème Bleu Océan
  static const oceanBlue = AppTheme(
    id: 'ocean_blue',
    name: 'Bleu Océan',
    icon: '🌊',
    primary: Color(0xFF00B4D8),
    secondary: Color(0xFF0077B6),
    accent: Color(0xFF03045E),
    background: Colors.white,
    surface: Color(0xFFF0F9FF),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFF0F9FF)],
    ),
  );

  /// Thème Violet Mystique
  static const mysticPurple = AppTheme(
    id: 'mystic_purple',
    name: 'Violet Mystique',
    icon: '🔮',
    primary: Color(0xFF9D4EDD),
    secondary: Color(0xFF7B2CBF),
    accent: Color(0xFF5A189A),
    background: Colors.white,
    surface: Color(0xFFFAF5FF),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFAF5FF)],
    ),
  );

  /// Thème Orange Sunset
  static const orangeSunset = AppTheme(
    id: 'orange_sunset',
    name: 'Orange Sunset',
    icon: '🌅',
    primary: Color(0xFFFF6B35),
    secondary: Color(0xFFF7931E),
    accent: Color(0xFFC1292E),
    background: Colors.white,
    surface: Color(0xFFFFF8F0),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFFF8F0)],
    ),
  );

  /// Thème Rose Sakura
  static const roseSakura = AppTheme(
    id: 'rose_sakura',
    name: 'Rose Sakura',
    icon: '🌸',
    primary: Color(0xFFFF6B9D),
    secondary: Color(0xFFC9184A),
    accent: Color(0xFFA4133C),
    background: Colors.white,
    surface: Color(0xFFFFF5F8),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFFFF6B9D), Color(0xFFC9184A)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFFF5F8)],
    ),
  );

  /// Thème Cyan Électrique
  static const electricCyan = AppTheme(
    id: 'electric_cyan',
    name: 'Cyan Électrique',
    icon: '⚡',
    primary: Color(0xFF00F5FF),
    secondary: Color(0xFF00D9E5),
    accent: Color(0xFF00A8B5),
    background: Colors.white,
    surface: Color(0xFFF0FEFF),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFF00F5FF), Color(0xFF00D9E5)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFF0FEFF)],
    ),
  );

  /// Thème Rouge Passion
  static const passionRed = AppTheme(
    id: 'passion_red',
    name: 'Rouge Passion',
    icon: '❤️',
    primary: Color(0xFFFF0054),
    secondary: Color(0xFFD90429),
    accent: Color(0xFF8B0000),
    background: Colors.white,
    surface: Color(0xFFFFF0F3),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFFFF0054), Color(0xFFD90429)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFFF0F3)],
    ),
  );

  /// Thème Or Luxe
  static const luxuryGold = AppTheme(
    id: 'luxury_gold',
    name: 'Or Luxe',
    icon: '👑',
    primary: Color(0xFFFFD700),
    secondary: Color(0xFFFFA500),
    accent: Color(0xFFB8860B),
    background: Colors.white,
    surface: Color(0xFFFFFDF0),
    text: Colors.black,
    textSecondary: Color(0xFF555555),
    gradient: LinearGradient(
      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFFFDF0)],
    ),
  );

  /// Thème Mode Sombre - Dark Ocean
  static const darkOcean = AppTheme(
    id: 'dark_ocean',
    name: 'Océan Sombre',
    icon: '🌙',
    primary: Color(0xFF00B4D8),
    secondary: Color(0xFF0077B6),
    accent: Color(0xFF00F5FF),
    background: Color(0xFF000814),
    surface: Color(0xFF001a33),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF001a33), Color(0xFF002040)],
    ),
  );

  /// Thème Mode Sombre - Violet Nuit
  static const darkPurple = AppTheme(
    id: 'dark_purple',
    name: 'Violet Nuit',
    icon: '🌃',
    primary: Color(0xFF9D4EDD),
    secondary: Color(0xFF7B2CBF),
    accent: Color(0xFFC77DFF),
    background: Color(0xFF10002B),
    surface: Color(0xFF1A0033),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A0033), Color(0xFF240046)],
    ),
  );

  /// Thème Cyan & Orange (Défaut)
  static const cyanOrange = AppTheme(
    id: 'cyan_orange',
    name: 'Cyan & Orange',
    icon: '🎨',
    primary: Color(0xFF00D4FF),
    secondary: Color(0xFFFF6B35),
    accent: Color(0xFF00A8CC),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFF00D4FF), Color(0xFFFF6B35)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ),
  );

  /// Thème Bleu & Violet
  static const blueViolet = AppTheme(
    id: 'blue_violet',
    name: 'Bleu & Violet',
    icon: '💙',
    primary: Color(0xFF2196F3),
    secondary: Color(0xFF9C27B0),
    accent: Color(0xFF1976D2),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ),
  );

  /// Thème Vert & Jaune
  static const greenYellow = AppTheme(
    id: 'green_yellow',
    name: 'Vert & Jaune',
    icon: '💚',
    primary: Color(0xFF4CAF50),
    secondary: Color(0xFFFFC107),
    accent: Color(0xFF388E3C),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFF4CAF50), Color(0xFFFFC107)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ),
  );

  /// Thème Rose & Indigo
  static const pinkIndigo = AppTheme(
    id: 'pink_indigo',
    name: 'Rose & Indigo',
    icon: '💖',
    primary: Color(0xFFE91E63),
    secondary: Color(0xFF3F51B5),
    accent: Color(0xFFC2185B),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFFE91E63), Color(0xFF3F51B5)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ),
  );

  /// Thème Orange & Rouge
  static const orangeRed = AppTheme(
    id: 'orange_red',
    name: 'Orange & Rouge',
    icon: '🔥',
    primary: Color(0xFFFF9800),
    secondary: Color(0xFFF44336),
    accent: Color(0xFFF57C00),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFFFF9800), Color(0xFFF44336)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ),
  );

  /// Thème Teal & Amber
  static const tealAmber = AppTheme(
    id: 'teal_amber',
    name: 'Teal & Amber',
    icon: '🌊',
    primary: Color(0xFF009688),
    secondary: Color(0xFFFFC107),
    accent: Color(0xFF00796B),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Colors.white,
    textSecondary: Color(0xFFBBBBBB),
    gradient: LinearGradient(
      colors: [Color(0xFF009688), Color(0xFFFFC107)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ),
  );

  /// Liste de tous les thèmes disponibles
  static const List<AppTheme> allThemes = [
    cyanOrange,
    blueViolet,
    greenYellow,
    pinkIndigo,
    orangeRed,
    tealAmber,
    darkOcean,
    darkPurple,
  ];

  /// Obtenir un thème par son ID
  static AppTheme fromId(String id) {
    try {
      return allThemes.firstWhere((theme) => theme.id == id);
    } catch (e) {
      return darkOcean; // Thème par défaut (dark)
    }
  }

  /// Vérifier si c'est un thème sombre
  bool get isDark => background.computeLuminance() < 0.5;

  /// Copier avec modifications
  AppTheme copyWith({
    String? id,
    String? name,
    String? icon,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? text,
    Color? textSecondary,
    LinearGradient? gradient,
    LinearGradient? cardGradient,
  }) {
    return AppTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      gradient: gradient ?? this.gradient,
      cardGradient: cardGradient ?? this.cardGradient,
    );
  }
}
