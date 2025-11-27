import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../api_service.dart';
import '../components/futuristic_card.dart';
import '../components/gradient_button.dart';
import '../components/image_background.dart';
import '../components/theme_selector.dart';
import '../theme/theme_provider.dart';
import '../pages/setraf_id_card_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _publicationsCount = 0;
  int _employeesCount = 0;
  bool _isLoadingStats = false;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();
  late String _selectedImage;
  
  // Statistiques de stockage
  Map<String, dynamic>? _storageInfo;
  bool _isLoadingStorage = false;
  
  // Gestion de la carte ID
  Map<String, dynamic>? _virtualIDCard;
  bool _isLoadingIDCard = false;
  Map<String, dynamic>? _cardStats; // Statistiques réelles de la carte
  bool _isLoadingCardStats = false;

  // Gestion des publications pour libérer l'espace
  List<Map<String, dynamic>> _myPublications = [];
  bool _isLoadingPublications = false;
  final Set<String> _selectedPublicationsToDelete = {};

  @override
  void initState() {
    super.initState();
    _selectedImage = 'assets/images/background_profile.jpg'; // Image par défaut
    _loadUserStats();
    _loadStorageInfo();
    _loadMyPublications();
    _loadVirtualIDCard();
    _loadCardStats();
  }
  Future<void> _loadUserStats() async {
    // Éviter les appels simultanés - VÉRIFIER EN PREMIER
    if (_isLoadingStats) {
      debugPrint('⏳ Chargement déjà en cours, ignoré');
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    final user = appProvider.currentUser;

    if (token == null) {
      debugPrint('⚠️ Token manquant');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
      return;
    }

    // Vérifier si l'utilisateur est admin
    final isAdmin = user?['status'] == 'admin' || 
                   user?['email'] == 'nyundumathryme@gmail.com' ||
                   user?['email'] == 'nyundumathryme@gmail';

    if (mounted) {
      setState(() => _isLoadingStats = true);
    }

    try {
      // Charger les statistiques (backend filtrera selon les permissions)
      final stats = await ApiService.getStats(token);
      debugPrint('📊 Statistiques reçues: $stats');
      
      if (mounted) {
        // Extraire les totaux des publications (accessible à tous)
        final pubCount = stats['publications']?['total'] ?? 0;
        
        // Extraire le nombre d'employés (disponible uniquement pour les admins)
        final empCount = stats['employees']?['total'] ?? 0;
        
        debugPrint('📊 Nombre total de publications: $pubCount');
        debugPrint('📊 Nombre total d\'employés: $empCount (Admin: $isAdmin)');
        
        setState(() {
          _publicationsCount = pubCount;
          _employeesCount = empCount;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  /// Charger les informations de stockage
  Future<void> _loadStorageInfo() async {
    if (_isLoadingStorage) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      debugPrint('⚠️ Token manquant pour stockage');
      return;
    }

    setState(() => _isLoadingStorage = true);

    try {
      final result = await ApiService.getUserStorage(token);
      debugPrint('💾 Stockage reçu: $result');

      if (mounted && result['success'] == true) {
        setState(() {
          _storageInfo = result['storage'];
          _isLoadingStorage = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement stockage: $e');
      if (mounted) {
        setState(() => _isLoadingStorage = false);
      }
    }
  }

  /// Charger les statistiques réelles de la carte d'identité virtuelle
  Future<void> _loadCardStats() async {
    if (_isLoadingCardStats) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      debugPrint('⚠️ Token manquant pour charger les stats de la carte');
      return;
    }

    setState(() => _isLoadingCardStats = true);

    try {
      final result = await ApiService.getVirtualIDCardStats(token);
      debugPrint('📊 Stats carte reçues: ${result['success']}');

      if (mounted && result['success'] == true) {
        setState(() {
          _cardStats = result['stats'];
          _isLoadingCardStats = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingCardStats = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement stats carte: $e');
      if (mounted) {
        setState(() => _isLoadingCardStats = false);
      }
    }
  }

  /// Charger la carte ID virtuelle de l'utilisateur
  Future<void> _loadVirtualIDCard() async {
    if (_isLoadingIDCard) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      debugPrint('⚠️ Token manquant pour charger la carte ID');
      return;
    }

    setState(() => _isLoadingIDCard = true);

    try {
      final result = await ApiService.getVirtualIDCard(token);
      debugPrint('🆔 Carte ID reçue: ${result['success']}');

      if (mounted && result['success'] == true) {
        setState(() {
          _virtualIDCard = result['card'];
          _isLoadingIDCard = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingIDCard = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement carte ID: $e');
      if (mounted) {
        setState(() => _isLoadingIDCard = false);
      }
    }
  }

  /// Renouveler automatiquement la carte ID (change l'ID tous les 3 mois)
  /// Routes backend requises:
  /// - POST /api/virtual-id-cards/renew : renouvelle la carte avec un nouvel ID
  /// - La route doit vérifier la date d'expiration et générer un nouvel ID si expiré
  /// - Format ID: SETRAF-{timestamp}-{userId_suffix}
  Future<void> _renewVirtualIDCard() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      _showMessage('Non authentifié');
      return;
    }

    try {
      _showMessage('Renouvellement de la carte en cours...');
      
      final result = await ApiService.renewVirtualIDCard(token);
      
      if (result['success'] == true) {
        // Recharger les données de la carte
        await _loadVirtualIDCard();
        _showMessage('Carte renouvelée avec succès ! Nouvel ID généré.');
      } else {
        _showMessage('Erreur lors du renouvellement: ${result['message'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      debugPrint('❌ Erreur renouvellement carte: $e');
      _showMessage('Erreur lors du renouvellement: $e');
    }
  }

  /// Charger les publications de l'utilisateur pour gestion du stockage
  Future<void> _loadMyPublications() async {
    if (_isLoadingPublications) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;
    final userId = appProvider.currentUser?['_id'];

    if (token == null || userId == null) {
      debugPrint('⚠️ Token ou userId manquant');
      return;
    }

    setState(() => _isLoadingPublications = true);

    try {
      // Récupérer toutes les publications de l'utilisateur
      final result = await ApiService.getUserPublications(token, userId);
      debugPrint('📄 Publications reçues: ${result['publications']?.length ?? 0}');

      if (mounted && result['success'] == true) {
        final pubs = result['publications'] as List? ?? [];
        setState(() {
          _myPublications = pubs.map((p) => p as Map<String, dynamic>).toList();
          _isLoadingPublications = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement publications: $e');
      if (mounted) {
        setState(() => _isLoadingPublications = false);
      }
    }
  }

  /// Supprimer les publications sélectionnées
  Future<void> _deleteSelectedPublications() async {
    if (_selectedPublicationsToDelete.isEmpty) {
      _showMessage('Aucune publication sélectionnée');
      return;
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      _showMessage('Non authentifié');
      return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer ${_selectedPublicationsToDelete.length} publication(s) ?\n\nCette action libérera de l\'espace de stockage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Supprimer chaque publication
    int deletedCount = 0;
    for (final pubId in _selectedPublicationsToDelete) {
      try {
        await ApiService.deletePublication(token, pubId);
        deletedCount++;
      } catch (e) {
        debugPrint('❌ Erreur suppression $pubId: $e');
      }
    }

    // Actualiser les données
    _selectedPublicationsToDelete.clear();
    await _loadMyPublications();
    await _loadStorageInfo();
    await _loadUserStats();

    if (mounted) {
      _showMessage('$deletedCount publication(s) supprimée(s) ✓');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      _showMessage('Non authentifié');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      debugPrint('🔄 Upload image - Token: ${token.substring(0, 20)}...');
      debugPrint('🔄 Upload image - BaseURL: ${ApiService.baseUrl}');
      debugPrint('🔄 Upload image - File path: ${image.path}');

      final result = await ApiService.uploadProfileImage(
        token,
        File(image.path),
      );

      debugPrint('✅ Upload réussi: ${result['user']?['profileImage']}');

      if (mounted) {
        setState(() => _isUploadingImage = false);

        // Mettre à jour l'utilisateur dans AppProvider
        final updatedUser = Map<String, dynamic>.from(appProvider.currentUser ?? {});
        updatedUser['profileImage'] = result['user']?['profileImage'] ?? '';
        appProvider.setAuthenticated(true, token: token, user: updatedUser);

        _showMessage('Photo de profil mise à jour !');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showMessage('Erreur: $e');
      }
      debugPrint('Erreur upload image: $e');
    }
  }

  Future<void> _deleteProfileImage() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Supprimer la photo', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment supprimer votre photo de profil ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteProfileImage(token);

      if (mounted) {
        // Mettre à jour l'utilisateur dans AppProvider
        final updatedUser = Map<String, dynamic>.from(appProvider.currentUser ?? {});
        updatedUser['profileImage'] = '';
        appProvider.setAuthenticated(true, token: token, user: updatedUser);

        _showMessage('Photo supprimée');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erreur: $e');
      }
      debugPrint('Erreur suppression image: $e');
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

  void _navigateToSetrafCard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SetrafIdCardPage(),
      ),
    ).then((_) => _loadVirtualIDCard());
  }

  Future<void> _showChangePasswordDialog(BuildContext context, AppProvider appProvider) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final token = appProvider.accessToken;

    if (token == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Changer le mot de passe', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D4FF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D4FF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D4FF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Changer', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );

    if (result != true) return;

    // Validation
    if (currentPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showMessage('Tous les champs sont requis');
      return;
    }

    if (newPasswordController.text.length < 6) {
      _showMessage('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      _showMessage('Les mots de passe ne correspondent pas');
      return;
    }

    try {
      final response = await ApiService.changePassword(
        token,
        currentPasswordController.text,
        newPasswordController.text,
      );

      if (mounted) {
        // Mettre à jour l'utilisateur dans AppProvider
        final updatedUser = response['user'] as Map<String, dynamic>;
        appProvider.setAuthenticated(true, token: token, user: updatedUser);

        _showMessage('Mot de passe changé avec succès !');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erreur: $e');
      }
      debugPrint('Erreur changement mot de passe: $e');
    }
  }

  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic>? user, AppProvider appProvider) {
    final profileImage = user?['profileImage'] ?? '';
    final hasImage = profileImage.isNotEmpty;

    return FuturisticCard(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasImage
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    image: hasImage
                        ? DecorationImage(
                            image: NetworkImage(profileImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _isUploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : !hasImage
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.black,
                              size: 60,
                            )
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'upload') {
                          _pickAndUploadImage();
                        } else if (value == 'delete') {
                          _deleteProfileImage();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'upload',
                          child: Row(
                            children: [
                              Icon(Icons.upload_rounded, color: Color(0xFF00D4FF)),
                              SizedBox(width: 12),
                              Text('Changer la photo'),
                            ],
                          ),
                        ),
                        if (hasImage)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Supprimer la photo'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user?['name'] ?? 'Utilisateur',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?['email'] ?? 'email@example.com',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                'Membre Actif',
                style: TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Indicateur de carte ID avec accès direct
            if (_isLoadingIDCard)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Vérification carte...',
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_virtualIDCard != null)
              InkWell(
                onTap: () => _navigateToSetrafCard(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF00FF88),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Carte trouvée pour ${user?['email']?.split('@')[0] ?? 'cet email'}',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: const Color(0xFF00FF88).withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              )
            else
              InkWell(
                onTap: () => _navigateToSetrafCard(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAA00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFAA00).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.credit_card_rounded,
                        color: Color(0xFFFFAA00),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Créer carte SETRAF',
                        style: TextStyle(
                          color: Color(0xFFFFAA00),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.add_rounded,
                        color: const Color(0xFFFFAA00).withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, AppProvider appProvider) {
    final user = appProvider.currentUser;
    
    // Vérifier si l'utilisateur est admin
    final isAdmin = user?['status'] == 'admin' || 
                   user?['email'] == 'nyundumathryme@gmail.com' ||
                   user?['email'] == 'nyundumathryme@gmail';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            title: 'Publications',
            value: _isLoadingStats ? '...' : '$_publicationsCount',
            icon: Icons.article_rounded,
            color: const Color(0xFF00D4FF),
          ),
        ),
        // Afficher la carte Employés UNIQUEMENT pour les admins
        if (isAdmin) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              context,
              title: 'Employés',
              value: _isLoadingStats ? '...' : '$_employeesCount',
              icon: Icons.badge_rounded,
              color: const Color(0xFF00FF88),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return FuturisticCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings(BuildContext context, AppProvider appProvider) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return FuturisticCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Paramètres',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.fingerprint_rounded,
                title: 'Carte SETRAF',
                subtitle: 'Générer votre carte d\'identité biométrique',
                onTap: () => _navigateToSetrafCard(context),
              ),
              _buildSettingItem(
                context,
                icon: Icons.lock_rounded,
                title: 'Changer le mot de passe',
                subtitle: 'Modifier votre mot de passe',
                onTap: () => _showChangePasswordDialog(context, appProvider),
              ),
              _buildSettingItem(
                context,
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle: 'Gérer les notifications push',
                onTap: () => _showNotificationsSettings(context, appProvider),
              ),
              _buildSettingItem(
                context,
                icon: Icons.palette_rounded,
                title: 'Thème',
                subtitle: 'Personnaliser l\'apparence',
                onTap: () => _showThemeSettings(context, appProvider),
              ),
              _buildSettingItem(
                context,
                icon: Icons.help_rounded,
                title: 'Aide & Support',
                subtitle: 'Obtenir de l\'aide',
                onTap: () => _showHelpDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: themeProvider.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: themeProvider.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: themeProvider.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: themeProvider.textSecondaryColor.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Section de stockage avec barre de progression
  Widget _buildStorageSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        if (_isLoadingStorage) {
          return FuturisticCard(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00D4FF),
                ),
              ),
            ),
          );
        }

        final storage = _storageInfo;
        if (storage == null) {
          return const SizedBox.shrink();
        }

        final usedGB = double.parse(storage['usedGB'] ?? '0');
        final limitGB = storage['limitGB'] ?? 5;
        final availableGB = double.parse(storage['availableGB'] ?? '0');
        final percentage = (storage['percentageUsed'] ?? 0.0).toDouble();
        final mediaCount = storage['mediaCount'] ?? 0;
        final mediaTypes = storage['mediaTypes'] ?? {};
        final images = mediaTypes['images'] ?? 0;
        final videos = mediaTypes['videos'] ?? 0;
        final audio = mediaTypes['audio'] ?? 0;
        final documents = mediaTypes['documents'] ?? 0;

        // Couleur selon l'utilisation
        Color progressColor;
        if (percentage < 50) {
          progressColor = const Color(0xFF00FF88); // Vert
        } else if (percentage < 80) {
          progressColor = const Color(0xFFFFAA00); // Orange
        } else {
          progressColor = const Color(0xFFFF4444); // Rouge
        }

        return FuturisticCard(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [progressColor, progressColor.withValues(alpha: 0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cloud_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stockage Cloud',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$mediaCount médias stockés',
                            style: TextStyle(
                              color: themeProvider.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: themeProvider.primaryColor,
                      ),
                      onPressed: _loadStorageInfo,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Barre de progression
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${usedGB.toStringAsFixed(2)} GB',
                          style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'sur $limitGB GB',
                          style: TextStyle(
                            color: themeProvider.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: (percentage / 100).clamp(0.0, 1.0),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [progressColor, progressColor.withValues(alpha: 0.7)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: progressColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(1)}% utilisé',
                          style: TextStyle(
                            color: progressColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${availableGB.toStringAsFixed(2)} GB disponible',
                          style: TextStyle(
                            color: themeProvider.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                Divider(color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                
                // Répartition par type de média
                Text(
                  'Répartition des médias',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaTypeCard(
                        icon: Icons.image,
                        label: 'Images',
                        count: images,
                        color: const Color(0xFF00D4FF),
                        themeProvider: themeProvider,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeCard(
                        icon: Icons.videocam,
                        label: 'Vidéos',
                        count: videos,
                        color: const Color(0xFFFF4444),
                        themeProvider: themeProvider,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaTypeCard(
                        icon: Icons.audiotrack,
                        label: 'Audio',
                        count: audio,
                        color: const Color(0xFF00FF88),
                        themeProvider: themeProvider,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeCard(
                        icon: Icons.description,
                        label: 'Docs',
                        count: documents,
                        color: const Color(0xFFFFAA00),
                        themeProvider: themeProvider,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaTypeCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required ThemeProvider themeProvider,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              color: themeProvider.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: themeProvider.textSecondaryColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Section de gestion des publications pour libérer l'espace
  Widget _buildPublicationsManagementSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return FuturisticCard(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_sweep,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gérer mes publications',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Libérez de l\'espace en supprimant vos anciens médias',
                            style: TextStyle(
                              color: themeProvider.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedPublicationsToDelete.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selectedPublicationsToDelete.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Liste scrollable des publications
                if (_isLoadingPublications)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D4FF),
                      ),
                    ),
                  )
                else if (_myPublications.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: themeProvider.textSecondaryColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune publication',
                            style: TextStyle(
                              color: themeProvider.textSecondaryColor,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 350),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeProvider.isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _myPublications.length,
                      itemBuilder: (context, index) {
                        final pub = _myPublications[index];
                        final pubId = pub['_id'] ?? '';
                        final content = pub['content'] ?? '';
                        final media = pub['media'] as List? ?? [];
                        final hasMedia = media.isNotEmpty;
                        final mediaCount = media.length;
                        final createdAt = pub['createdAt'] != null
                            ? DateTime.parse(pub['createdAt'])
                            : DateTime.now();
                        final timeAgo = _formatTimeAgo(createdAt);
                        final isSelected = _selectedPublicationsToDelete.contains(pubId);
                        
                        // Calculer la taille approximative
                        String sizeInfo = '';
                        if (hasMedia) {
                          final firstMedia = media[0] as Map<String, dynamic>;
                          final type = firstMedia['type'] ?? '';
                          if (type == 'video') {
                            sizeInfo = '~${(mediaCount * 5).toStringAsFixed(0)} MB'; // Estimation
                          } else if (type == 'image') {
                            sizeInfo = '~${(mediaCount * 0.5).toStringAsFixed(1)} MB';
                          }
                        }
                        
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPublicationsToDelete.remove(pubId);
                                } else {
                                  _selectedPublicationsToDelete.add(pubId);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                color: isSelected
                                    ? const Color(0xFFFF6B35).withValues(alpha: 0.1)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFF6B35)
                                            : themeProvider.textSecondaryColor.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFFFF6B35)
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  // Contenu
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          content.isEmpty ? '(Sans texte)' : content,
                                          style: TextStyle(
                                            color: themeProvider.textColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: themeProvider.textSecondaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              timeAgo,
                                              style: TextStyle(
                                                color: themeProvider.textSecondaryColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (hasMedia) ...[
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.collections,
                                                size: 12,
                                                color: themeProvider.textSecondaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$mediaCount média(s)',
                                                style: TextStyle(
                                                  color: themeProvider.textSecondaryColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (sizeInfo.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  sizeInfo,
                                                  style: TextStyle(
                                                    color: const Color(0xFFFF6B35),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                // Boutons d'action
                if (_myPublications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Bouton tout sélectionner
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_selectedPublicationsToDelete.length == _myPublications.length) {
                                _selectedPublicationsToDelete.clear();
                              } else {
                                _selectedPublicationsToDelete.clear();
                                for (final pub in _myPublications) {
                                  _selectedPublicationsToDelete.add(pub['_id'] ?? '');
                                }
                              }
                            });
                          },
                          icon: Icon(
                            _selectedPublicationsToDelete.length == _myPublications.length
                                ? Icons.deselect
                                : Icons.select_all,
                            size: 18,
                          ),
                          label: Text(
                            _selectedPublicationsToDelete.length == _myPublications.length
                                ? 'Tout désélectionner'
                                : 'Tout sélectionner',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeProvider.primaryColor,
                            side: BorderSide(color: themeProvider.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton supprimer
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectedPublicationsToDelete.isEmpty
                              ? null
                              : _deleteSelectedPublications,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            _selectedPublicationsToDelete.isEmpty
                                ? 'Supprimer'
                                : 'Supprimer (${_selectedPublicationsToDelete.length})',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                            disabledForegroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else if (difference.inDays < 30) {
      return 'Il y a ${(difference.inDays / 7).floor()}sem';
    } else {
      return 'Il y a ${(difference.inDays / 30).floor()}mois';
    }
  }

  Widget _buildVirtualIDCardSection(BuildContext context, AppProvider appProvider) {
    if (_isLoadingIDCard) {
      return FuturisticCard(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D4FF),
            ),
          ),
        ),
      );
    }

    if (_virtualIDCard == null) {
      return const SizedBox.shrink();
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardId = _virtualIDCard?['cardData']?['idNumber'] ?? _virtualIDCard?['cardId'] ?? _virtualIDCard?['idNumber'] ?? 'N/A';
    final cardPdfUrl = _virtualIDCard?['cardPdf']?['url'] ?? _virtualIDCard?['cardImage']?['frontImage'];
    
    // Dates automatiques si non fournies
    final now = DateTime.now();
    final issueDate = _virtualIDCard?['issueDate'] != null
        ? DateTime.parse(_virtualIDCard!['issueDate'])
        : now;
    final expiryDate = _virtualIDCard?['expiryDate'] != null
        ? DateTime.parse(_virtualIDCard!['expiryDate'])
        : now.add(const Duration(days: 90)); // 3 mois par défaut
    
    final issueDateStr = issueDate.toString().substring(0, 10);
    final expiryDateStr = expiryDate.toString().substring(0, 10);
    
    // Calcul du temps restant
    final difference = expiryDate.difference(now);

    return FuturisticCard(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carte d\'Identité SETRAF',
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Votre carte biométrique officielle',
                        style: TextStyle(
                          color: themeProvider.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.visibility,
                    color: themeProvider.primaryColor,
                  ),
                  onPressed: () => _navigateToSetrafCard(context),
                  tooltip: 'Voir la carte complète',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ID de la carte - Section proéminente
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FF88), Color(0xFF00CC66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ID de votre Carte SETRAF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cardId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: cardId));
                            _showMessage('✅ ID de la carte copié dans le presse-papiers !');
                          },
                          tooltip: 'Copier l\'ID',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cet ID unique identifie votre carte biométrique. Utilisez-le pour les vérifications.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Informations détaillées de la carte
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeProvider.isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations de la Carte',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCardInfoRow(
                    'Statut',
                    _virtualIDCard?['verificationStatus'] == 'verified' ? 'Vérifiée' : 'En attente',
                    _virtualIDCard?['verificationStatus'] == 'verified' ? Icons.verified : Icons.pending,
                    _virtualIDCard?['verificationStatus'] == 'verified' ? const Color(0xFF00FF88) : const Color(0xFFFFAA00),
                    themeProvider,
                  ),
                  _buildCardInfoRow(
                    'Utilisations',
                    _isLoadingCardStats 
                        ? 'Chargement...' 
                        : '${_cardStats?['totalUses'] ?? 0}',
                    Icons.touch_app,
                    const Color(0xFF00D4FF),
                    themeProvider,
                  ),
                  _buildCardInfoRow(
                    'Dernière utilisation',
                    _cardStats?['lastUsed'] != null
                        ? DateTime.parse(_cardStats!['lastUsed']).toString().substring(0, 10)
                        : 'Jamais',
                    Icons.access_time,
                    const Color(0xFFFF6B35),
                    themeProvider,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Aperçu de la carte
            if (cardPdfUrl != null && cardPdfUrl.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Carte PDF Disponible',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cliquez pour voir la carte complète',
                            style: TextStyle(
                              color: themeProvider.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.open_in_new,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () => _navigateToSetrafCard(context),
                      tooltip: 'Ouvrir la carte',
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Carte PDF Disponible',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cliquez pour voir la carte complète',
                            style: TextStyle(
                              color: themeProvider.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.open_in_new,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () => _navigateToSetrafCard(context),
                      tooltip: 'Ouvrir la carte',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Compte à rebours jusqu'à expiration
            _buildExpirationCountdown(expiryDate, themeProvider),

            const SizedBox(height: 16),

            // Bouton de renouvellement si expiré ou bientôt expiré
            if (difference.inDays <= 7 || difference.isNegative) ...[
              GradientButton(
                onPressed: _renewVirtualIDCard,
                gradientColors: difference.isNegative 
                    ? [Colors.red, Colors.red.shade700]
                    : [const Color(0xFFFFAA00), const Color(0xFFFF8800)],
                child: Text(
                  difference.isNegative ? 'Renouveler la Carte' : 'Renouveler Bientôt',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Dates
            Row(
              children: [
                Expanded(
                  child: _buildDateInfo(
                    'Émise le',
                    issueDateStr,
                    Icons.calendar_today,
                    const Color(0xFF00D4FF),
                    themeProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateInfo(
                    'Expire le',
                    expiryDateStr,
                    Icons.event_busy,
                    const Color(0xFFFFAA00),
                    themeProvider,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo(
    String label,
    String date,
    IconData icon,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: themeProvider.textSecondaryColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            style: TextStyle(
              color: themeProvider.textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfoRow(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: themeProvider.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationCountdown(DateTime expiryDate, ThemeProvider themeProvider) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    
    if (difference.isNegative) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carte Expirée',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Votre carte a expiré. Renouvelez-la.',
                    style: TextStyle(
                      color: themeProvider.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    Color countdownColor;
    String urgencyText;
    
    if (days > 30) {
      countdownColor = const Color(0xFF00FF88);
      urgencyText = 'Valide';
    } else if (days > 7) {
      countdownColor = const Color(0xFFFFAA00);
      urgencyText = 'Expire bientôt';
    } else {
      countdownColor = Colors.red;
      urgencyText = 'Expiration imminente';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: countdownColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: countdownColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            color: countdownColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  urgencyText,
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days > 0 
                      ? '$days jours, $hours heures restantes'
                      : '$hours heures, $minutes minutes restantes',
                  style: TextStyle(
                    color: themeProvider.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppProvider appProvider) {
    return GradientButton(
      onPressed: () => _showLogoutDialog(context, appProvider),
      gradientColors: const [Color(0xFFFF6B35), Color(0xFFE55A2B)],
      child: const Text(
        'Se Déconnecter',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppProvider appProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.surfaceColor,
        title: Text(
          'Se Déconnecter',
          style: TextStyle(color: themeProvider.textColor),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: themeProvider.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: themeProvider.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              appProvider.logout();
            },
            child: Text(
              'Se Déconnecter',
              style: TextStyle(color: themeProvider.secondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // Paramètres de notifications
  Future<void> _showNotificationsSettings(BuildContext context, AppProvider appProvider) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationSwitch(
              'Publications',
              'Notifications des nouvelles publications',
              true,
              (value) {},
            ),
            _buildNotificationSwitch(
              'Commentaires',
              'Notifications des commentaires',
              true,
              (value) {},
            ),
            _buildNotificationSwitch(
              'Likes',
              'Notifications des likes',
              false,
              (value) {},
            ),
            _buildNotificationSwitch(
              'Messages',
              'Notifications des messages',
              true,
              (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: const Color(0xFF00D4FF).withValues(alpha: 0.5),
      activeThumbColor: const Color(0xFF00D4FF),
    );
  }

  // Paramètres de thème
  Future<void> _showThemeSettings(BuildContext context, AppProvider appProvider) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    final colorThemes = [
      {'name': 'Cyan & Orange (Défaut)', 'themeId': 'cyan_orange', 'primary': const Color(0xFF00D4FF), 'secondary': const Color(0xFFFF6B35)},
      {'name': 'Bleu & Violet', 'themeId': 'blue_violet', 'primary': const Color(0xFF2196F3), 'secondary': const Color(0xFF9C27B0)},
      {'name': 'Vert & Jaune', 'themeId': 'green_yellow', 'primary': const Color(0xFF4CAF50), 'secondary': const Color(0xFFFFC107)},
      {'name': 'Rose & Indigo', 'themeId': 'pink_indigo', 'primary': const Color(0xFFE91E63), 'secondary': const Color(0xFF3F51B5)},
      {'name': 'Orange & Rouge', 'themeId': 'orange_red', 'primary': const Color(0xFFFF9800), 'secondary': const Color(0xFFF44336)},
      {'name': 'Teal & Amber', 'themeId': 'teal_amber', 'primary': const Color(0xFF009688), 'secondary': const Color(0xFFFFC107)},
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        title: const Text(
          'Choisir un thème',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: colorThemes.map((theme) {
                final isSelected = themeProvider.currentTheme.id == theme['themeId'];
                
                return _buildThemeOption(
                  context,
                  theme['name'] as String,
                  theme['primary'] as Color,
                  theme['secondary'] as Color,
                  isSelected,
                  () async {
                    final themeId = theme['themeId'] as String;
                    await themeProvider.setThemeById(themeId);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _showMessage('Thème "${theme['name']}" appliqué !');
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String name,
    Color primaryColor,
    Color secondaryColor,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? primaryColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Prévisualisation des couleurs
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: isSelected 
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    shape: BoxShape.circle,
                    border: isSelected 
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // Aide & Support
  Future<void> _showHelpDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Aide & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem(
                icon: Icons.email_rounded,
                title: 'Email',
                subtitle: 'nyundumathryme@gmail.com',
                onTap: () => _showMessage('Ouvrir le client email...'),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                icon: Icons.phone_rounded,
                title: 'Téléphone',
                subtitle: '+243 76 356 144',
                onTap: () => _showMessage('Ouvrir le dialer...'),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                icon: Icons.web_rounded,
                title: 'Site Web',
                subtitle: 'www.center.com',
                onTap: () => _showMessage('Ouvrir le navigateur...'),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                icon: Icons.article_rounded,
                title: 'FAQ',
                subtitle: 'Questions fréquentes',
                onTap: () => _showMessage('Ouvrir la FAQ...'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF00D4FF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final user = appProvider.currentUser;

        return Scaffold(
          body: ImageBackground(
            imagePath: _selectedImage,
            opacity: 0.30, // Réduit pour éviter le voile blanc
            withGradient: false, // Désactivé pour clarté maximale
            child: SafeArea(
              bottom: false, // Ne pas appliquer SafeArea en bas
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 100, // Padding fixe pour éviter l'overflow
                ),
                child: Column(
                  children: [
                    _buildProfileHeader(context, user, appProvider),
                    const SizedBox(height: 16), // Réduit de 24 à 16
                    _buildQuickStats(context, appProvider),
                    const SizedBox(height: 16), // Réduit de 24 à 16
                    _buildVirtualIDCardSection(context, appProvider),
                    const SizedBox(height: 16),
                    _buildStorageSection(), // Section de stockage
                    const SizedBox(height: 16),
                    _buildPublicationsManagementSection(), // Section de gestion des publications
                    const SizedBox(height: 16), // Réduit de 24 à 16
                    const ThemeSelector(), // Sélecteur de thème
                    const SizedBox(height: 16), // Réduit de 24 à 16
                    _buildSettings(context, appProvider),
                    const SizedBox(height: 16), // Réduit de 24 à 16
                    _buildLogoutButton(context, appProvider),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

