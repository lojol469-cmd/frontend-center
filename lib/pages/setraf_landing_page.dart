import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class SetrafLandingPage extends StatefulWidget {
  const SetrafLandingPage({super.key});

  @override
  State<SetrafLandingPage> createState() => _SetrafLandingPageState();
}

class _SetrafLandingPageState extends State<SetrafLandingPage> {
  PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
    _enterFullscreen();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Créer le contrôleur PDF
      _pdfController = PdfController(
        document: PdfDocument.openAsset('assets/documents/presentation_setraf.pdf'),
      );

      // Attendre que le document soit chargé
      await _pdfController!.document;

      // Obtenir le nombre total de pages
      final document = await _pdfController!.document;
      final pageCount = document.pagesCount;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _totalPages = pageCount;
          _currentPage = 1; // PDF commence à la page 1
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement PDF: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors du chargement du PDF: $e';
        });
      }
    }
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  }

  @override
  void dispose() {
    _exitFullscreen();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black, // Fond noir pour contraste
      body: Stack(
        children: [
          // PDF en plein écran
          Positioned.fill(
            child: _buildBody(themeProvider),
          ),

          // Contrôles flottants en haut
          if (!_isFullscreen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 16,
                  right: 16,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Présentation SETRAF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_totalPages > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$_currentPage / $_totalPages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Bouton plein écran flottant
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              onPressed: _isFullscreen ? _exitFullscreen : _enterFullscreen,
              child: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeProvider themeProvider) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chargement du PDF...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Erreur de chargement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Contrôleur PDF non initialisé',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: PdfView(
        controller: _pdfController!,
        scrollDirection: Axis.vertical,
        onDocumentLoaded: (document) {
          debugPrint('✅ PDF chargé avec succès: ${document.pagesCount} pages');
        },
        onPageChanged: (page) {
          if (mounted) {
            setState(() {
              _currentPage = page + 1; // PDF commence à 0, affichage à 1
            });
          }
        },
        onDocumentError: (error) {
          debugPrint('❌ Erreur PDF: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Erreur du document PDF: $error';
            });
          }
        },
      ),
    );
  }
}