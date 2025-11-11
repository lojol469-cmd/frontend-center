# Script de traitement automatique des videos aquatiques
# Optimise, compresse et deplace les videos dans le projet

Write-Host "Traitement des videos aquatiques" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Chemins
$sourceFolder = "C:\Users\Admin\Pictures\DAT.ERT\ERT\flutterAPP\CENTER\videos"
$destFolder = "assets\videos"
$maxSizeMB = 10

# Vérifier si FFmpeg est disponible
$ffmpegPath = $null
$ffmpegLocations = @(
    "ffmpeg",
    "C:\ffmpeg\bin\ffmpeg.exe",
    "C:\Program Files\ffmpeg\bin\ffmpeg.exe",
    "$env:USERPROFILE\ffmpeg\bin\ffmpeg.exe"
)

foreach ($location in $ffmpegLocations) {
    try {
        $testResult = & $location -version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $ffmpegPath = $location
            break
        }
    } catch {
        continue
    }
}

if (-not $ffmpegPath) {
    Write-Host "❌ FFmpeg n'est pas installé !" -ForegroundColor Red
    Write-Host ""
    Write-Host "📥 Installation requise:" -ForegroundColor Yellow
    Write-Host "   1. Téléchargez FFmpeg: https://github.com/BtbN/FFmpeg-Builds/releases" -ForegroundColor White
    Write-Host "   2. Ou utilisez Chocolatey: choco install ffmpeg" -ForegroundColor White
    Write-Host "   3. Ou avec winget: winget install ffmpeg" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Alternative: Utilisez le service en ligne gratuit" -ForegroundColor Cyan
    Write-Host "   https://www.freeconvert.com/video-compressor" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "✓ FFmpeg trouvé: $ffmpegPath" -ForegroundColor Green
Write-Host ""

# Vérifier si le dossier source existe
if (-not (Test-Path $sourceFolder)) {
    Write-Host "❌ Dossier source introuvable: $sourceFolder" -ForegroundColor Red
    exit 1
}

# Créer le dossier de destination s'il n'existe pas
if (-not (Test-Path $destFolder)) {
    New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
}

# Lister les vidéos
$videos = Get-ChildItem -Path $sourceFolder -Filter "*.mp4"
Write-Host "📹 Vidéos trouvées: $($videos.Count)" -ForegroundColor Cyan
Write-Host ""

if ($videos.Count -eq 0) {
    Write-Host "❌ Aucune vidéo trouvée dans: $sourceFolder" -ForegroundColor Red
    exit 1
}

# Fonction pour obtenir la durée d'une vidéo
function Get-VideoDuration {
    param($videoPath)
    try {
        $output = & $ffmpegPath -i $videoPath 2>&1 | Select-String "Duration"
        if ($output -match "Duration: (\d+):(\d+):(\d+\.\d+)") {
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            $seconds = [double]$matches[3]
            return ($hours * 3600) + ($minutes * 60) + $seconds
        }
    } catch {
        return 0
    }
    return 0
}

# Fonction pour compresser une vidéo
function Compress-Video {
    param(
        [string]$inputPath,
        [string]$outputPath,
        [int]$targetSizeMB
    )
    
    Write-Host "   🔄 Compression en cours..." -ForegroundColor Yellow
    
    # Calculer le bitrate cible (en kbps)
    $duration = Get-VideoDuration $inputPath
    if ($duration -le 0) {
        Write-Host "   ❌ Impossible de lire la durée" -ForegroundColor Red
        return $false
    }
    
    # Formule: (taille_cible_MB * 8192) / durée_secondes - 128 (pour l'audio)
    $targetBitrate = [math]::Floor((($targetSizeMB * 8192) / $duration) - 128)
    
    # Limiter le bitrate minimum
    if ($targetBitrate -lt 500) {
        $targetBitrate = 500
    }
    
    Write-Host "   📊 Bitrate calculé: $targetBitrate kbps" -ForegroundColor Gray
    
    # Compression avec FFmpeg (720p, 30fps, bitrate calculé)
    $ffmpegArgs = @(
        "-i", $inputPath,
        "-c:v", "libx264",
        "-preset", "medium",
        "-b:v", "${targetBitrate}k",
        "-maxrate", "${targetBitrate}k",
        "-bufsize", "$($targetBitrate * 2)k",
        "-vf", "scale=-2:720",
        "-r", "30",
        "-c:a", "aac",
        "-b:a", "128k",
        "-movflags", "+faststart",
        "-y",
        $outputPath
    )
    
    try {
        $process = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
        return ($process.ExitCode -eq 0)
    } catch {
        Write-Host "   ❌ Erreur: $_" -ForegroundColor Red
        return $false
    }
}

# Traiter chaque vidéo
$processed = 0
$skipped = 0
$failed = 0

foreach ($video in $videos) {
    $videoNum = $videos.IndexOf($video) + 1
    Write-Host "[$videoNum/$($videos.Count)] 📹 $($video.Name)" -ForegroundColor Cyan
    
    $sourceSize = [math]::Round($video.Length / 1MB, 2)
    Write-Host "   📦 Taille source: $sourceSize MB" -ForegroundColor Gray
    
    # Définir le nom de sortie
    $outputName = "aquarium_$videoNum.mp4"
    $outputPath = Join-Path $destFolder $outputName
    
    # Si la vidéo est déjà < 10 MB, copier directement
    if ($video.Length -le ($maxSizeMB * 1MB)) {
        Write-Host "   ✓ Déjà optimisée, copie directe..." -ForegroundColor Green
        Copy-Item -Path $video.FullName -Destination $outputPath -Force
        $outputSize = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Host "   💾 Enregistré: $outputName ($outputSize MB)" -ForegroundColor Green
        $processed++
    }
    else {
        # Compresser la vidéo
        $success = Compress-Video -inputPath $video.FullName -outputPath $outputPath -targetSizeMB ($maxSizeMB - 1)
        
        if ($success -and (Test-Path $outputPath)) {
            $outputSize = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
            
            if ($outputSize -le $maxSizeMB) {
                Write-Host "   ✓ Compressée: $sourceSize MB → $outputSize MB" -ForegroundColor Green
                Write-Host "   💾 Enregistré: $outputName" -ForegroundColor Green
                $processed++
            }
            else {
                Write-Host "   ⚠️  Encore trop volumineuse: $outputSize MB" -ForegroundColor Yellow
                Write-Host "   🔄 Nouvelle tentative avec bitrate plus bas..." -ForegroundColor Yellow
                
                # Deuxième tentative avec bitrate réduit de 30%
                Remove-Item $outputPath -Force
                $success = Compress-Video -inputPath $video.FullName -outputPath $outputPath -targetSizeMB ([math]::Floor($maxSizeMB * 0.7))
                
                if ($success -and (Test-Path $outputPath)) {
                    $outputSize = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
                    Write-Host "   ✓ Compressée: $sourceSize MB → $outputSize MB" -ForegroundColor Green
                    Write-Host "   💾 Enregistré: $outputName" -ForegroundColor Green
                    $processed++
                }
                else {
                    Write-Host "   ❌ Échec de la compression" -ForegroundColor Red
                    $failed++
                }
            }
        }
        else {
            Write-Host "   ❌ Échec de la compression" -ForegroundColor Red
            $failed++
        }
    }
    
    Write-Host ""
}

# Résumé
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "📊 RÉSUMÉ" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "✓ Traitées avec succès: $processed" -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host "⊘ Ignorées: $skipped" -ForegroundColor Yellow
}
if ($failed -gt 0) {
    Write-Host "✗ Échecs: $failed" -ForegroundColor Red
}
Write-Host ""

