import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// Widget de sélection de thème avec aperçu visuel
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final currentTheme = themeProvider.currentTheme;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: currentTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: currentTheme.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: currentTheme.gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: currentTheme.isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thème de l\'application',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: currentTheme.text,
                          ),
                        ),
                        Text(
                          currentTheme.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: currentTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle Dark Mode
                  IconButton(
                    onPressed: () => themeProvider.toggleDarkMode(),
                    icon: Icon(
                      currentTheme.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: currentTheme.primary,
                    ),
                    tooltip: currentTheme.isDark
                        ? 'Passer en mode clair'
                        : 'Passer en mode sombre',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Grille de thèmes
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: AppTheme.allThemes.length,
                itemBuilder: (context, index) {
                  final theme = AppTheme.allThemes[index];
                  final isSelected = theme.id == currentTheme.id;

                  return _ThemeCard(
                    theme: theme,
                    isSelected: isSelected,
                    onTap: () => themeProvider.setTheme(theme),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Carte individuelle de thème
class _ThemeCard extends StatelessWidget {
  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          gradient: theme.gradient,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône emoji du thème
            Text(
              theme.icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            
            // Nom du thème
            Text(
              theme.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: theme.isDark ? Colors.white : Colors.black,
              ),
            ),

            // Indicateur de sélection
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle_rounded,
                color: theme.isDark ? Colors.white : Colors.black,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
