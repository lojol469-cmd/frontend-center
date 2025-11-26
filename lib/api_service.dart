import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;
import 'config/server_config.dart';

///
/// SERVICE API DYNAMIQUE POUR FLUTTER
///
/// Ce service s'adapte automatiquement à n'importe quelle adresse IP réseau.
/// Il détecte automatiquement l'adresse IP du serveur backend au premier appel.
///
/// UTILISATION :
/// 1. Appelez n'importe quelle méthode API - l'initialisation se fait automatiquement
/// 2. Le service scanne d'abord l'adresse par défaut, puis le réseau local si nécessaire
/// 3. Toutes les URLs sont mises à jour dynamiquement
///
/// EXEMPLE :
/// ```dart
/// // Première utilisation - détection automatique
/// final result = await ApiService.login('email@example.com');
///
/// // Toutes les autres méthodes utilisent automatiquement l'IP détectée
/// final publications = await ApiService.getPublications(token);
/// ```
///
class ApiService {
  // Configuration dynamique - détection automatique de l'IP
  static String? _baseUrl;
  static const String apiPrefix = '/api';
  static bool _isInitialized = false;
  
  // Liste des adresses IP à essayer (depuis la configuration)
  static List<String> get _possibleIPs => ServerConfig.serverIPs;
  static int get _serverPort => ServerConfig.serverPort;

  // Getter pour l'URL de base
  static String get baseUrl {
    // ✅ PRIORITÉ ABSOLUE: Mode production = URL Render uniquement
    if (ServerConfig.isProduction) {
      developer.log('🌐 PRODUCTION MODE: Forçant l\'utilisation de ${ServerConfig.productionUrl}', name: 'ApiService');
      return ServerConfig.productionUrl;
    }

    // Mode développement: utiliser l'URL détectée ou par défaut
    if (_baseUrl == null) {
      return ServerConfig.buildUrl(_possibleIPs[0]);
    }
    return _baseUrl!;
  }

  // Headers par défaut
  static Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers avec token d'authentification
  static Map<String, String> _authHeaders(String token) => {
    ..._defaultHeaders,
    'Authorization': 'Bearer $token',
  };

  // Headers pour MultipartRequest (sans Content-Type car géré automatiquement)
  static Map<String, String> _multipartAuthHeaders(String token) => {
    'Authorization': 'Bearer $token',
  };