# Lister les vidéos créées
$outputVideos = Get-ChildItem -Path $destFolder -Filter "aquarium_*.mp4"
if ($outputVideos.Count -gt 0) {
    Write-Host "📹 Vidéos disponibles dans $destFolder :" -ForegroundColor Cyan
    foreach ($outVid in $outputVideos) {
        $size = [math]::Round($outVid.Length / 1MB, 2)
        $duration = Get-VideoDuration $outVid.FullName
        Write-Host "   • $($outVid.Name) - $size MB - $([math]::Round($duration, 1))s" -ForegroundColor White
    }
    Write-Host ""
    
    # Créer un fichier de configuration
    $configPath = Join-Path $destFolder "videos_config.txt"
    $outputVideos | ForEach-Object {
        "$($_.Name)" | Out-File -FilePath $configPath -Append -Encoding UTF8
    }
    Write-Host "✓ Configuration sauvegardée: $configPath" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "   Utilisation dans Flutter:" -ForegroundColor Cyan
    Write-Host "AquaticBackground(" -ForegroundColor Gray
    Write-Host "  videoSource: 'assets/videos/aquarium_1.mp4'," -ForegroundColor Gray
    Write-Host "  isAsset: true," -ForegroundColor Gray
    Write-Host "  opacity: 0.3," -ForegroundColor Gray
    Write-Host "  child: // Votre contenu" -ForegroundColor Gray
    Write-Host ")" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Traitement termine !" -ForegroundColor Green
