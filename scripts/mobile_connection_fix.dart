import 'dart:io';

/// 🔧 Script de diagnostic et correction automatique
/// pour le problème de connexion mobile Flutter
class MobileConnectionFix {
  static const String configFile = 'lib/config/server_config.dart';
  static const String apiFile = 'lib/api_service.dart';

  static Future<void> main(List<String> args) async {
    // ignore: avoid_print
    print('🚀 Mobile Connection Fix - Diagnostic et Correction Automatique');
    // ignore: avoid_print
    print('=' * 60);

    try {
      await runDiagnostic();
      await applyFixes();
      await validateFixes();

      // ignore: avoid_print
      print('\n✅ Toutes les corrections ont été appliquées avec succès !');
      // ignore: avoid_print
      print('📱 Testez maintenant sur votre appareil Android.');

    } catch (e) {
      // ignore: avoid_print
      print('\n❌ Erreur lors de la correction automatique : $e');
      // ignore: avoid_print
      print('🔧 Veuillez corriger manuellement ou contacter le support.');
      exit(1);
    }
  }

  static Future<void> runDiagnostic() async {
    // ignore: avoid_print
    print('\n🔍 PHASE 1: DIAGNOSTIC');
    // ignore: avoid_print
    print('-' * 30);

    // 1. Vérifier la configuration serveur
    // ignore: avoid_print
    print('📋 Vérification de la configuration serveur...');
    final configExists = await File(configFile).exists();
    if (!configExists) {
      throw Exception('Fichier $configFile introuvable');
    }

    final configContent = await File(configFile).readAsString();
    final isProductionCorrect = configContent.contains('isProduction = true');

    if (!isProductionCorrect) {
      // ignore: avoid_print
      print('❌ PROBLÈME: isProduction doit être true (actuellement false)');
    } else {
      // ignore: avoid_print
      print('✅ Configuration serveur OK');
    }

    // 2. Vérifier l'initialisation ApiService
    // ignore: avoid_print
    print('🔧 Vérification de l\'initialisation ApiService...');
    final apiExists = await File(apiFile).exists();
    if (!apiExists) {
      throw Exception('Fichier $apiFile introuvable');
    }

    final apiContent = await File(apiFile).readAsString();
    final hasEnsureInitialized = apiContent.contains('await _ensureInitialized();');

    if (!hasEnsureInitialized) {
      // ignore: avoid_print
      print('❌ PROBLÈME: _ensureInitialized() manquant dans checkConnection()');
    } else {
      // ignore: avoid_print
      print('✅ Initialisation ApiService OK');
    }

    // 3. Vérifier les logs
    // ignore: avoid_print
    print('📝 Vérification des logs de débogage...');
    final hasDebugPrint = apiContent.contains('debugPrint(');
    final hasDeveloperLog = apiContent.contains('developer.log(');

    if (hasDeveloperLog && !hasDebugPrint) {
      // ignore: avoid_print
      print('❌ PROBLÈME: Utilise developer.log() au lieu de debugPrint()');
    } else if (hasDebugPrint) {
      // ignore: avoid_print
      print('✅ Logs de débogage OK');
    }

    // ignore: avoid_print
    print('✅ Diagnostic terminé');
  }

