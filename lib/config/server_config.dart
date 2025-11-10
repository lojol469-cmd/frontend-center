/// Configuration du serveur backend
/// 
/// Ce fichier centralise toutes les adresses IP possibles pour le serveur.
/// L'application essaiera automatiquement chaque adresse jusqu'à trouver celle qui fonctionne.
/// 
/// AJOUTER UNE NOUVELLE ADRESSE IP:
/// Ajoutez simplement l'IP dans la liste `serverIPs` ci-dessous.
/// 
/// EXEMPLES:
/// - WiFi maison: '192.168.1.98'
/// - Point d'accès mobile: '192.168.43.1'
/// - WiFi bureau: '10.0.0.5'
/// - VPN: '172.16.0.1'
library;

class ServerConfig {
  /// Port du serveur backend Node.js
  static const int serverPort = 5000;
  
  /// Liste des adresses IP à tester automatiquement
  /// L'ordre est important: la première IP qui répond sera utilisée
  static const List<String> serverIPs = [
    // IP actuelle WiFi (détectée par ipconfig)
    '192.168.1.66',
    
    // WiFi principal (alternative)
    '192.168.1.98',
    
    // Point d'accès mobile (hotspot)
    '192.168.43.1',
    
    // Émulateur Android
    '10.0.2.2',
    
    // Localhost (pour tests sur ordinateur)
    'localhost',
    '127.0.0.1',
    
    // AJOUTEZ VOS PROPRES IP ICI:
    // '192.168.0.100',  // Exemple: autre réseau WiFi
    // '10.0.0.50',      // Exemple: réseau bureau
  ];
  
  /// Timeout pour chaque test de connexion (en secondes)
  static const int connectionTimeout = 3;
  
  /// Endpoint pour tester la connexion au serveur
  static const String healthCheckEndpoint = '/api/server-info';
  
  /// Construire l'URL complète pour une IP donnée
  static String buildUrl(String ip) {
    return 'http://$ip:$serverPort';
  }
  
  /// Obtenir l'URL de test pour une IP
  static String getTestUrl(String ip) {
    return '${buildUrl(ip)}$healthCheckEndpoint';
  }
}
