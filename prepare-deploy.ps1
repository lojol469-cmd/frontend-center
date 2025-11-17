# Script pour push les fichiers Docker vers GitHub

Write-Host "📦 Préparation du déploiement Render..." -ForegroundColor Cyan
Write-Host ""

# Vérifier si on est dans un repo Git
if (-not (Test-Path ".git")) {
    Write-Host "❌ Ce n'est pas un repository Git" -ForegroundColor Red
    Write-Host "Initialiser avec : git init" -ForegroundColor Yellow
    exit 1
}

Write-Host "🔍 Vérification des fichiers Docker..." -ForegroundColor Cyan
$files = @(
    "backend/Dockerfile.node",
    "backend/.dockerignore.node",
    "backend/render.yaml",
    "backend/DEPLOY_GUIDE.md",
    "backend/RECAP.md",
    "backend/test-docker.ps1",
    "backend/test-docker.sh"
)

$allExist = $true
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ $file (manquant)" -ForegroundColor Red
        $allExist = $false
    }
}

if (-not $allExist) {
    Write-Host ""
    Write-Host "❌ Certains fichiers sont manquants" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 Statut Git actuel :" -ForegroundColor Cyan
git status --short

Write-Host ""
Write-Host "➕ Ajout des fichiers Docker au staging..." -ForegroundColor Cyan
git add backend/Dockerfile.node
git add backend/.dockerignore.node
git add backend/render.yaml
git add backend/DEPLOY_GUIDE.md
git add backend/RECAP.md
git add backend/test-docker.ps1
git add backend/test-docker.sh
git add backend/.env.example

Write-Host ""
Write-Host "📝 Commit des changements..." -ForegroundColor Cyan
$commitMessage = "🐳 Add Docker configuration for Render deployment"
git commit -m $commitMessage

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Aucun changement à commiter ou erreur" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🚀 Push vers GitHub..." -ForegroundColor Cyan
Write-Host "Branche actuelle :" -ForegroundColor White
git branch --show-current

$response = Read-Host "Voulez-vous pusher maintenant ? (o/n)"
if ($response -eq "o" -or $response -eq "O" -or $response -eq "yes" -or $response -eq "y") {
    git push origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Push réussi !" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎯 Prochaines étapes :" -ForegroundColor Cyan
        Write-Host "  1. Aller sur render.com" -ForegroundColor White
        Write-Host "  2. Créer un nouveau Web Service" -ForegroundColor White
        Write-Host "  3. Sélectionner le repo BelikanM/CENTER" -ForegroundColor White
        Write-Host "  4. Suivre les instructions de DEPLOY_GUIDE.md" -ForegroundColor White
        Write-Host ""
        Write-Host "📖 Voir : backend/DEPLOY_GUIDE.md pour les détails" -ForegroundColor Yellow
    }
    else {
        Write-Host ""
        Write-Host "❌ Erreur lors du push" -ForegroundColor Red
        Write-Host "Vérifiez vos credentials GitHub" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "⏸️ Push annulé" -ForegroundColor Yellow
    Write-Host "Vous pouvez pusher manuellement avec : git push origin main" -ForegroundColor White
}