  static Future<void> applyFixes() async {
    // ignore: avoid_print
    print('\n🛠️ PHASE 2: APPLICATION DES CORRECTIONS');
    // ignore: avoid_print
    print('-' * 40);

    bool fixesApplied = false;

    // 1. Corriger la configuration serveur
    // ignore: avoid_print
    print('🔧 Correction de server_config.dart...');
    final configContent = await File(configFile).readAsString();
    if (!configContent.contains('isProduction = true')) {
      final updatedConfig = configContent.replaceAll(
        'isProduction = false',
        'isProduction = true'
      );
      await File(configFile).writeAsString(updatedConfig);
      // ignore: avoid_print
      print('✅ isProduction forcé à true');
      fixesApplied = true;
    } else {
      // ignore: avoid_print
      print('⏭️ Aucune modification nécessaire');
    }

    // 2. Corriger l'initialisation ApiService
    // ignore: avoid_print
    print('🔧 Correction de api_service.dart...');
    final apiContent = await File(apiFile).readAsString();

    if (!apiContent.contains('await _ensureInitialized();')) {
      // Trouver la méthode checkConnection et ajouter l'initialisation
      final checkConnectionPattern = RegExp(
        r'(static Future<bool> checkConnection\(\) async \{\s*\n\s*)try \{',
        multiLine: true
      );

      final updatedApi = apiContent.replaceFirst(
        checkConnectionPattern,
        '\$1    await _ensureInitialized();\n\n    try {'
      );

      await File(apiFile).writeAsString(updatedApi);
      // ignore: avoid_print
      print('✅ _ensureInitialized() ajouté à checkConnection()');
      fixesApplied = true;
    } else {
      // ignore: avoid_print
      print('⏭️ Aucune modification nécessaire');
    }

    // 3. Corriger les logs
    if (apiContent.contains('developer.log(') && !apiContent.contains('debugPrint(')) {
      // ignore: avoid_print
      print('🔧 Correction des logs developer.log() -> debugPrint()...');
      final updatedLogs = apiContent.replaceAll('developer.log(', 'debugPrint(');
      await File(apiFile).writeAsString(updatedLogs);
      // ignore: avoid_print
      print('✅ Logs convertis en debugPrint()');
      fixesApplied = true;
    } else {
      // ignore: avoid_print
      print('⏭️ Aucune modification nécessaire');
    }

    if (fixesApplied) {
      // ignore: avoid_print
      print('✅ Corrections appliquées avec succès');
    } else {
      // ignore: avoid_print
      print('ℹ️ Aucune correction nécessaire - tout est déjà correct');
    }
  }

  static Future<void> validateFixes() async {
    // ignore: avoid_print
    print('\n✅ PHASE 3: VALIDATION DES CORRECTIONS');
    // ignore: avoid_print
    print('-' * 40);

    // Relire les fichiers pour valider
    final configContent = await File(configFile).readAsString();
    final apiContent = await File(apiFile).readAsString();

    // Vérifications
    final validations = [
      ('isProduction = true', configContent.contains('isProduction = true')),
      ('_ensureInitialized()', apiContent.contains('await _ensureInitialized();')),
      ('debugPrint() logs', apiContent.contains('debugPrint(')),
    ];

    for (final validation in validations) {
      final (check, passed) = validation;
      if (passed) {
        // ignore: avoid_print
        print('✅ $check : OK');
      } else {
        // ignore: avoid_print
        print('❌ $check : ÉCHEC');
        throw Exception('Validation échouée pour: $check');
      }
    }

    // ignore: avoid_print
    print('✅ Toutes les validations passées');
  }

  /// Méthode utilitaire pour créer un backup
  static Future<void> createBackup() async {
    // ignore: avoid_print
    print('💾 Création d\'un backup des fichiers critiques...');

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupDir = 'backup_$timestamp';

    await Directory(backupDir).create();

    // Copier les fichiers critiques
    await File(configFile).copy('$backupDir/server_config.dart');
    await File(apiFile).copy('$backupDir/api_service.dart');

    // ignore: avoid_print
    print('✅ Backup créé dans: $backupDir');
  }

  /// Méthode utilitaire pour restaurer un backup
  static Future<void> restoreBackup(String backupDir) async {
    // ignore: avoid_print
    print('🔄 Restauration du backup: $backupDir');

    if (!await Directory(backupDir).exists()) {
      throw Exception('Backup directory not found: $backupDir');
    }

    await File('$backupDir/server_config.dart').copy(configFile);
    await File('$backupDir/api_service.dart').copy(apiFile);

    // ignore: avoid_print
    print('✅ Backup restauré');
  }
}

/// Fonction principale pour exécution en ligne de commande
void main(List<String> args) async {
  if (args.isNotEmpty && args[0] == '--backup') {
    await MobileConnectionFix.createBackup();
  } else if (args.length >= 2 && args[0] == '--restore') {
    await MobileConnectionFix.restoreBackup(args[1]);
  } else {
    await MobileConnectionFix.main([]);
  }
}