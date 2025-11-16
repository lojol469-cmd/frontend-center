import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../theme/theme_provider.dart';
import 'home_page.dart';
import 'social_page.dart';
import 'employees_page.dart';
import 'profile_page.dart';
import 'auth_page.dart';
import 'admin_page.dart';
import 'chat_gpt_page.dart';
import 'create/create_publication_page.dart';
import 'create/create_employee_page.dart';
import 'create/create_marker_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        if (!appProvider.isAuthenticated) {
          return const AuthPage();
        }

        // Vérifier si l'utilisateur est admin
        final user = appProvider.currentUser;
        final isAdmin = user?['status'] == 'admin' || 
                       user?['email'] == 'nyundumathryme@gmail.com' ||
                       user?['email'] == 'nyundumathryme@gmail';

        // Pages disponibles selon le rôle
        final List<Widget> pages = isAdmin 
          ? [
              const HomePage(),
              const SocialPage(),
              EmployeesPage(token: appProvider.accessToken ?? ''),
              const ProfilePage(),
              const AdminPage(),
            ]
          : [
              const HomePage(),
              const SocialPage(),
              const ProfilePage(),
            ];

        return Scaffold(
          body: IndexedStack(
            index: appProvider.currentIndex,
            children: pages,
          ),
          floatingActionButton: _buildFloatingActionButton(context, appProvider, isAdmin),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: _buildBottomNavigationBar(context, appProvider, isAdmin),
        );
      },
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, AppProvider appProvider, bool isAdmin) {
    // N'afficher le FAB que pour les admins
    if (!isAdmin) return const SizedBox.shrink();
    
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: themeProvider.gradient,
        ),
        child: FloatingActionButton(
          heroTag: 'admin_add',
          onPressed: () => _showCreateDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            Icons.add,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, AppProvider appProvider, bool isAdmin) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        border: Border(
          top: BorderSide(
            color: themeProvider.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: themeProvider.primaryColor,
          unselectedItemColor: themeProvider.textSecondaryColor,
          currentIndex: appProvider.currentIndex,
          onTap: (index) {
            // Pour les non-admins, tous les index de la barre sont accessibles
            // car elle ne contient que Home (0), Social (1), et Profile (2)
            // Pour les admins, tous les index sont accessibles
            appProvider.setCurrentIndex(index);
          },
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 28,
          items: isAdmin 
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.groups_rounded),
                  label: 'Social',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_center_rounded),
                  label: 'Employés',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings_rounded),
                  label: 'Admin',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.groups_rounded),
                  label: 'Social',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + bottomPadding, // Ajouter le padding du système
        ),
        decoration: BoxDecoration(
          color: themeProvider.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: themeProvider.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Créer',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: themeProvider.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCreateOption(
                  context,
                  icon: Icons.edit_rounded,
                  label: 'Publication',
                  color: themeProvider.primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreatePublicationPage(),
                      ),
                    ).then((result) {
                      if (result == true && context.mounted) {
                        // Rafraîchir la liste des publications si nécessaire
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        appProvider.setCurrentIndex(1); // Rediriger vers Social
                      }
                    });
                  },
                ),
                _buildCreateOption(
                  context,
                  icon: Icons.person_add_rounded,
                  label: 'Employé',
                  color: themeProvider.secondaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateEmployeePage(),
                      ),
                    ).then((result) {
                      if (result == true && context.mounted) {
                        // Rafraîchir la liste des employés
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        appProvider.setCurrentIndex(2); // Rediriger vers Employees
                      }
                    });
                  },
                ),
                _buildCreateOption(
                  context,
                  icon: Icons.location_on_rounded,
                  label: 'Marqueur',
                  color: themeProvider.accentColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateMarkerPage(),
                      ),
                    ).then((result) {
                      if (result == true && context.mounted) {
                        // Afficher un message de succès
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Marqueur créé avec succès !'),
                            backgroundColor: Color(0xFF25D366),
                          ),
                        );
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCreateOption(
                  context,
                  icon: Icons.chat_rounded,
                  label: 'Chat IA',
                  color: themeProvider.primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatGPTPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
