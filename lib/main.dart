import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pages/main_page.dart';
import 'config/server_config.dart';
import 'websocket_service.dart';
import 'theme/theme_provider.dart';
import 'components/notification_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuration de la barre de statut (sera ajustée selon le thème)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Blanc pour thèmes sombres
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // ✅ PRODUCTION MODE: Effacer le cache d'URL et forcer Render
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('api_base_url'); // Supprimer l'ancienne URL en cache
  
  // Mode Production : Connexion directe à Render (pas de détection IP)
  debugPrint('🌐 Mode Production : ${ServerConfig.productionUrl}');
  debugPrint('📡 Notifications via WebSocket + Notifications Locales');
  
  runApp(const CenterApp());
}

class CenterApp extends StatelessWidget {
  const CenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = AppProvider();
            provider.initialize(); // Charger les données sauvegardées
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(), // Gestionnaire de thèmes
        ),
      ],
      child: Consumer2<AppProvider, ThemeProvider>(
        builder: (context, appProvider, themeProvider, _) {
          // Afficher un loading pendant l'initialisation
          if (!appProvider.isInitialized || themeProvider.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Container(
                  decoration: BoxDecoration(
                    gradient: themeProvider.currentTheme.gradient,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: themeProvider.currentTheme.primary,
                    ),
                  ),
                ),
              ),
            );
          }

          return MaterialApp(
            title: 'Center - Personnel & Social',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(themeProvider),
            home: const NotificationWrapper(
              child: MainPage(),
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;
    
    return ThemeData(
      useMaterial3: true,
      brightness: theme.isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: theme.isDark ? Brightness.dark : Brightness.light,
        primary: theme.primary,
        onPrimary: theme.isDark ? Colors.white : Colors.black,
        secondary: theme.secondary,
        onSecondary: theme.isDark ? Colors.white : Colors.black,
        tertiary: theme.accent,
        onTertiary: theme.isDark ? Colors.white : Colors.black,
        error: Colors.red,
        onError: Colors.white,
        surface: theme.surface,
        onSurface: theme.text,
        outline: theme.primary,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: theme.text,
        displayColor: theme.text,
      ),
      scaffoldBackgroundColor: theme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.background,
        elevation: 0,
        systemOverlayStyle: theme.isDark 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        foregroundColor: theme.text,
        surfaceTintColor: theme.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF88), // Bright green
          foregroundColor: Colors.black,
          elevation: 2,
          shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: Color(0xFF00FF88),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: theme.surface,
        elevation: 4,
        shadowColor: theme.isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.primary,
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: theme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.primary,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.primary,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(color: theme.text),
        hintStyle: TextStyle(color: theme.textSecondary),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF00FF88),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.surface,
        selectedItemColor: theme.primary,
        unselectedItemColor: theme.textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class AppProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _isAuthenticated = false;
  String? _accessToken;
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;
  final WebSocketService _wsService = WebSocketService();
  int _unreadMessagesCount = 0;
  bool _hasUnreadNotifications = false;

  int get currentIndex => _currentIndex;
  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  Stream<Map<String, dynamic>> get webSocketStream => _wsService.stream;
  int get unreadMessagesCount => _unreadMessagesCount;
  bool get hasUnreadNotifications => _hasUnreadNotifications;

  // Clés pour SharedPreferences
  static const String _keyIsAuthenticated = 'is_authenticated';
  static const String _keyAccessToken = 'access_token';
  static const String _keyCurrentUser = 'current_user';

  // Initialiser et charger les données sauvegardées
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isAuthenticated = prefs.getBool(_keyIsAuthenticated) ?? false;
      _accessToken = prefs.getString(_keyAccessToken);
      
      final userJson = prefs.getString(_keyCurrentUser);
      if (userJson != null) {
        _currentUser = json.decode(userJson) as Map<String, dynamic>;
      }
      
      _isInitialized = true;
      
      debugPrint('🔐 AppProvider initialisé - Authentifié: $_isAuthenticated');
      if (_isAuthenticated) {
        debugPrint('👤 Utilisateur: ${_currentUser?['email']}');
        // Connecter WebSocket si authentifié
        if (_accessToken != null) {
          _wsService.connect(_accessToken!);
          // Écouter les mises à jour de notifications via WebSocket
          _setupWebSocketNotificationListener();
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur initialisation AppProvider: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> setAuthenticated(bool authenticated, {String? token, Map<String, dynamic>? user}) async {
    _isAuthenticated = authenticated;
    _accessToken = token;
    _currentUser = user;
    
    // Sauvegarder dans SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsAuthenticated, authenticated);
      
      if (token != null) {
        await prefs.setString(_keyAccessToken, token);
      } else {
        await prefs.remove(_keyAccessToken);
      }
      
      if (user != null) {
        await prefs.setString(_keyCurrentUser, json.encode(user));
      } else {
        await prefs.remove(_keyCurrentUser);
      }
      
      debugPrint('💾 Authentification sauvegardée - Token: ${token?.substring(0, 20)}...');
      
      // Connecter WebSocket si authentifié
      if (authenticated && token != null) {
        _wsService.connect(token);
      }
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde authentification: $e');
    }
    
    notifyListeners();
  }

  Future<void> logout() async {
    // Déconnecter WebSocket
    _wsService.disconnect();
    
    _isAuthenticated = false;
    _accessToken = null;
    _currentUser = null;
    _currentIndex = 0;
    
    // Supprimer de SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsAuthenticated);
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyCurrentUser);
      
      debugPrint('🚪 Déconnexion - Données supprimées');
    } catch (e) {
      debugPrint('❌ Erreur suppression données: $e');
    }
    
    notifyListeners();
  }

  // Mettre à jour le compteur de messages non lus
  void setUnreadMessagesCount(int count) {
    _unreadMessagesCount = count;
    _hasUnreadNotifications = count > 0;
    notifyListeners();
  }

  // Incrémenter le compteur
  void incrementUnreadMessages() {
    _unreadMessagesCount++;
    _hasUnreadNotifications = true;
    notifyListeners();
  }

  // Réinitialiser le compteur
  void clearUnreadMessages() {
    _unreadMessagesCount = 0;
    _hasUnreadNotifications = false;
    notifyListeners();
  }

  // Écouter les messages WebSocket pour mettre à jour le badge
  void _setupWebSocketNotificationListener() {
    _wsService.stream.listen((data) {
      final type = data['type'] as String?;
      
      switch (type) {
        case 'notification_update':
          // Mise à jour du compteur depuis le serveur
          final count = data['unreadCount'] as int? ?? 0;
          setUnreadMessagesCount(count);
          debugPrint('🔔 Badge mis à jour: $count notifications');
          break;
          
        case 'notification_read':
          // Une notification a été lue
          final count = data['unreadCount'] as int? ?? 0;
          setUnreadMessagesCount(count);
          debugPrint('✅ Notification lue, badge: $count');
          break;
          
        case 'new_message':
        case 'new_comment':
        case 'new_like':
          // Nouveau message/notification - incrémenter
          incrementUnreadMessages();
          debugPrint('📬 Nouvelle notification reçue');
          break;
      }
    });
  }
}
