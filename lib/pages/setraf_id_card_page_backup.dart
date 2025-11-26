import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
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
      // Créer le document PDF
      final pdf = pw.Document();

      // Charger l'image de profil si disponible
      pw.ImageProvider? profileImage;
      final profileImageUrl = user['profileImage'] as String?;
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(profileImageUrl));
          if (response.statusCode == 200) {
            profileImage = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Erreur chargement image profil: $e');
        }
      }

      // Ajouter la page au PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              width: 400,
              height: 250,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#00FF88'), width: 4),
              ),
              child: pw.Stack(
                children: [
                  // Fond blanc
                  pw.Container(color: PdfColors.white),

                  // En-tête SETRAF
                  pw.Container(
                    width: 400,
                    height: 50,
                    color: PdfColor.fromHex('#1A5F7A'),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 20, top: 15),
                      child: pw.Text(
                        'CARTE D\'IDENTITÉ SETRAF',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Photo de profil
                  pw.Positioned(
                    left: 40,
                    top: 80,
                    child: pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColor.fromHex('#00D4FF'), width: 2),
                      ),
                      child: profileImage != null
                          ? pw.ClipOval(
                              child: pw.Image(profileImage, fit: pw.BoxFit.cover),
                            )
                          : pw.Center(
                              child: pw.Icon(
                                pw.IconData(0xe7fd), // person icon
                                color: PdfColors.grey,
                                size: 40,
                              ),
                            ),
                    ),
                  ),

                  // Informations utilisateur
                  pw.Positioned(
                    left: 140,
                    top: 90,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          user['name'] ?? 'Utilisateur',
                          style: pw.TextStyle(
                            color: PdfColors.black,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          user['email'] ?? 'email@example.com',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'ID: ${user['_id']?.substring(0, 8) ?? 'N/A'}',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Date d'émission
                  pw.Positioned(
                    left: 20,
                    bottom: 20,
                    child: pw.Text(
                      'Émis le: ${DateTime.now().toString().substring(0, 10)}',
                      style: pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 10,
                      ),
                    ),
                  ),

                  // Logo SETRAF
                  pw.Positioned(
                    right: 20,
                    bottom: 20,
                    child: pw.Container(
                      width: 60,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        gradient: pw.LinearGradient(
                          colors: [
                            PdfColor.fromHex('#00FF88'),
                            PdfColor.fromHex('#00CC66'),
                            PdfColor.fromHex('#009944'),
                          ],
                        ),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'SETRAF',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Empreinte digitale (optionnel)
                  pw.Positioned(
                    right: 20,
                    top: 80,
                    child: pw.Container(
                      width: 40,
                      height: 40,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '👆',
                          style: pw.TextStyle(
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Sauvegarder le PDF
      final output = await pdf.save();
      setState(() {
        _generatedCardImage = output;
      });

      _showMessage('Carte SETRAF générée avec succès !');
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
      final file = File('${tempDir.path}/carte_setraf_${DateTime.now().millisecondsSinceEpoch}.pdf');
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
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
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
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 200,
                                  color: Colors.white,
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf,
                                          size: 48,
                                          color: Color(0xFF00D4FF),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Carte PDF générée',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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