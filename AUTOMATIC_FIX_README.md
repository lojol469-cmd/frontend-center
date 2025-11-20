# 🔧 Outils de Correction Automatique - Connexion Mobile

## 📋 Vue d'ensemble

Ce projet inclut des outils automatiques pour diagnostiquer et corriger le problème de connexion mobile Flutter.

## 🛠️ Outils Disponibles

### 1. Script de Correction Automatique (`fix_mobile_connection.bat`)

**Usage :**
```bash
# Double-cliquez sur le fichier ou exécutez:
fix_mobile_connection.bat
```

**Ce que fait le script :**
- ✅ Crée automatiquement un backup
- 🔍 Diagnostique les problèmes
- 🛠️ Applique les corrections nécessaires
- ✅ Valide que tout fonctionne

### 2. Script Dart Avancé (`scripts/mobile_connection_fix.dart`)

**Usage :**
```bash
# Diagnostic et correction complète
dart run scripts/mobile_connection_fix.dart

# Créer un backup uniquement
dart run scripts/mobile_connection_fix.dart --backup

# Restaurer un backup
dart run scripts/mobile_connection_fix.dart --restore backups/backup_2025-11-20_14-30
```

### 3. Hook Git Pre-commit (`scripts/pre-commit-hook`)

**Installation :**
```bash
# Copier le hook dans .git/hooks/
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Fonction :**
- 🔍 Vérifie automatiquement avant chaque commit
- 🛠️ Corrige automatiquement les problèmes détectés
- 🚫 Bloque le commit si les corrections échouent

## 📖 Documentation Détaillée

Consultez [`MOBILE_CONNECTION_FIX.md`](MOBILE_CONNECTION_FIX.md) pour :
- Description complète du problème
- Procédures de diagnostic manuel
- Solutions détaillées
- Tests de validation

## 🚀 Utilisation Rapide

### Pour corriger immédiatement :
1. **Double-cliquez** sur `fix_mobile_connection.bat`
2. **Attendez** que le script termine
3. **Testez** sur votre appareil Android

### Pour les développeurs :
```bash
# Installation du hook Git
cp scripts/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Test du script
dart run scripts/mobile_connection_fix.dart
```

## 🔄 Backup et Restauration

Les backups sont automatiquement créés dans le dossier `backups/`.

**Restaurer un backup :**
```bash
dart run scripts/mobile_connection_fix.dart --restore backups/NOM_DU_BACKUP
```

## 📞 Support

Si les outils automatiques ne fonctionnent pas :
1. Consultez `MOBILE_CONNECTION_FIX.md`
2. Vérifiez les logs de la console
3. Contactez le support technique

---

*Outils créés le : 20 novembre 2025*