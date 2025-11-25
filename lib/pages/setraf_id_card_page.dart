import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../components/futuristic_card.dart';
import '../components/gradient_button.dart';
import '../theme/theme_provider.dart';

class SetrafIdCardPage extends StatefulWidget {
  const SetrafIdCardPage({super.key});

  @override
  State<SetrafIdCardPage> createState() => _SetrafIdCardPageState();
}

class _SetrafIdCardPageState extends State<SetrafIdCardPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  String _authMessage = '';
  Uint8List? _generatedCardImage;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();

      if (!canAuthenticate || !canAuthenticateWithBiometrics) {
        setState(() {
          _authMessage = 'Authentification biométrique non supportée sur cet appareil';
        });
      }
    } catch (e) {
      setState(() {
        _authMessage = 'Erreur lors de la vérification biométrique: $e';
      });
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _authMessage = '';
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authentifiez-vous pour générer votre carte SETRAF',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      setState(() {
        _isAuthenticated = authenticated;
        _isAuthenticating = false;
        if (authenticated) {
          _authMessage = 'Authentification réussie !';
          // Générer la carte automatiquement après authentification
          _generateIdCard();
        } else {
          _authMessage = 'Authentification échouée';
        }
      });
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _authMessage = 'Erreur d\'authentification: $e';
      });
    }
  }

  Future<void> _generateIdCard() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final user = appProvider.currentUser;

    if (user == null) {
      _showMessage('Utilisateur non trouvé');
      return;
    }

    try {
      // Créer une image de 400x250 pixels pour la carte
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 250);

      // Fond blanc
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Bordure verte
      final borderPaint = Paint()
        ..color = const Color(0xFF00FF88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), borderPaint);

      // En-tête SETRAF
      final headerPaint = Paint()..color = const Color(0xFF1A5F7A);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 50), headerPaint);

      // Texte "CARTE D'IDENTITÉ SETRAF"
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'CARTE D\'IDENTITÉ SETRAF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(20, 15));

      // Photo de profil (cercle blanc avec image)
      final profileImageUrl = user['profileImage'] as String?;
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        // Charger l'image depuis le réseau (simplifié - en production utiliser cached_network_image)
        // Pour cette démo, on dessine un cercle blanc
        final profilePaint = Paint()..color = Colors.white;
        canvas.drawCircle(const Offset(80, 120), 40, profilePaint);

        // Bordure du cercle
        final circleBorderPaint = Paint()
          ..color = const Color(0xFF00D4FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(const Offset(80, 120), 40, circleBorderPaint);
      }

      // Informations utilisateur
      final namePainter = TextPainter(
        text: TextSpan(
          text: user['name'] ?? 'Utilisateur',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(canvas, const Offset(140, 90));

      final emailPainter = TextPainter(
        text: TextSpan(
          text: user['email'] ?? 'email@example.com',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      emailPainter.layout();
      emailPainter.paint(canvas, const Offset(140, 115));

      // ID utilisateur
      final idPainter = TextPainter(
        text: TextSpan(
          text: 'ID: ${user['_id']?.substring(0, 8) ?? 'N/A'}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      idPainter.layout();
      idPainter.paint(canvas, const Offset(140, 135));

      // Date d'émission
      final datePainter = TextPainter(
        text: TextSpan(
          text: 'Émis le: ${DateTime.now().toString().substring(0, 10)}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      datePainter.layout();
      datePainter.paint(canvas, const Offset(20, 200));

      // Empreinte digitale transparente (overlay)
      // Charger l'image d'empreinte depuis les assets
      try {
        final fingerprintData = await rootBundle.load('assets/images/fingerprint.png');
        final fingerprintImage = await decodeImageFromList(fingerprintData.buffer.asUint8List());

        // Dessiner l'empreinte avec transparence
        final fingerprintPaint = Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..blendMode = BlendMode.multiply;

        // Positionner l'empreinte en bas à droite
        final fingerprintRect = Rect.fromLTWH(
          size.width - 80,
          size.height - 80,
          60,
          60,
        );

        canvas.saveLayer(fingerprintRect, Paint());
        canvas.drawImageRect(
          fingerprintImage,
          Rect.fromLTWH(0, 0, fingerprintImage.width.toDouble(), fingerprintImage.height.toDouble()),
          fingerprintRect,
          fingerprintPaint,
        );
        canvas.restore();
      } catch (e) {
        debugPrint('Erreur chargement empreinte: $e');
        // Dessiner une empreinte simple si l'image n'est pas disponible
        final simpleFingerprintPaint = Paint()
          ..color = Colors.black.withOpacity(0.2);
        canvas.drawCircle(Offset(size.width - 50, size.height - 50), 25, simpleFingerprintPaint);
      }

      // Finaliser l'image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        setState(() {
          _generatedCardImage = byteData.buffer.asUint8List();
        });

        _showMessage('Carte SETRAF générée avec succès !');
      }
    } catch (e) {
      debugPrint('Erreur génération carte: $e');
      _showMessage('Erreur lors de la génération de la carte: $e');
    }
  }

  Future<void> _saveAndShareCard() async {
    if (_generatedCardImage == null) {
      _showMessage('Aucune carte à sauvegarder');
      return;
    }

    try {
      // Sauvegarder dans le répertoire temporaire
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/carte_setraf_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_generatedCardImage!);

      // Partager le fichier
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Ma carte d\'identité SETRAF',
        subject: 'Carte SETRAF',
      );

      _showMessage('Carte sauvegardée et prête à partager !');
    } catch (e) {
      _showMessage('Erreur lors de la sauvegarde: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00D4FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appProvider = Provider.of<AppProvider>(context);
    final user = appProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte SETRAF'),
        backgroundColor: themeProvider.surfaceColor,
        foregroundColor: themeProvider.textColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: themeProvider.currentTheme.gradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // En-tête
                FuturisticCard(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Carte d\'Identité SETRAF',
                          style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Authentification biométrique requise',
                          style: TextStyle(
                            color: themeProvider.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Section authentification
                if (!_isAuthenticated) ...[
                  FuturisticCard(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Authentification Biométrique',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Utilisez votre empreinte digitale ou reconnaissance faciale pour générer votre carte d\'identité SETRAF.',
                            style: TextStyle(
                              color: themeProvider.textSecondaryColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (_authMessage.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _authMessage.contains('réussie')
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _authMessage.contains('réussie')
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              child: Text(
                                _authMessage,
                                style: TextStyle(
                                  color: _authMessage.contains('réussie')
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          GradientButton(
                            onPressed: _isAuthenticating ? null : _authenticate,
                            gradientColors: const [Color(0xFF00D4FF), Color(0xFF0099CC)],
                            child: _isAuthenticating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'S\'authentifier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Carte générée
                  if (_generatedCardImage != null) ...[
                    FuturisticCard(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Votre Carte SETRAF',
                              style: TextStyle(
                                color: themeProvider.textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _generatedCardImage!,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    onPressed: _saveAndShareCard,
                                    gradientColors: const [Color(0xFF00FF88), Color(0xFF00CC66)],
                                    child: const Text(
                                      'Sauvegarder & Partager',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isAuthenticated = false;
                                        _generatedCardImage = null;
                                        _authMessage = '';
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: themeProvider.primaryColor),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      'Nouvelle Carte',
                                      style: TextStyle(
                                        color: themeProvider.primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // En cours de génération
                    FuturisticCard(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: const Column(
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF00D4FF),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Génération de votre carte...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // Informations utilisateur
                if (user != null) ...[
                  FuturisticCard(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informations Utilisateur',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Nom', user['name'] ?? 'Non défini'),
                          _buildInfoRow('Email', user['email'] ?? 'Non défini'),
                          _buildInfoRow('Statut', user['status'] ?? 'Utilisateur'),
                          _buildInfoRow('ID', user['_id']?.substring(0, 8) ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: themeProvider.textSecondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}