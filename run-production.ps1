# Script pour relancer l'app Flutter en mode production propre
Write-Host "`n=== NETTOYAGE ET RELANCE APP FLUTTER ===" -ForegroundColor Cyan

# 1. Nettoyer le cache Flutter
Write-Host "`n1. Nettoyage du cache Flutter..." -ForegroundColor Yellow
flutter clean

# 2. Récupérer les dépendances
Write-Host "`n2. Récupération des dépendances..." -ForegroundColor Yellow
flutter pub get

# 3. Afficher la configuration
Write-Host "`n=== CONFIGURATION PRODUCTION ===" -ForegroundColor Green
Write-Host "URL Backend: https://center-backend-v9rf.onrender.com" -ForegroundColor White
Write-Host "Mode: Production (pas de détection IP)" -ForegroundColor White
Write-Host "WebSocket: wss://center-backend-v9rf.onrender.com" -ForegroundColor White

# 4. Lancer l'application
Write-Host "`n3. Lancement de l'application..." -ForegroundColor Yellow
Write-Host "Appuyez sur Ctrl+C pour arrêter`n" -ForegroundColor Gray

flutter run