  // Détecter le type MIME d'un fichier
  static String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    
    // Images
    if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'webp') return 'image/webp';
    
    // Vidéos
    if (ext == 'mp4') return 'video/mp4';
    if (ext == 'mov') return 'video/quicktime';
    if (ext == 'avi') return 'video/x-msvideo';
    if (ext == 'webm') return 'video/webm';
    if (ext == 'mkv') return 'video/x-matroska';
    
    // Audio
    if (['mp3', 'mpeg'].contains(ext)) return 'audio/mpeg';
    if (ext == 'm4a') return 'audio/mp4';
    if (ext == 'wav') return 'audio/wav';
    if (ext == 'ogg') return 'audio/ogg';
    if (ext == 'aac') return 'audio/aac';
    
    return 'application/octet-stream';
  }

  // Méthodes de détection automatique d'IP
  static Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('ℹ️ ApiService déjà initialisé avec URL: $_baseUrl', name: 'ApiService');
      return;
    }
    
    // ✅ MODE PRODUCTION: Utiliser directement l'URL Render
    if (ServerConfig.isProduction) {
      _baseUrl = ServerConfig.productionUrl;
      _isInitialized = true;
      developer.log('🌐 PRODUCTION MODE FORCÉ - URL: $_baseUrl', name: 'ApiService');
      developer.log('📍 Configuration: isProduction=${ServerConfig.isProduction}, productionUrl=${ServerConfig.productionUrl}', name: 'ApiService');
      return;
    }
    
    // MODE DÉVELOPPEMENT: Détection automatique
    developer.log('🔍 MODE DÉVELOPPEMENT - Détection automatique du serveur...', name: 'ApiService');
    developer.log('📡 Test de ${_possibleIPs.length} adresses IP', name: 'ApiService');
    
    // Essayer chaque IP dans l'ordre
    for (final ip in _possibleIPs) {
      try {
        final testUrl = ServerConfig.getTestUrl(ip);
        
        developer.log('🧪 Test de connexion à: $testUrl', name: 'ApiService');
        
        final response = await http.get(Uri.parse(testUrl)).timeout(
          Duration(seconds: ServerConfig.connectionTimeout),
        );
        
        if (response.statusCode == 200) {
          _baseUrl = ServerConfig.buildUrl(ip);
          _isInitialized = true;
          developer.log('✅ Serveur trouvé! IP: $ip:$_serverPort', name: 'ApiService');
          developer.log('🌐 Base URL: $_baseUrl', name: 'ApiService');
          return;
        }
      } catch (e) {
        developer.log('❌ Échec pour $ip: ${e.toString().split('\n')[0]}', name: 'ApiService');
        continue;
      }
    }
    
    // Aucune IP n'a fonctionné - utiliser la première par défaut
    _baseUrl = ServerConfig.buildUrl(_possibleIPs[0]);
    _isInitialized = true;
    developer.log('⚠️ Aucun serveur trouvé - Utilisation par défaut: $_baseUrl', name: 'ApiService');
    developer.log('💡 Vérifiez que le serveur Node.js est démarré sur le port $_serverPort', name: 'ApiService');
  }
  
  // Forcer une nouvelle détection (utile si on change de réseau)
  static Future<void> reconnect() async {
    developer.log('🔄 Reconnexion - Réinitialisation de la détection IP...', name: 'ApiService');
    _isInitialized = false;
    _baseUrl = null;
    await initialize();
  }

  // ========================================
  // GESTION TOKEN FCM (FIREBASE CLOUD MESSAGING)
  // ========================================

  /// Envoyer le token FCM au serveur pour les notifications push
  static Future<Map<String, dynamic>> updateFcmToken(String token, String fcmToken) async {
    await initialize();
    
    try {
      developer.log('📲 Envoi token FCM au serveur...', name: 'ApiService');
      
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/users/fcm-token'),
        headers: _authHeaders(token),
        body: jsonEncode({'fcmToken': fcmToken}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        developer.log('✅ Token FCM enregistré', name: 'ApiService');
        return {'success': true, 'data': data};
      } else {
        developer.log('❌ Erreur enregistrement FCM: ${data['message']}', name: 'ApiService');
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      developer.log('❌ Exception updateFcmToken: $e', name: 'ApiService');
      return {'success': false, 'message': 'Erreur réseau'};
    }
  }
  
  // Vérifier si le serveur est accessible
  static Future<bool> checkConnection() async {
    try {
      // ✅ MODE PRODUCTION: Utiliser directement l'URL Render sans initialisation
      final String serverUrl = ServerConfig.isProduction
        ? '${ServerConfig.productionUrl}/api/server-info'
        : '${ServerConfig.buildUrl(_possibleIPs[0])}/api/server-info';

      debugPrint('🔍 [CHECK] Tentative de connexion à: $serverUrl');

      final response = await http.get(Uri.parse(serverUrl)).timeout(
        const Duration(seconds: 10), // Augmenté à 10 secondes pour mobile
      );

      debugPrint('📡 [CHECK] Status Code: ${response.statusCode}');
      debugPrint('📡 [CHECK] Response Body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');

      // Accepter tout code de statut 2xx
      final isConnected = response.statusCode >= 200 && response.statusCode < 300;
      debugPrint('📡 [CHECK] Résultat: $isConnected');

      return isConnected;
    } catch (e) {
      debugPrint('❌ [CHECK] Erreur checkConnection: $e');
      debugPrint('❌ [CHECK] Type d\'erreur: ${e.runtimeType}');
      
      // Log spécifique pour les erreurs SSL
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED') || 
          e.toString().contains('HandshakeException') ||
          e.toString().contains('SSL')) {
        debugPrint('🔒 [CHECK] Erreur SSL détectée - Certificat ou connexion sécurisée');
      }
      
      // Log pour les timeouts
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        debugPrint('⏱️ [CHECK] Timeout détecté - Connexion trop lente');
      }
      
      return false;
    }
  }

  static void reset() {
    _baseUrl = null;
    _isInitialized = false;
    developer.log('🔄 API Service - reset effectué', name: 'ApiService');
  }

  // Méthode privée pour assurer l'initialisation
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ========================================
  // AUTHENTIFICATION
  // ========================================

  // Inscription
  static Future<Map<String, dynamic>> register(String email, String password, String name) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/register'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'inscription');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Connexion (envoi OTP)
  static Future<Map<String, dynamic>> login(String email) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/login'),
        headers: _defaultHeaders,
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de connexion');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Connexion admin directe (pour tests, sans OTP)
  static Future<Map<String, dynamic>> adminLogin(String email, String password) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/admin-login'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de connexion');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Vérification OTP
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/verify-otp'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
          'otp': otp,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'OTP invalide');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Vérifier l'existence d'une carte d'identité
  static Future<Map<String, dynamic>> verifyIdCard(String idCard) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/verify-id-card'),
        headers: _defaultHeaders,
        body: json.encode({
          'idCard': idCard,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Carte d\'identité non trouvée');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Inscription avec Face ID et carte d'identité
  static Future<Map<String, dynamic>> registerWithFaceID({
    required String email,
    required String name,
    required String idCard,
  }) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/register-faceid'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
          'name': name,
          'idCard': idCard,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'inscription');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Connexion avec Face ID et carte d'identité
  static Future<Map<String, dynamic>> loginWithFaceID(String idCard) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/login-faceid'),
        headers: _defaultHeaders,
        body: json.encode({
          'idCard': idCard,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de connexion');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/auth/refresh-token'),
        headers: _defaultHeaders,
        body: json.encode({'refreshToken': refreshToken}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de rafraîchissement');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // PROFIL UTILISATEUR
  // ========================================

  // Récupérer le profil complet de l'utilisateur connecté
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/user/profile'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération du profil');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour le nom
  static Future<Map<String, dynamic>> updateUserName(String token, String name) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/user/update-name'),
        headers: _authHeaders(token),
        body: json.encode({'name': name}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Changer le mot de passe
  static Future<Map<String, dynamic>> changePassword(
    String token,
    String currentPassword,
    String newPassword,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/user/change-password'),
        headers: _authHeaders(token),
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de changement de mot de passe');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Upload photo de profil
  static Future<Map<String, dynamic>> uploadProfileImage(String token, File imageFile) async {
    await _ensureInitialized();
    
    developer.log('🔄 Upload image START', name: 'ApiService');
    developer.log('URL: $baseUrl$apiPrefix/user/upload-profile-image', name: 'ApiService');
    developer.log('File: ${imageFile.path}', name: 'ApiService');
    
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/user/upload-profile-image'),
      );

      // Pour MultipartRequest, on n'ajoute que Authorization (pas Content-Type)
      request.headers['Authorization'] = 'Bearer $token';
      
      developer.log('Headers: ${request.headers}', name: 'ApiService');
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          imageFile.path,
          filename: path.basename(imageFile.path),
          contentType: MediaType('image', path.extension(imageFile.path).substring(1)),
        ),
      );

      developer.log('Sending request...', name: 'ApiService');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      developer.log('Response status: ${response.statusCode}', name: 'ApiService');
      developer.log('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}', name: 'ApiService');
      
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ Upload SUCCESS', name: 'ApiService');
        return data;
      } else {
        developer.log('❌ Upload FAILED: ${data['message']}', name: 'ApiService');
        throw Exception(data['message'] ?? 'Erreur d\'upload');
      }
    } catch (e) {
      developer.log('❌ Upload ERROR: $e', name: 'ApiService');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer photo de profil
  static Future<Map<String, dynamic>> deleteProfileImage(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/user/delete-profile-image'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer compte
  static Future<Map<String, dynamic>> deleteAccount(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/user/delete-account'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // PUBLICATIONS
  // ========================================

  // Créer une publication
  static Future<Map<String, dynamic>> createPublication(
    String token, {
    required String content,
    String? type,
    double? latitude,
    double? longitude,
    String? address,
    String? placeName,
    List<String>? tags,
    String? category,
    String? visibility,
    List<File>? mediaFiles,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/publications'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      // Champs texte
      request.fields['content'] = content;
      if (type != null) request.fields['type'] = type;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      if (address != null) request.fields['address'] = address;
      if (placeName != null) request.fields['placeName'] = placeName;
      if (tags != null && tags.isNotEmpty) request.fields['tags'] = tags.join(',');
      if (category != null) request.fields['category'] = category;
      if (visibility != null) request.fields['visibility'] = visibility;

      // Fichiers média
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var i = 0; i < mediaFiles.length; i++) {
          final file = mediaFiles[i];
          request.files.add(
            await http.MultipartFile.fromPath(
              'media',
              file.path,
              filename: path.basename(file.path),
              contentType: _getMediaType(file.path),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de création');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les publications
  static Future<Map<String, dynamic>> getPublications(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications?page=$page&limit=$limit'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les publications de l'utilisateur connecté uniquement
  static Future<Map<String, dynamic>> getMyPublications(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications/my?page=$page&limit=$limit'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer une publication par son ID (pour partage) - PUBLIQUE
  static Future<Map<String, dynamic>> getPublicationById(String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications/shared/$publicationId'),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'publication': data['publication'] ?? data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Publication introuvable',
        };
      }
    } catch (e) {
      debugPrint('❌ Erreur getPublicationById: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion',
      };
    }
  }

  // Obtenir les statistiques de partage d'une publication
  static Future<Map<String, dynamic>> getPublicationShareStats(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/share-stats'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'stats': data['stats'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de la récupération des stats',
        };
      }
    } catch (e) {
      debugPrint('❌ Erreur getPublicationShareStats: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion',
      };
    }
  }

  // Incrémenter le compteur de partages
  static Future<Map<String, dynamic>> incrementShareCount(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/share'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'shareCount': data['shareCount'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de l\'incrémentation',
        };
      }
    } catch (e) {
      debugPrint('❌ Erreur incrementShareCount: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion',
      };
    }
  }

  // Mettre à jour le token FCM de l'utilisateur
  static Future<Map<String, dynamic>> updateFCMToken(String token, String fcmToken) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/users/fcm-token'),
        headers: _authHeaders(token),
        body: json.encode({'fcmToken': fcmToken}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Token FCM mis à jour',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur mise à jour token',
        };
      }
    } catch (e) {
      debugPrint('❌ Erreur updateFCMToken: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion',
      };
    }
  }

  // Récupérer les publications d'un utilisateur
  static Future<Map<String, dynamic>> getUserPublications(String token, String userId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications/user/$userId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer une publication par ID
  static Future<Map<String, dynamic>> getPublication(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Publication non trouvée');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour une publication
  static Future<Map<String, dynamic>> updatePublication(
    String token,
    String publicationId, {
    String? content,
    double? latitude,
    double? longitude,
    String? address,
    String? placeName,
    List<String>? tags,
    String? category,
    String? visibility,
    List<File>? mediaFiles,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      if (content != null) request.fields['content'] = content;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      if (address != null) request.fields['address'] = address;
      if (placeName != null) request.fields['placeName'] = placeName;
      if (tags != null && tags.isNotEmpty) request.fields['tags'] = tags.join(',');
      if (category != null) request.fields['category'] = category;
      if (visibility != null) request.fields['visibility'] = visibility;

      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var file in mediaFiles) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'media',
              file.path,
              filename: path.basename(file.path),
              contentType: _getMediaType(file.path),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer une publication
  static Future<Map<String, dynamic>> deletePublication(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Liker/Disliker une publication
  static Future<Map<String, dynamic>> toggleLike(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/like'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de like');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Sauvegarder une publication
  static Future<Map<String, dynamic>> savePublication(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/save'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de sauvegarde');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Retirer une publication des sauvegardées
  static Future<Map<String, dynamic>> unsavePublication(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/save'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de retrait');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les publications sauvegardées
  static Future<Map<String, dynamic>> getSavedPublications(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/users/saved-publications'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les commentaires d'une publication
  // ========================================
  // COMMENTAIRES (Mini-Chat Temps Réel)
  // ========================================

  // Récupérer tous les commentaires d'une publication
  static Future<Map<String, dynamic>> getPublicationComments(String token, String publicationId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/comments'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Ajouter un commentaire (texte uniquement)
  static Future<Map<String, dynamic>> addComment(
    String token, 
    String publicationId, 
    String content, {
    String? replyTo,
  }) async {
    await _ensureInitialized();
    try {
      final body = {
        'content': content,
        if (replyTo != null) 'replyTo': replyTo,
      };

      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/comments'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'ajout de commentaire');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Ajouter un commentaire avec médias (images, vidéos, audio)
  static Future<Map<String, dynamic>> addCommentWithMedia(
    String token,
    String publicationId, {
    String? content,
    List<File>? mediaFiles,
    String? replyTo,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/comments'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      
      if (replyTo != null) {
        request.fields['replyTo'] = replyTo;
      }

      // Ajouter les fichiers médias
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var file in mediaFiles) {
          final mimeType = _getMimeType(file.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'media',
              file.path,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'ajout de commentaire');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Modifier un commentaire
  static Future<Map<String, dynamic>> updateComment(
    String token,
    String publicationId,
    String commentId,
    String content,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/comments/$commentId'),
        headers: _authHeaders(token),
        body: json.encode({'content': content}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de modification');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un commentaire
  static Future<Map<String, dynamic>> deleteComment(
    String token,
    String publicationId,
    String commentId,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/comments/$commentId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Liker/Unliker un commentaire
  static Future<Map<String, dynamic>> likeComment(
    String token,
    String publicationId,
    String commentId,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/comments/$commentId/like'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de like');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un média d'une publication
  static Future<Map<String, dynamic>> deletePublicationMedia(
    String token,
    String publicationId,
    int mediaIndex,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/publications/$publicationId/media/$mediaIndex'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // MARQUEURS
  // ========================================

  // Créer un marqueur
  static Future<Map<String, dynamic>> createMarker(
    String token, {
    required double latitude,
    required double longitude,
    required String title,
    String? comment,
    String? color,
    List<File>? photos,
    List<File>? videos,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/markers'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['title'] = title;
      if (comment != null) request.fields['comment'] = comment;
      if (color != null) request.fields['color'] = color;

      // Photos
      if (photos != null && photos.isNotEmpty) {
        for (var photo in photos) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'photos',
              photo.path,
              filename: path.basename(photo.path),
              contentType: MediaType('image', path.extension(photo.path).substring(1)),
            ),
          );
        }
      }

      // Vidéos
      if (videos != null && videos.isNotEmpty) {
        for (var video in videos) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'videos',
              video.path,
              filename: path.basename(video.path),
              contentType: MediaType('video', path.extension(video.path).substring(1)),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de création');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer tous les marqueurs
  static Future<Map<String, dynamic>> getMarkers(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/markers'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les marqueurs d'un utilisateur
  static Future<Map<String, dynamic>> getUserMarkers(String token, String userId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/markers/user/$userId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer un marqueur par ID
  static Future<Map<String, dynamic>> getMarker(String token, String markerId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/markers/$markerId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Marqueur non trouvé');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour un marqueur
  static Future<Map<String, dynamic>> updateMarker(
    String token,
    String markerId, {
    String? title,
    String? comment,
    String? color,
    List<File>? photos,
    List<File>? videos,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl$apiPrefix/markers/$markerId'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      if (title != null) request.fields['title'] = title;
      if (comment != null) request.fields['comment'] = comment;
      if (color != null) request.fields['color'] = color;

      if (photos != null && photos.isNotEmpty) {
        for (var photo in photos) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'photos',
              photo.path,
              filename: path.basename(photo.path),
              contentType: MediaType('image', path.extension(photo.path).substring(1)),
            ),
          );
        }
      }

      if (videos != null && videos.isNotEmpty) {
        for (var video in videos) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'videos',
              video.path,
              filename: path.basename(video.path),
              contentType: MediaType('video', path.extension(video.path).substring(1)),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un marqueur
  static Future<Map<String, dynamic>> deleteMarker(String token, String markerId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/markers/$markerId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un média d'un marqueur
  static Future<Map<String, dynamic>> deleteMarkerMedia(
    String token,
    String markerId,
    String type,
    int index,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/markers/$markerId/media/$type/$index'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // STORIES (STATUTS)
  // ========================================

  // Récupérer toutes les stories actives (dernières 24h)
  static Future<Map<String, dynamic>> getStories(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/stories'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Créer une story
  static Future<Map<String, dynamic>> createStory(
    String token, {
    String? content,
    File? mediaFile,
    String? mediaType,
    String? backgroundColor,
    int duration = 5,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/stories'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      // Champs optionnels
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (backgroundColor != null) {
        request.fields['backgroundColor'] = backgroundColor;
      }
      request.fields['duration'] = duration.toString();
      if (mediaType != null) {
        request.fields['mediaType'] = mediaType;
      }

      // Fichier média (image ou vidéo)
      if (mediaFile != null) {
        String mimeType = mediaType == 'video' ? 'video' : 'image';
        String extension = path.extension(mediaFile.path).substring(1);
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'media',
            mediaFile.path,
            filename: path.basename(mediaFile.path),
            contentType: MediaType(mimeType, extension),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          return data;
        } catch (e) {
          // Si le parsing JSON échoue mais que le statut est 201, considérer comme succès
          return {'success': true, 'message': 'Story créée avec succès'};
        }
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Erreur de création');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Marquer une story comme vue
  static Future<Map<String, dynamic>> viewStory(String token, String storyId) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/stories/$storyId/view'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'enregistrement de vue');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les vues d'une story (avec profils des utilisateurs)
  static Future<Map<String, dynamic>> getStoryViews(String token, String storyId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/stories/$storyId/views'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 403) {
        throw Exception('Seul l\'auteur peut voir qui a vu sa story');
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des vues');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer une story
  static Future<Map<String, dynamic>> deleteStory(String token, String storyId) async {
    await _ensureInitialized();
    debugPrint('🗑️ API_SERVICE: deleteStory appelée avec storyId: $storyId');
    debugPrint('🔑 API_SERVICE: Token length: ${token.length}');
    debugPrint('🌐 API_SERVICE: URL complète: $baseUrl$apiPrefix/stories/$storyId');
    
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/stories/$storyId'),
        headers: _authHeaders(token),
      );

      debugPrint('📡 API_SERVICE: Status code: ${response.statusCode}');
      debugPrint('📡 API_SERVICE: Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          debugPrint('✅ API_SERVICE: Suppression réussie, data: $data');
          return data;
        } catch (e) {
          // Si le parsing JSON échoue mais que le statut est 200, considérer comme succès
          debugPrint('⚠️ API_SERVICE: Parsing JSON échoué, mais status 200: $e');
          return {'success': true, 'message': 'Story supprimée'};
        }
      } else {
        final data = json.decode(response.body);
        debugPrint('❌ API_SERVICE: Erreur ${response.statusCode}: ${data['message']}');
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      debugPrint('❌ API_SERVICE: Exception générale: $e');
      if (e is Exception) rethrow;
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // GESTION DES EMPLOYÉS (ADMIN)
  // ========================================

  // Lister les employés avec filtres
  static Future<Map<String, dynamic>> getEmployees(
    String token, {
    String? search,
    String? department,
    String? status,
    String? sortBy,
    String? order,
  }) async {
    await _ensureInitialized();
    try {
      // Construire les query parameters
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (department != null && department.isNotEmpty) queryParams['department'] = department;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (sortBy != null && sortBy.isNotEmpty) queryParams['sortBy'] = sortBy;
      if (order != null && order.isNotEmpty) queryParams['order'] = order;

      final uri = Uri.parse('$baseUrl$apiPrefix/employees').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Créer un employé
  static Future<Map<String, dynamic>> createEmployee(
    String token, {
    required String name,
    required String email,
    required String phone,
    String? department,
    String? role,
    File? faceImage,
    File? certificate,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? certificateStartDate,
    DateTime? certificateEndDate,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/employees'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['phone'] = phone;
      if (department != null) request.fields['department'] = department;
      if (role != null) request.fields['role'] = role;

      if (startDate != null) request.fields['startDate'] = startDate.toIso8601String();
      if (endDate != null) request.fields['endDate'] = endDate.toIso8601String();
      if (certificateStartDate != null) request.fields['certificateStartDate'] = certificateStartDate.toIso8601String();
      if (certificateEndDate != null) request.fields['certificateEndDate'] = certificateEndDate.toIso8601String();

      if (faceImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'faceImage',
            faceImage.path,
            filename: path.basename(faceImage.path),
            contentType: MediaType('image', path.extension(faceImage.path).substring(1)),
          ),
        );
      }

      if (certificate != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'certificate',
            certificate.path,
            filename: path.basename(certificate.path),
            contentType: MediaType('application', 'pdf'),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de création');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour un employé
  static Future<Map<String, dynamic>> updateEmployee(
    String token,
    String employeeId, {
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    File? faceImage,
    File? certificate,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? certificateStartDate,
    DateTime? certificateEndDate,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl$apiPrefix/employees/$employeeId'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      if (name != null) request.fields['name'] = name;
      if (email != null) request.fields['email'] = email;
      if (phone != null) request.fields['phone'] = phone;
      if (role != null) request.fields['role'] = role;
      if (department != null) request.fields['department'] = department;
      if (startDate != null) request.fields['startDate'] = startDate.toIso8601String();
      if (endDate != null) request.fields['endDate'] = endDate.toIso8601String();
      if (certificateStartDate != null) request.fields['certificateStartDate'] = certificateStartDate.toIso8601String();
      if (certificateEndDate != null) request.fields['certificateEndDate'] = certificateEndDate.toIso8601String();

      if (faceImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'faceImage',
            faceImage.path,
            filename: path.basename(faceImage.path),
            contentType: MediaType('image', path.extension(faceImage.path).substring(1)),
          ),
        );
      }

      if (certificate != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'certificate',
            certificate.path,
            filename: path.basename(certificate.path),
            contentType: MediaType('application', 'pdf'),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un employé
  static Future<Map<String, dynamic>> deleteEmployee(String token, String employeeId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/employees/$employeeId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // GESTION DES NOTIFICATIONS
  // ========================================

  // Récupérer les notifications
  static Future<Map<String, dynamic>> getNotifications(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/notifications'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'notifications': data['notifications'] ?? data,
          'unreadCount': data['unreadCount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur de récupération',
        };
      }
    } catch (e) {
      debugPrint('❌ Erreur getNotifications: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  // Marquer une notification comme lue
  static Future<Map<String, dynamic>> markNotificationAsRead(String token, String notificationId) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/notifications/$notificationId/read'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Notification marquée comme lue',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur',
        };
      }
    } catch (e) {
      debugPrint('❌ Erreur markNotificationAsRead: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  // Marquer toutes les notifications comme lues
  static Future<Map<String, dynamic>> markAllNotificationsAsRead(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/notifications/read-all'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer une notification
  static Future<Map<String, dynamic>> deleteNotification(String token, String notificationId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/notifications/$notificationId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // GESTION DES UTILISATEURS (ADMIN)
  // ========================================

  // Récupérer les statistiques admin
  static Future<Map<String, dynamic>> getAdminStats(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/admin/stats'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des statistiques');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les statistiques (accessible à tous les utilisateurs authentifiés)
  // Retourne des données selon les permissions (employés voient seulement publications)
  static Future<Map<String, dynamic>> getStats(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/stats'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des statistiques');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les statistiques de stockage de l'utilisateur
  static Future<Map<String, dynamic>> getUserStorage(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/users/me/storage'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération du stockage');
      }
    } catch (e) {
      developer.log('❌ Erreur getUserStorage: $e', name: 'ApiService');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Lister les utilisateurs (accessible à tous les utilisateurs authentifiés)
  static Future<Map<String, dynamic>> getUsersList(String token) async {
    await _ensureInitialized();
    try {
      developer.log('🔍 Récupération de la liste des utilisateurs via /users', name: 'ApiService');
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/users'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        developer.log('✅ Liste des utilisateurs récupérée avec succès', name: 'ApiService');
        return data;
      } else {
        developer.log('❌ Erreur récupération utilisateurs: ${response.statusCode} - ${data['message']}', name: 'ApiService');
        throw Exception(data['message'] ?? 'Erreur de récupération des utilisateurs');
      }
    } catch (e) {
      developer.log('❌ Erreur générale getUsersList: $e', name: 'ApiService');
      throw Exception('Erreur de connexion: $e');
    }
  }  // Lister les utilisateurs (ADMIN seulement - données complètes)
  static Future<Map<String, dynamic>> getUsers(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/users'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Changer le statut d'un utilisateur
  static Future<Map<String, dynamic>> updateUserStatus(
    String token,
    String userId,
    String status,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/users/$userId/status'),
        headers: _authHeaders(token),
        body: json.encode({'status': status}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Changer le niveau d'accès d'un utilisateur
  static Future<Map<String, dynamic>> updateUserAccessLevel(
    String token,
    String userId,
    int accessLevel,
  ) async {
    await _ensureInitialized();
    debugPrint('🔄 [API] updateUserAccessLevel - Début');
    debugPrint('   UserId: $userId');
    debugPrint('   AccessLevel: $accessLevel');
    debugPrint('   BaseUrl: $baseUrl');

    try {
      final url = '$baseUrl$apiPrefix/users/$userId/access-level';
      debugPrint('📡 [API] URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: _authHeaders(token),
        body: json.encode({'accessLevel': accessLevel}),
      );

      debugPrint('📡 [API] Status Code: ${response.statusCode}');
      debugPrint('📡 [API] Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ [API] updateUserAccessLevel - Succès');
        return data;
      } else {
        debugPrint('❌ [API] updateUserAccessLevel - Erreur ${response.statusCode}: ${data['message']}');
        throw Exception(data['message'] ?? 'Erreur de mise à jour du niveau d\'accès');
      }
    } catch (e) {
      debugPrint('❌ [API] updateUserAccessLevel - Exception: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Basculer l'accès au chat IA pour un utilisateur
  static Future<Map<String, dynamic>> toggleAiChatAccess(
    String token,
    String userId,
  ) async {
    await _ensureInitialized();
    debugPrint('🔄 [API] toggleAiChatAccess - Début');
    debugPrint('   UserId: $userId');
    debugPrint('   BaseUrl: $baseUrl');

    try {
      final url = '$baseUrl$apiPrefix/users/$userId/ai-chat-access';
      debugPrint('📡 [API] URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: _authHeaders(token),
      );

      debugPrint('📡 [API] Status Code: ${response.statusCode}');
      debugPrint('📡 [API] Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ [API] toggleAiChatAccess - Succès');
        return data;
      } else {
        debugPrint('❌ [API] toggleAiChatAccess - Erreur ${response.statusCode}: ${data['message']}');
        throw Exception(data['message'] ?? 'Erreur de basculement accès chat IA');
      }
    } catch (e) {
      debugPrint('❌ [API] toggleAiChatAccess - Exception: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Basculer l'accès à la messagerie pour un utilisateur
  static Future<Map<String, dynamic>> toggleMessageAccess(
    String token,
    String userId,
  ) async {
    await _ensureInitialized();
    debugPrint('🔄 [API] toggleMessageAccess - Début');
    debugPrint('   UserId: $userId');
    debugPrint('   BaseUrl: $baseUrl');

    try {
      final url = '$baseUrl$apiPrefix/users/$userId/message-access';
      debugPrint('📡 [API] URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: _authHeaders(token),
      );

      debugPrint('📡 [API] Status Code: ${response.statusCode}');
      debugPrint('📡 [API] Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ [API] toggleMessageAccess - Succès');
        return data;
      } else {
        debugPrint('❌ [API] toggleMessageAccess - Erreur ${response.statusCode}: ${data['message']}');
        throw Exception(data['message'] ?? 'Erreur de basculement accès messagerie');
      }
    } catch (e) {
      debugPrint('❌ [API] toggleMessageAccess - Exception: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un utilisateur
  static Future<Map<String, dynamic>> deleteUser(String token, String userId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/users/$userId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // MÉTHODES UTILITAIRES PRIVÉES
  // ========================================

  // Obtenir les informations du serveur (utilise l'URL dynamique)
  static Future<Map<String, dynamic>> getServerInfo() async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/server-info'),
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Déterminer le type MIME d'un fichier média
  static MediaType _getMediaType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      case '.webp':
        return MediaType('image', 'webp');
      case '.mp4':
        return MediaType('video', 'mp4');
      case '.avi':
        return MediaType('video', 'avi');
      case '.mov':
        return MediaType('video', 'mov');
      case '.wmv':
        return MediaType('video', 'wmv');
      case '.flv':
        return MediaType('video', 'flv');
      case '.webm':
        return MediaType('video', 'webm');
      case '.mkv':
        return MediaType('video', 'mkv');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  // ========================================
  // COMMUNICATION (EMAIL, WHATSAPP, APPELS)
  // ========================================

  // Envoyer un email à un employé
  static Future<Map<String, dynamic>> sendEmailToEmployee(
    String token,
    String employeeId,
    String subject,
    String message,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/employees/$employeeId/send-email'),
        headers: _authHeaders(token),
        body: json.encode({
          'subject': subject,
          'message': message,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de l\'envoi de l\'email');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Obtenir le lien WhatsApp pour contacter un employé
  static Future<Map<String, dynamic>> getWhatsAppLink(
    String token,
    String employeeId, {
    String? message,
  }) async {
    await _ensureInitialized();
    try {
      final queryParams = message != null ? {'message': message} : <String, String>{};
      final uri = Uri.parse('$baseUrl$apiPrefix/employees/$employeeId/whatsapp-link')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la génération du lien WhatsApp');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Obtenir les informations pour appeler un employé
  static Future<Map<String, dynamic>> getCallInfo(
    String token,
    String employeeId,
  ) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/employees/$employeeId/call'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la récupération du numéro');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ============= STATISTIQUES =============

  // Récupérer les statistiques globales
  Future<Map<String, dynamic>> getStatisticsOverview(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/statistics/overview'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['statistics'];
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les données de géolocalisation
  Future<Map<String, dynamic>> getGeolocationData(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/statistics/geolocation'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ✅ NOUVELLE MÉTHODE - Récupérer les publications géolocalisées
  Future<Map<String, dynamic>> getGeolocatedPublications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/publications/geolocated'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ✅ NOUVELLE MÉTHODE - Mettre à jour la position GPS d'un employé
  Future<Map<String, dynamic>> updateEmployeeLocation({
    required String token,
    required String employeeId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/employees/$employeeId/location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les employés en ligne
  Future<Map<String, dynamic>> getOnlineEmployees(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/statistics/online-employees'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les détails par département
  Future<Map<String, dynamic>> getDepartmentsDetails(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/statistics/departments-details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ============ CHAT DE GROUPE ============
  
  // Récupérer les messages d'un groupe (utilise les routes existantes)
  Future<Map<String, dynamic>> getGroupMessages(String token, String groupId) async {
    try {
      // Utiliser la route correcte du serveur pour le groupe général
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/groups/$groupId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Transformer les données pour correspondre au format attendu
        return {
          'success': true,
          'messages': data['messages']?.map((msg) => {
            ...msg,
            'type': 'group_message'
          })?.toList() ?? []
        };
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les utilisateurs en ligne dans un groupe
  Future<Map<String, dynamic>> getGroupOnlineUsers(String token, String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/groups/$groupId/online'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Le serveur retourne 'onlineUsers', on le transforme en 'users' pour la compatibilité
        return {
          'success': true,
          'users': data['onlineUsers'] ?? []
        };
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Envoyer un message texte dans un groupe
  Future<Map<String, dynamic>> sendGroupMessage(
    String token,
    String groupId,
    String content, {
    String? replyTo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/groups/$groupId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content': content,
          if (replyTo != null) 'replyTo': replyTo,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Envoyer un message avec médias dans un groupe
  Future<Map<String, dynamic>> sendGroupMessageWithMedia(
    String token,
    String groupId, {
    String? content,
    required List<File> mediaFiles,
    String? replyTo,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/chat/groups/$groupId/messages'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }

      if (replyTo != null) {
        request.fields['replyTo'] = replyTo;
      }

      for (var file in mediaFiles) {
        final ext = file.path.split('.').last.toLowerCase();
        String fieldName;
        
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
          fieldName = 'images';
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
          fieldName = 'videos';
        } else if (['mp3', 'wav', 'm4a', 'ogg'].contains(ext)) {
          fieldName = 'audio';
        } else {
          fieldName = 'documents';
        }

        request.files.add(await http.MultipartFile.fromPath(
          fieldName,
          file.path,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Modifier un message
  Future<Map<String, dynamic>> updateGroupMessage(
    String token,
    String groupId,
    String messageId,
    String content,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/chat/groups/$groupId/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'content': content}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer un message
  Future<Map<String, dynamic>> deleteGroupMessage(
    String token,
    String groupId,
    String messageId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chat/groups/$groupId/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Réagir à un message
  Future<Map<String, dynamic>> reactToGroupMessage(
    String token,
    String groupId,
    String messageId,
    String emoji,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/groups/$groupId/messages/$messageId/react'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'emoji': emoji}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // MESSAGERIE PRIVÉE
  // ========================================

  // Récupérer les conversations privées
  static Future<Map<String, dynamic>> getMessageConversations(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/messages/conversations'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des conversations');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les messages d'une conversation privée
  static Future<Map<String, dynamic>> getPrivateMessages(String token, String userId) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/messages/$userId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des messages');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Envoyer un message privé (texte uniquement)
  static Future<Map<String, dynamic>> sendPrivateMessage(
    String token,
    String receiverId,
    String content, {
    String? replyTo,
  }) async {
    await _ensureInitialized();
    try {
      final body = {
        'receiverId': receiverId,
        'content': content,
        if (replyTo != null) 'replyTo': replyTo,
      };

      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/messages/send'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'envoi du message');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Envoyer un message privé avec médias
  static Future<Map<String, dynamic>> sendPrivateMessageWithMedia(
    String token,
    String receiverId, {
    String? content,
    List<File>? mediaFiles,
    String? replyTo,
  }) async {
    await _ensureInitialized();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$apiPrefix/messages/send'),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      request.fields['receiverId'] = receiverId;
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (replyTo != null) {
        request.fields['replyTo'] = replyTo;
      }

      // Ajouter les fichiers médias
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var file in mediaFiles) {
          final mimeType = _getMimeType(file.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'media',
              file.path,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur d\'envoi du message');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Marquer un message comme lu
  static Future<Map<String, dynamic>> markMessageAsRead(String token, String messageId) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/messages/$messageId/read'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de marquage comme lu');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // CARTES D'IDENTITÉ VIRTUELLES
  // ========================================

  // Créer une carte d'identité virtuelle
  static Future<Map<String, dynamic>> createVirtualIDCard(
    String token, {
    required Map<String, dynamic> cardData,
    Map<String, dynamic>? biometricData,
    bool forceRecreate = false,
    File? cardPdfFile,
  }) async {
    try {
      // ✅ MODE PRODUCTION: Utiliser directement l'URL Render
      final String serverUrl = ServerConfig.isProduction
        ? '${ServerConfig.productionUrl}/api/virtual-id-cards'
        : '$baseUrl$apiPrefix/virtual-id-cards';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(serverUrl),
      );

      request.headers.addAll(_multipartAuthHeaders(token));

      // Champs texte
      request.fields['cardData'] = json.encode(cardData);
      request.fields['biometricData'] = json.encode(biometricData ?? {});
      request.fields['forceRecreate'] = forceRecreate.toString();

      // Fichier PDF de la carte
      if (cardPdfFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'cardPdf',
            cardPdfFile.path,
            filename: path.basename(cardPdfFile.path),
            contentType: MediaType('application', 'pdf'),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de création de la carte');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer la carte d'identité virtuelle de l'utilisateur
  static Future<Map<String, dynamic>> getVirtualIDCard(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 404) {
        // Carte non trouvée - c'est normal, pas une erreur
        return {
          'success': false,
          'message': 'Carte d\'identité virtuelle non trouvée',
          'card': null
        };
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la récupération');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour la carte d'identité virtuelle
  static Future<Map<String, dynamic>> updateVirtualIDCard(
    String token, {
    Map<String, dynamic>? cardData,
    Map<String, dynamic>? biometricData,
  }) async {
    await _ensureInitialized();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards'),
        headers: _authHeaders(token),
        body: json.encode({
          'cardData': cardData,
          'biometricData': biometricData,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer la carte d'identité virtuelle
  static Future<Map<String, dynamic>> deleteVirtualIDCard(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 404) {
        // Carte non trouvée - c'est normal pour une suppression
        return {
          'success': false,
          'message': 'Carte d\'identité virtuelle non trouvée'
        };
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Authentifier via biométrie
  static Future<Map<String, dynamic>> authenticateBiometric({
    required String biometricType,
    required dynamic biometricData,
    String? deviceId,
  }) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards/authenticate'),
        headers: _defaultHeaders,
        body: json.encode({
          'biometricType': biometricType,
          'biometricData': biometricData,
          'deviceId': deviceId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Authentification échouée');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Vérifier un token d'authentification biométrique
  static Future<Map<String, dynamic>> verifyBiometricToken(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards/verify-token'),
        headers: _defaultHeaders,
        body: json.encode({'token': token}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Token invalide');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les statistiques de la carte
  static Future<Map<String, dynamic>> getVirtualIDCardStats(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards/stats'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des stats');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Vérifier si un email a une carte d'identité virtuelle
  static Future<Map<String, dynamic>> checkUserHasVirtualIDCard(String email) async {
    await _ensureInitialized();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards/check-user-card'),
        headers: _defaultHeaders,
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la vérification');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // ADMIN - GESTION DES CARTES D'IDENTITÉ
  // ========================================

  // Récupérer toutes les cartes d'identité (ADMIN)
  static Future<Map<String, dynamic>> getAllIDCards(String token) async {
    await _ensureInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards/admin/all'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de récupération des cartes');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer une carte d'identité par ID (ADMIN)
  static Future<Map<String, dynamic>> deleteVirtualIDCardById(String token, String cardId) async {
    await _ensureInitialized();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix/virtual-id-cards/admin/$cardId'),
        headers: _authHeaders(token),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Erreur de suppression de la carte');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}
