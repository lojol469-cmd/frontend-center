/// Configuration du serveur backend
/// 
/// En production, utilise directement l'URL Render sans détection automatique
library;

class ServerConfig {
  /// URL de production Render (HTTPS)
  static const String productionUrl = 'https://center-backend-v9rf.onrender.com';
  
  /// Port du serveur backend Node.js (pour développement local uniquement)
  static const int serverPort = 8001;
  
  /// Mode de production (true = utilise uniquement Render, false = détection auto)
  static const bool isProduction = true;
  
  /// Liste des adresses IP pour développement local (ignorée en production)
  static const List<String> serverIPs = [
    // IP du serveur AI backend
    '192.168.1.84',
    // IP locale pour tests en développement
    '192.168.1.66',
    '192.168.1.98',
    'localhost',
    '127.0.0.1',
  ];
  
  /// Timeout pour chaque test de connexion (en secondes)
  static const int connectionTimeout = 5;
  
  /// Endpoint pour tester la connexion au serveur
  static const String healthCheckEndpoint = '/api/server-info';
  
  /// Obtenir l'URL du serveur (production ou développement)
  static String getBaseUrl() {
    if (isProduction) {
      return productionUrl;
    }
    // En développement, utiliser la première IP locale
    return buildUrl(serverIPs.first);
  }
  
  /// Construire l'URL complète pour une IP donnée (dev uniquement)
  static String buildUrl(String ip) {
    if (ip.contains('onrender.com')) {
      return 'https://$ip';
    }
    return 'http://$ip:$serverPort';
  }
  
  /// Obtenir l'URL de test
  static String getTestUrl(String ip) {
    return '${buildUrl(ip)}$healthCheckEndpoint';
  }
}

