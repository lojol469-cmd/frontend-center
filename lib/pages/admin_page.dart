import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../components/futuristic_card.dart';
import '../components/gradient_button.dart';
import '../components/image_background.dart';
import '../api_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late String _selectedImage;
  bool _isLoadingStats = false;
  bool _isLoadingUsers = false;
  bool _isLoadingEmployees = false;
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _employees = [];
  String? _error;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _selectedImage = 'assets/images/pexels-francesco-ungaro-2325447.jpg'; // Image existante
    _loadAdminData();
  }

  // Helper pour transformer les URLs relatives en URLs complètes
  String _getFullUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Si l'URL commence déjà par http:// ou https://, la retourner telle quelle
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // Sinon, ajouter le baseUrl
    final baseUrl = ApiService.baseUrl;
    // Enlever le slash au début de l'URL si présent
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanUrl';
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    // Éviter les appels simultanés
    if (_isLoadingStats) {
      debugPrint('⏳ Chargement déjà en cours, ignoré');
      return;
    }

    if (_isDisposed) return;

    if (mounted) {
      setState(() {
        _isLoadingStats = true;
        _isLoadingUsers = true;
        _isLoadingEmployees = true;
        _error = null;
      });
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) {
      debugPrint('⚠️ Token manquant');
      if (!_isDisposed && mounted) {
        setState(() {
          _error = 'Token manquant';
          _isLoadingStats = false;
          _isLoadingUsers = false;
          _isLoadingEmployees = false;
        });
      }
      return;
    }

    // Charger les statistiques
    try {
      final stats = await ApiService.getAdminStats(token);
      if (!_isDisposed && mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement stats: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _error = 'Erreur stats: $e';
          _isLoadingStats = false;
        });
      }
    }

    // Arrêter si le widget a été disposé
    if (_isDisposed) return;

    // Charger les utilisateurs
    try {
      final usersData = await ApiService.getUsers(token);
      if (!_isDisposed && mounted) {
        setState(() {
          _users = usersData['users'] ?? [];
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement users: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }

    // Arrêter si le widget a été disposé
    if (_isDisposed) return;

    // Charger les employés
    try {
      final employeesData = await ApiService.getEmployees(token);
      if (!_isDisposed && mounted) {
        setState(() {
          _employees = employeesData['employees'] ?? [];
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement employees: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        // Check if user is admin
        final isAdmin = appProvider.currentUser?['email'] == 'nyundumathryme@gmail.com';

        if (!isAdmin) {
          return _buildAccessDenied(context);
        }

        return Scaffold(
          backgroundColor: Colors.grey[50], // ✅ MODIFIÉ - Plus de blanc pur
          appBar: AppBar(
            title: const Text(
              'Administration',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadAdminData,
                tooltip: 'Rafraîchir',
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: ImageBackground(
            imagePath: _selectedImage,
            opacity: 0.3, // Opacité modérée pour visibilité équilibrée
            child: ListView(
              padding: const EdgeInsets.only(top: kToolbarHeight + 60, left: 20, right: 20, bottom: 20),
              children: [
                _buildAdminStats(context, appProvider),
                const SizedBox(height: 24),
                _buildUserManagement(context, appProvider),
                const SizedBox(height: 24),
                _buildEmployeeManagement(context, appProvider),
                const SizedBox(height: 24),
                _buildSystemControls(context, appProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // ✅ MODIFIÉ - Plus de blanc pur
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Accès Administrateur Requis',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Vous n\'avez pas les permissions nécessaires\npour accéder à cette section.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminStats(BuildContext context, AppProvider appProvider) {
    if (_isLoadingStats) {
      return const FuturisticCard(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );
    }

    if (_error != null || _stats == null) {
      return FuturisticCard(
        child: Center(
          child: Text(
            _error ?? 'Erreur de chargement',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return FuturisticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF00D4FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Statistiques Globales',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Utilisateurs',
                  value: '${_stats!['users']['total']}',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF00D4FF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Employés',
                  value: '${_stats!['employees']['total']}',
                  icon: Icons.business_center_rounded,
                  color: const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Publications',
                  value: '${_stats!['publications']['total']}',
                  icon: Icons.article_rounded,
                  color: const Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Actifs',
                  value: '${_stats!['users']['active']}',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagement(BuildContext context, AppProvider appProvider) {
    if (_isLoadingUsers) {
      return const FuturisticCard(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );
    }

    // Séparer les utilisateurs actifs/admins des utilisateurs bloqués
    final activeUsers = _users.where((user) => user['status'] != 'blocked').toList();
    final blockedUsers = _users.where((user) => user['status'] == 'blocked').toList();

    return Column(
      children: [
        // Section Utilisateurs Actifs
        FuturisticCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.manage_accounts_rounded,
                      color: Color(0xFF00D4FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Utilisateurs Actifs (${activeUsers.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (activeUsers.isEmpty)
                const Center(
                  child: Text(
                    'Aucun utilisateur actif',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ...activeUsers.map((user) => _buildUserItem(context, user, appProvider)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section Utilisateurs Désactivés (pour réactivation)
        if (blockedUsers.isNotEmpty)
          FuturisticCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Utilisateurs Désactivés (${blockedUsers.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ces utilisateurs sont désactivés et ne peuvent pas se connecter. Vous pouvez les réactiver en cliquant sur l\'icône d\'action.',
                          style: TextStyle(
                            color: Colors.red.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...blockedUsers.map((user) => _buildBlockedUserItem(context, user, appProvider)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUserItem(BuildContext context, dynamic user, AppProvider appProvider) {
    final String userId = user['_id'] ?? user['id'] ?? '';
    final String name = user['name'] ?? 'Sans nom';
    final String email = user['email'] ?? '';
    final String status = user['status'] ?? 'active';
    final String rawProfileImage = user['profileImage'] ?? '';
    final String profileImage = _getFullUrl(rawProfileImage);

    // Logs réduits pour éviter la duplication
    if (profileImage.isNotEmpty) {
      debugPrint('👤 User: $name (avec image)');
    } else {
      debugPrint('👤 User: $name (sans image)');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                child: profileImage.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          profileImage,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ Error loading user image: $error');
                            debugPrint('   URL: $profileImage');
                            return const Icon(Icons.person, color: Colors.grey);
                          },
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
              if (status == 'admin')
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E1E1E),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status == 'admin') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Bouton Désactiver (admin seulement)
              if (appProvider.currentUser?['email'] == 'nyundumathryme@gmail.com')
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => _handleUserAction(context, userId, 'deactivate', appProvider),
                    icon: const Icon(Icons.block, color: Colors.red),
                    tooltip: 'Désactiver l\'utilisateur',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              // Bouton Chat IA
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => _handleUserAction(context, userId, 'toggle_ai_chat', appProvider),
                  icon: Icon(
                    user['aiChatAccess'] == true ? Icons.smart_toy : Icons.smart_toy_outlined,
                    color: user['aiChatAccess'] == true ? Colors.blue : Colors.grey,
                  ),
                  tooltip: user['aiChatAccess'] == true ? 'Désactiver le chat IA' : 'Activer le chat IA',
                  style: IconButton.styleFrom(
                    backgroundColor: (user['aiChatAccess'] == true ? Colors.blue : Colors.grey).withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              // Menu déroulant existant
              PopupMenuButton<String>(
                onSelected: (value) => _handleUserAction(context, userId, value, appProvider),
                itemBuilder: (context) => [
                  if (status == 'admin') ...[
                    const PopupMenuItem(
                      value: 'demote',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Rétrograder'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  const PopupMenuItem(
                    value: 'activate',
                    child: Text('Activer'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: _getStatusColor(status),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUserItem(BuildContext context, dynamic user, AppProvider appProvider) {
    final String userId = user['_id'] ?? user['id'] ?? '';
    final String name = user['name'] ?? 'Sans nom';
    final String email = user['email'] ?? '';
    final String rawProfileImage = user['profileImage'] ?? '';
    final String profileImage = _getFullUrl(rawProfileImage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                child: profileImage.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          profileImage,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ Error loading user image: $error');
                            return const Icon(Icons.person, color: Colors.grey);
                          },
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'DÉSACTIVÉ',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleBlockedUserAction(context, userId, value, appProvider),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reactivate',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Réactiver'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeManagement(BuildContext context, AppProvider appProvider) {
    if (_isLoadingEmployees) {
      return const FuturisticCard(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    return FuturisticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Color(0xFFFF6B35),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Gestion des Employés',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_employees.isEmpty)
            const Center(
              child: Text(
                'Aucun employé',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            ..._employees.map((employee) => _buildEmployeeItem(context, employee, appProvider)),
        ],
      ),
    );
  }

  Widget _buildEmployeeItem(BuildContext context, dynamic employee, AppProvider appProvider) {
    // ignore: unused_local_variable
    final String employeeId = employee['_id'] ?? employee['id'] ?? '';
    final String name = employee['name'] ?? 'Sans nom';
    final String email = employee['email'] ?? '';
    final String phone = employee['phone'] ?? '';
    final String status = employee['status'] ?? 'active';
    final String rawFaceImage = employee['faceImage'] ?? '';
    final String faceImage = _getFullUrl(rawFaceImage);

    // Log réduit pour éviter la pollution de console
    debugPrint('👷 Employee: $name');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFFF6B35),
            child: faceImage.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      faceImage,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ Error loading employee image: $error');
                        debugPrint('   URL: $faceImage');
                        return const Icon(Icons.person, color: Colors.white);
                      },
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: TextStyle(
                      color: const Color(0xFF25D366).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleEmployeeAction(context, employee, value, appProvider),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'promote',
                child: Text('Promouvoir'),
              ),
              const PopupMenuItem(
                value: 'demote',
                child: Text('Rétrograder'),
              ),
              const PopupMenuItem(
                value: 'transfer',
                child: Text('Transférer'),
              ),
              const PopupMenuItem(
                value: 'terminate',
                child: Text('Licencier'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getEmployeeStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                color: _getEmployeeStatusColor(status),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemControls(BuildContext context, AppProvider appProvider) {
    return FuturisticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings_system_daydream_rounded,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Contrôles Système',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  onPressed: () => _showMessage(context, 'Données sauvegardées avec succès!'),
                  gradientColors: const [Color(0xFF25D366), Color(0xFF128C7E)],
                  child: const Text(
                    'Sauvegarder Données',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GradientButton(
                  onPressed: () => _showMessage(context, 'Rapports exportés avec succès!'),
                  gradientColors: const [Color(0xFF128C7E), Color(0xFF075E54)],
                  child: const Text(
                    'Exporter Rapports',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () => _showMaintenanceDialog(context),
            gradientColors: const [Color(0xFF075E54), Color(0xFF25D366)],
            child: const Text(
              'Maintenance Système',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'admin':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'banned':
      case 'blocked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getEmployeeStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'on_leave':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleUserAction(BuildContext context, String userId, String action, AppProvider appProvider) async {
    final token = appProvider.accessToken;
    if (token == null) {
      if (!context.mounted) return;
      _showMessage(context, 'Token manquant');
      return;
    }

    try {
      switch (action) {
        case 'activate':
          await ApiService.updateUserStatus(token, userId, 'admin');
          if (!context.mounted) return;
          _showMessage(context, 'Utilisateur promu administrateur');
          _loadAdminData(); // Recharger les données
          break;
        case 'demote':
          await ApiService.updateUserStatus(token, userId, 'active');
          if (!context.mounted) return;
          _showMessage(context, 'Administrateur rétrogradé');
          _loadAdminData(); // Recharger les données
          break;
        case 'deactivate':
          await ApiService.updateUserStatus(token, userId, 'blocked');
          if (!context.mounted) return;
          _showMessage(context, 'Utilisateur désactivé');
          _loadAdminData();
          break;
        case 'toggle_ai_chat':
          await ApiService.toggleAiChatAccess(token, userId);
          if (!context.mounted) return;
          _showMessage(context, 'Accès chat IA basculé');
          _loadAdminData();
          break;
        case 'delete':
          await ApiService.deleteUser(token, userId);
          if (!context.mounted) return;
          _showMessage(context, 'Utilisateur supprimé');
          _loadAdminData();
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      _showMessage(context, 'Erreur: $e');
    }
  }

  void _handleBlockedUserAction(BuildContext context, String userId, String action, AppProvider appProvider) async {
    final token = appProvider.accessToken;
    if (token == null) {
      if (!context.mounted) return;
      _showMessage(context, 'Token manquant');
      return;
    }

    try {
      switch (action) {
        case 'reactivate':
          await ApiService.updateUserStatus(token, userId, 'active');
          if (!context.mounted) return;
          _showMessage(context, 'Utilisateur réactivé avec succès');
          _loadAdminData(); // Recharger les données
          break;
        case 'delete':
          await ApiService.deleteUser(token, userId);
          if (!context.mounted) return;
          _showMessage(context, 'Utilisateur supprimé');
          _loadAdminData();
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      _showMessage(context, 'Erreur: $e');
    }
  }

  void _handleEmployeeAction(BuildContext context, dynamic employee, String action, AppProvider appProvider) async {
    final employeeId = employee['_id'] ?? employee['id'] ?? '';
    final employeeName = employee['name'] ?? 'Employé';
    
    // Note: Backend routes for employee actions (promote/demote/transfer/terminate) 
    // need to be implemented in server.js
    if (!context.mounted) return;
    
    switch (action) {
      case 'promote':
        debugPrint('Promote employee: $employeeId');
        _showMessage(context, '$employeeName promu (fonctionnalité à implémenter)');
        break;
      case 'demote':
        debugPrint('Demote employee: $employeeId');
        _showMessage(context, '$employeeName rétrogradé (fonctionnalité à implémenter)');
        break;
      case 'transfer':
        debugPrint('Transfer employee: $employeeId');
        _showMessage(context, '$employeeName transféré (fonctionnalité à implémenter)');
        break;
      case 'terminate':
        debugPrint('Terminate employee: $employeeId');
        // When backend route exists: await ApiService.updateEmployeeStatus(token, employeeId, 'terminated');
        _showMessage(context, '$employeeName licencié (fonctionnalité à implémenter)');
        break;
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Maintenance Système',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Cette action effectuera une maintenance complète du système. Continuer?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          GradientButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage(context, 'Maintenance effectuée avec succès!');
            },
            gradientColors: const [Color(0xFF25D366), Color(0xFF128C7E)],
            height: 36,
            child: const Text(
              'Confirmer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
