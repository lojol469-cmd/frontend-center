import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  String? _token;
  
  // Configuration dynamique depuis ApiService
  static const Duration reconnectDelay = Duration(seconds: 5);

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  /// Se connecter au WebSocket avec un token d'authentification
  Future<void> connect(String token) async {
    if (_isConnecting) {
      debugPrint('🔌 Connexion WebSocket déjà en cours...');
      return;
    }

    _token = token;
    _isConnecting = true;

    try {
      // Utiliser l'URL du serveur détecté par ApiService
      final baseUrl = ApiService.baseUrl.replaceAll('http://', '').replaceAll('https://', '');
      
      // Déterminer le protocole WebSocket (wss pour HTTPS, ws pour HTTP)
      final wsProtocol = ApiService.baseUrl.startsWith('https') ? 'wss' : 'ws';
      final wsUrl = '$wsProtocol://$baseUrl';
      
      debugPrint('🔌 Connexion WebSocket à $wsUrl...');
      
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      // Envoyer le token d'authentification
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': token,
      }));

      // Écouter les messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            debugPrint('📨 Message WebSocket reçu: ${data['type']}');
            _controller.add(data);
          } catch (e) {
            debugPrint('❌ Erreur parse message WebSocket: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Erreur WebSocket: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('🔌 WebSocket déconnecté');
          _handleDisconnect();
        },
      );

      _isConnecting = false;
      debugPrint('✅ WebSocket connecté');
    } catch (e) {
      debugPrint('❌ Erreur connexion WebSocket: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  /// Gérer la déconnexion et programmer une reconnexion
  void _handleDisconnect() {
    _channel = null;
    _isConnecting = false;
    
    if (_token != null) {
      _scheduleReconnect();
    }
  }

  /// Programmer une reconnexion automatique
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_token != null && !_isConnecting) {
        debugPrint('🔄 Tentative de reconnexion WebSocket...');
        connect(_token!);
      }
    });
  }

  /// Envoyer un message au serveur
  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
      debugPrint('📤 Message envoyé: ${data['type']}');
    } else {
      debugPrint('⚠️ WebSocket non connecté, impossible d\'envoyer le message');
    }
  }

  /// S'abonner à un canal spécifique
  void subscribe(String channel) {
    send({
      'type': 'subscribe',
      'channel': channel,
    });
  }

  /// Se désabonner d'un canal
  void unsubscribe(String channel) {
    send({
      'type': 'unsubscribe',
      'channel': channel,
    });
  }

  /// Se déconnecter proprement
  void disconnect() {
    debugPrint('🔌 Déconnexion WebSocket...');
    _reconnectTimer?.cancel();
    _token = null;
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
  }

  /// Nettoyer les ressources
  void dispose() {
    disconnect();
    _controller.close();
  }
}
