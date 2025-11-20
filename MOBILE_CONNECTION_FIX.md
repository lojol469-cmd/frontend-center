# 🔧 Guide de Dépannage - Problème de Connexion Mobile

## 📋 Description du Problème

**Symptôme :** L'application Flutter fonctionne correctement sur PC mais échoue à se connecter au serveur sur les appareils Android mobiles.

**Logs observés :**
```
📡 Résultat de la vérification de connexion: false
✅ Statut de connexion mis à jour: false
```

**Cause racine :** L'application utilise le mode développement au lieu du mode production, causant une tentative de connexion vers des adresses IP locales au lieu de l'URL Render.

## 🔍 Diagnostic Automatique

### Vérifications à effectuer :

1. **Vérifier le mode de configuration :**
   ```dart
   // Dans lib/config/server_config.dart
   static const bool isProduction = true; // Doit être true
   ```

2. **Vérifier l'initialisation de l'ApiService :**
   ```dart
   // Dans checkConnection() - doit contenir :
   await _ensureInitialized();
   ```

3. **Vérifier les logs détaillés :**
   - `🔍 [CHECK] Tentative de connexion à: https://center-backend-v9rf.onrender.com/api/server-info`
   - `📡 [CHECK] Status Code: 200`
   - `📡 [CHECK] Résultat: true`

## 🛠️ Solution Appliquée

### Modifications apportées :

#### 1. Configuration Serveur (`lib/config/server_config.dart`)
```dart
// AVANT
static const bool isProduction = false;

// APRÈS
static const bool isProduction = true;
```

#### 2. Méthode checkConnection (`lib/api_service.dart`)
```dart
// AJOUT au début de la méthode :
await _ensureInitialized();
```

#### 3. Logs améliorés (`lib/api_service.dart`)
```dart
// Changement de developer.log() vers debugPrint()
debugPrint('🔍 [CHECK] Tentative de connexion à: $url');
debugPrint('📡 [CHECK] Status Code: ${response.statusCode}');
debugPrint('❌ [CHECK] Erreur checkConnection: $e');
```

## 🚀 Procédure de Correction Automatique

### Script de diagnostic (`scripts/diagnose_connection.dart`)

```dart
import 'dart:io';
import 'package:path/path.dart' as path;

class ConnectionDiagnostic {
  static Future<void> run() async {
    print('🔍 Diagnostic automatique de connexion mobile...');

    // 1. Vérifier la configuration serveur
    final configFile = File('lib/config/server_config.dart');
    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      if (!content.contains('isProduction = true')) {
        print('❌ ERREUR: isProduction doit être true');
        await fixServerConfig();
      } else {
        print('✅ Configuration serveur OK');
      }
    }

    // 2. Vérifier l'initialisation dans checkConnection
    final apiFile = File('lib/api_service.dart');
    if (await apiFile.exists()) {
      final content = await apiFile.readAsString();
      if (!content.contains('await _ensureInitialized();')) {
        print('❌ ERREUR: _ensureInitialized manquant dans checkConnection');
        await fixApiService();
      } else {
        print('✅ Initialisation ApiService OK');
      }
    }

    // 3. Vérifier les logs debugPrint
    if (content.contains('debugPrint(')) {
      print('✅ Logs debugPrint OK');
    } else {
      print('❌ ERREUR: Logs debugPrint manquants');
      await fixLogging();
    }

    print('✅ Diagnostic terminé');
  }

  static Future<void> fixServerConfig() async {
    print('🔧 Correction automatique de server_config.dart...');
    final file = File('lib/config/server_config.dart');
    var content = await file.readAsString();
    content = content.replaceAll('isProduction = false', 'isProduction = true');
    await file.writeAsString(content);
    print('✅ server_config.dart corrigé');
  }

  static Future<void> fixApiService() async {
    print('🔧 Correction automatique de api_service.dart...');
    final file = File('lib/api_service.dart');
    var content = await file.readAsString();

    // Trouver la méthode checkConnection et ajouter _ensureInitialized
    final checkConnectionPattern = RegExp(r'static Future<bool> checkConnection\(\) async \{\s*try \{');
    if (checkConnectionPattern.hasMatch(content)) {
      content = content.replaceFirst(
        checkConnectionPattern,
        'static Future<bool> checkConnection() async {\n    await _ensureInitialized();\n    try {'
      );
      await file.writeAsString(content);
      print('✅ api_service.dart corrigé');
    }
  }

  static Future<void> fixLogging() async {
    print('🔧 Correction automatique des logs...');
    final file = File('lib/api_service.dart');
    var content = await file.readAsString();
    content = content.replaceAll('developer.log(', 'debugPrint(');
    await file.writeAsString(content);
    print('✅ Logs corrigés');
  }
}
```

### Hook Git Pre-commit (`scripts/pre-commit-hook`)

```bash
#!/bin/bash

echo "🔍 Vérification automatique avant commit..."

# Vérifier si les fichiers critiques ont été modifiés
if git diff --cached --name-only | grep -E "(server_config.dart|api_service.dart)"; then
    echo "📝 Fichiers de configuration modifiés, exécution du diagnostic..."
    dart run scripts/diagnose_connection.dart

    if [ $? -ne 0 ]; then
        echo "❌ Erreurs détectées, commit annulé"
        exit 1
    fi
fi

echo "✅ Pré-commit OK"
```

## 📊 Monitoring et Alertes

### Logs à surveiller :

```dart
// Dans connection_status.dart
debugPrint('🔍 Vérification de la connexion au serveur...');
debugPrint('📡 Résultat de la vérification de connexion: $connected');
```

### Métriques à collecter :
- Taux de succès des connexions mobiles
- Temps de réponse moyen
- Erreurs SSL/Timeout détectées

## 🧪 Tests de Validation

### Test unitaire (`test/connection_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../lib/api_service.dart';
import '../lib/config/server_config.dart';

void main() {
  group('Connection Tests', () {
    test('Server config should be in production mode', () {
      expect(ServerConfig.isProduction, true);
    });

    test('ApiService should initialize correctly', () async {
      await ApiService.initialize();
      expect(ApiService.baseUrl, contains('onrender.com'));
    });

    test('Connection check should work', () async {
      final result = await ApiService.checkConnection();
      expect(result, true);
    });
  });
}
```

## 📋 Checklist de Déploiement

- [ ] `isProduction = true` dans `server_config.dart`
- [ ] `await _ensureInitialized()` dans `checkConnection()`
- [ ] Logs `debugPrint()` au lieu de `developer.log()`
- [ ] Tests unitaires passent
- [ ] Build Android réussi
- [ ] Test sur appareil physique

## 🔄 Procédure de Rollback

En cas de problème avec la correction :

```bash
# Revenir à la version précédente
git checkout HEAD~1 lib/config/server_config.dart
git checkout HEAD~1 lib/api_service.dart

# Remettre isProduction = false
sed -i 's/isProduction = true/isProduction = false/' lib/config/server_config.dart
```

## 📞 Support

**Si le problème persiste :**
1. Vérifier les logs Android complets
2. Tester la connectivité réseau manuellement :
   ```bash
   curl -I https://center-backend-v9rf.onrender.com/api/server-info
   ```
3. Vérifier la configuration réseau de l'appareil Android

---

*Document créé le : 20 novembre 2025*
*Dernière mise à jour : 20 novembre 2025*</content>
<parameter name="filePath">c:\Users\Admin\Pictures\DAT.ERT\ERT\flutterAPP\CENTER\MOBILE_CONNECTION_FIX.md