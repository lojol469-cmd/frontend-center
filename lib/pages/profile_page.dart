import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../api_service.dart';
import '../components/futuristic_card.dart';
import '../components/gradient_button.dart';
import '../components/image_background.dart';
import '../components/theme_selector.dart';
import '../theme/theme_provider.dart';
import '../utils/background_image_manager.dart';

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
  final BackgroundImageManager _imageManager = BackgroundImageManager();

  @override
  void initState() {
    super.initState();
    _selectedImage = _imageManager.getImageForPage('profile'); // Image élégante
    _loadUserStats();
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

  Future<void> _showEditNameDialog(BuildContext context, AppProvider appProvider) async {
    final nameController = TextEditingController(text: appProvider.currentUser?['name'] ?? '');
    final token = appProvider.accessToken;

    if (token == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Modifier le nom', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nouveau nom',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty) return;

    try {
      final response = await ApiService.updateUserName(token, nameController.text.trim());

      if (mounted) {
        // Mettre à jour l'utilisateur dans AppProvider
        final updatedUser = response['user'] as Map<String, dynamic>;
        appProvider.setAuthenticated(true, token: token, user: updatedUser);

        _showMessage('Nom mis à jour !');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Erreur: $e');
      }
      debugPrint('Erreur mise à jour nom: $e');
    }
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
                    _buildProfileHeader(context, user),
                    const SizedBox(height: 16), // Réduit de 24 à 16
                    _buildQuickStats(context, appProvider),
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

  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic>? user) {
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
    return FuturisticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Paramètres',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.edit_rounded,
            title: 'Modifier le nom',
            subtitle: 'Changer votre nom d\'affichage',
            onTap: () => _showEditNameDialog(context, appProvider),
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
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
                color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF00D4FF),
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
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black38,
              size: 16,
            ),
          ],
        ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Se Déconnecter',
          style: TextStyle(color: Colors.black87),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              appProvider.logout();
            },
            child: const Text(
              'Se Déconnecter',
              style: TextStyle(color: Color(0xFFFF6B35)),
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
        title: const Text(
          'Choisir un thème',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: colorThemes.length,
            itemBuilder: (context, index) {
              final theme = colorThemes[index];
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
                  Navigator.pop(context);
                  _showMessage('Thème "${theme['name']}" appliqué !');
                },
              );
            },
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: isSelected 
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
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
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 16,
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
}

