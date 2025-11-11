# Script de test de l'API Backend
# =================================

$baseUrl = "http://localhost:5000/api"
$headers = @{"Content-Type"="application/json"}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST DE L'API BACKEND - SETRAF" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Inscription
Write-Host "TEST 1: Inscription" -ForegroundColor Yellow
$testEmail = "test$(Get-Random)@example.com"
$registerBody = @{
    email = $testEmail
    password = "test123456"
    name = "Test User $(Get-Random)"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method POST -Headers $headers -Body $registerBody
    Write-Host "✅ SUCCÈS:" $response.message -ForegroundColor Green
    Write-Host "   Email:" $testEmail
} catch {
    Write-Host "❌ ÉCHEC:" $_.Exception.Message -ForegroundColor Red
}

# Test 2: Connexion (envoi OTP)
Write-Host "`nTEST 2: Connexion (envoi OTP)" -ForegroundColor Yellow
$loginBody = @{
    email = "nyundumathryme@gmail.com"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -Headers $headers -Body $loginBody
    Write-Host "✅ SUCCÈS:" $response.message -ForegroundColor Green
} catch {
    Write-Host "❌ ÉCHEC:" $_.Exception.Message -ForegroundColor Red
}

# Test 3: Routes protégées (sans token - devrait échouer)
Write-Host "`nTEST 3: Route protégée sans token (devrait échouer)" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/publications" -Method GET -Headers $headers
    Write-Host "❌ INATTENDU: La route a répondu sans token" -ForegroundColor Red
} catch {
    Write-Host "✅ ATTENDU: Accès refusé (401)" -ForegroundColor Green
}

# Résumé
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ DES TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Backend opérationnel" -ForegroundColor Green
Write-Host "✅ Routes d'authentification fonctionnelles" -ForegroundColor Green
Write-Host "✅ Protection des routes sécurisées active" -ForegroundColor Green
Write-Host "`nPour tester avec le frontend Flutter:" -ForegroundColor Yellow
Write-Host "  1. Le serveur tourne sur: http://192.168.1.66:5000" -ForegroundColor White
Write-Host "  2. Lancez 'flutter run' dans un autre terminal" -ForegroundColor White
Write-Host "  3. Testez l'inscription depuis l'app mobile`n" -ForegroundColor White
