# Test de connexion à l'API Backend
# =====================================

$baseUrl = "http://192.168.1.66:5000/api"
$headers = @{"Content-Type"="application/json"}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST DE CONNEXION À L'API" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Vérifier que le serveur répond
Write-Host "TEST 1: Vérification du serveur..." -ForegroundColor Yellow
try {
    $testEmail = "testuser$(Get-Random)@example.com"
    $registerBody = @{
        email = $testEmail
        password = "test123456"
        name = "Test User $(Get-Random)"
    } | ConvertTo-Json

    Write-Host "   Envoi vers: $baseUrl/auth/register" -ForegroundColor White
    Write-Host "   Email de test: $testEmail" -ForegroundColor White
    
    $response = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method POST -Headers $headers -Body $registerBody -TimeoutSec 10
    
    Write-Host "✅ SUCCÈS: Serveur accessible" -ForegroundColor Green
    Write-Host "   Réponse: $($response.message)" -ForegroundColor Green
    Write-Host "`n📧 Un email OTP a été envoyé à: $testEmail" -ForegroundColor Cyan
} catch {
    Write-Host "❌ ÉCHEC: Impossible de se connecter au serveur" -ForegroundColor Red
    Write-Host "   Erreur: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*refused*" -or $_.Exception.Message -like "*refusé*") {
        Write-Host "`n⚠️  Le serveur backend n'est pas démarré!" -ForegroundColor Yellow
        Write-Host "   Démarrez-le avec: cd backend; node server.js" -ForegroundColor White
    }
    elseif ($_.Exception.Message -like "*timeout*") {
        Write-Host "`n⚠️  Le serveur ne répond pas (timeout)" -ForegroundColor Yellow
        Write-Host "   Vérifiez que l'IP 192.168.1.66 est correcte" -ForegroundColor White
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "URL Backend: http://192.168.1.66:5000" -ForegroundColor White
Write-Host "Port: 5000" -ForegroundColor White
Write-Host "`nSi le test échoue, vérifiez:" -ForegroundColor Yellow
Write-Host "  1. Le serveur backend est démarré (cd backend; node server.js)" -ForegroundColor White
Write-Host "  2. Le port 5000 n'est pas bloqué par le pare-feu" -ForegroundColor White
Write-Host "  3. L'adresse IP 192.168.1.66 est correcte`n" -ForegroundColor White
