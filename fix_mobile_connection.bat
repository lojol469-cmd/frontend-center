@echo off
REM ===========================================
REM 🔧 Mobile Connection Fix Script
REM Script de diagnostic et correction automatique
REM pour les problèmes de connexion mobile Flutter
REM ===========================================

echo 🚀 Mobile Connection Fix - Script Automatique
echo ==============================================

REM Vérifier si Dart est installé
dart --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ ERREUR: Dart n'est pas installé ou n'est pas dans le PATH
    echo 📥 Veuillez installer Dart SDK depuis: https://dart.dev/get-dart
    pause
    exit /b 1
)

REM Vérifier si on est dans le bon répertoire
if not exist "lib\config\server_config.dart" (
    echo ❌ ERREUR: Ce script doit être exécuté depuis la racine du projet Flutter
    echo 📁 Répertoire actuel: %cd%
    pause
    exit /b 1
)

echo 📍 Projet détecté: %cd%
echo.

REM Créer un backup automatique
echo 💾 Création d'un backup automatique...
if not exist "backups" mkdir backups
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do set DATE=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set TIME=%%a-%%b
set BACKUP_DIR=backups\backup_%DATE%_%TIME%
mkdir "%BACKUP_DIR%"

if exist "lib\config\server_config.dart" copy "lib\config\server_config.dart" "%BACKUP_DIR%\"
if exist "lib\api_service.dart" copy "lib\api_service.dart" "%BACKUP_DIR%\"

echo ✅ Backup créé dans: %BACKUP_DIR%
echo.

REM Exécuter le script de diagnostic et correction
echo 🔍 Lancement du diagnostic et des corrections...
dart run scripts\mobile_connection_fix.dart

if %errorlevel% equ 0 (
    echo.
    echo ✅ CORRECTION RÉUSSIE !
    echo 📱 Vous pouvez maintenant tester sur votre appareil Android
    echo.
    echo 🔄 Pour restaurer le backup si nécessaire:
    echo dart run scripts\mobile_connection_fix.dart --restore "%BACKUP_DIR%"
) else (
    echo.
    echo ❌ ÉCHEC de la correction automatique
    echo 🔧 Veuillez consulter MOBILE_CONNECTION_FIX.md pour la correction manuelle
    echo 📞 Ou contacter le support technique
)

echo.
echo 📋 Logs détaillés disponibles dans la console ci-dessus
pause