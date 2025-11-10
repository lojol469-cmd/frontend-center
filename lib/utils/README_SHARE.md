# ShareHelper - Partage Avancé avec Rich Preview

## 📱 Fonctionnalité

Le `ShareHelper` permet de partager des publications avec une prévisualisation enrichie (rich preview) dans les applications de messagerie, comme YouTube, Instagram ou TikTok.

## ✨ Caractéristiques

- **Rich Preview**: Le média (image/vidéo) est affiché dans l'aperçu du partage
- **Téléchargement automatique**: Les médias sont téléchargés en cache avant le partage
- **Fallback intelligent**: Si le téléchargement échoue, partage le lien direct
- **Support multi-média**: Images, vidéos, texte, et partage multiple
- **UI/UX soignée**: Dialog de chargement avec progression
- **Auto-nettoyage**: Les fichiers temporaires sont supprimés automatiquement

## 🎯 Utilisation

### 1. Partage d'une publication avec média

```dart
import '../utils/share_helper.dart';

// Partager une vidéo
await ShareHelper.sharePublication(
  context: context,
  mediaUrl: 'https://exemple.com/video.mp4',
  userName: 'John Doe',
  content: 'Découvre ma nouvelle vidéo !',
  mediaType: 'video', // ou 'image'
);
```

### 2. Partage de texte uniquement

```dart
// Pour les publications sans média
await ShareHelper.shareText(
  context: context,
  userName: 'Jane Smith',
  content: 'Pensée du jour : Croyez en vous !',
);
```

### 3. Partage multiple de médias

```dart
// Partager plusieurs photos
await ShareHelper.shareMultipleMedia(
  context: context,
  mediaUrls: [
    'https://exemple.com/photo1.jpg',
    'https://exemple.com/photo2.jpg',
    'https://exemple.com/photo3.jpg',
  ],
  userName: 'PhotoPro',
  content: 'Ma collection de photos',
);
```

## 📦 Format du partage

### Pour une vidéo :
```
🎬 Vidéo de John Doe sur CENTER

Découvre cette vidéo incroyable !

📱 Télécharge CENTER pour voir plus de vidéos
🌐 https://serveur.com/video.mp4
```

### Pour une image :
```
📸 Photo de Jane Smith sur CENTER

Magnifique coucher de soleil

📱 Télécharge CENTER pour voir plus de contenus
🌐 https://serveur.com/photo.jpg
```

### Pour du texte :
```
💬 Publication de Alex Martin sur CENTER

Pensée du jour : La persévérance est la clé du succès

📱 Rejoins-nous sur CENTER
```

## 🎨 Aperçu du partage

Lorsqu'un utilisateur partage du contenu, voici ce qui se passe :

1. **Dialog de chargement** apparaît avec :
   - Indicateur de progression animé
   - Message "Préparation du partage..."
   - Message "Téléchargement du média"

2. **Téléchargement** :
   - Le média est téléchargé depuis le serveur
   - Sauvegardé dans le cache temporaire de l'appareil
   - Timeout de 30 secondes pour éviter les blocages

3. **Partage natif** :
   - Le sélecteur natif s'ouvre (WhatsApp, Telegram, etc.)
   - Le média est attaché pour une rich preview
   - Le texte descriptif est inclus

4. **Nettoyage** :
   - Après 30 secondes, le fichier temporaire est supprimé
   - Libère l'espace de stockage automatiquement

## 🔧 Configuration requise

### Dépendances dans `pubspec.yaml` :

```yaml
dependencies:
  share_plus: ^10.1.3
  path_provider: ^2.1.5
  http: ^1.2.2
```

### Imports nécessaires :

```dart
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
```

## 📱 Exemple d'intégration

### Dans TrendsPage (Mode vidéo) :

```dart
ElevatedButton(
  onPressed: () => ShareHelper.sharePublication(
    context: context,
    mediaUrl: videoUrl,
    userName: publication['userId']['name'],
    content: publication['description'],
    mediaType: 'video',
  ),
  child: const Text('Partager'),
)
```

### Dans SocialPage (Feed) :

```dart
PostCard(
  // ... autres paramètres
  onShare: () async {
    final publication = _publications[index];
    final media = publication['media'];
    
    if (media != null && media.isNotEmpty) {
      await ShareHelper.sharePublication(
        context: context,
        mediaUrl: media[0]['url'],
        userName: publication['userId']['name'],
        content: publication['content'],
        mediaType: media[0]['type'],
      );
    } else {
      await ShareHelper.shareText(
        context: context,
        userName: publication['userId']['name'],
        content: publication['content'],
      );
    }
  },
)
```

## 🚀 Avantages

### Par rapport au partage simple :

| Fonctionnalité | Partage Simple | ShareHelper |
|----------------|----------------|-------------|
| Rich Preview | ❌ Non | ✅ Oui |
| Aperçu média | ❌ Lien uniquement | ✅ Image/Vidéo visible |
| Téléchargement | ❌ Manuel | ✅ Automatique |
| Fallback | ❌ Non | ✅ Oui |
| Nettoyage | ❌ Manuel | ✅ Automatique |
| UX | ⚠️ Basique | ✅ Professionnelle |

## 🎯 Applications compatibles

Le rich preview fonctionne avec :
- ✅ WhatsApp
- ✅ Telegram
- ✅ Messenger
- ✅ Instagram (stories)
- ✅ Email
- ✅ Messages (iOS/Android)
- ✅ Twitter/X
- ✅ LinkedIn
- ✅ Discord

## ⚡ Performance

- Téléchargement asynchrone (non-bloquant)
- Cache temporaire optimisé
- Timeout de 30 secondes pour éviter les blocages
- Nettoyage automatique après 30 secondes
- Gestion intelligente des erreurs

## 🛡️ Gestion des erreurs

Le helper gère automatiquement :
- ❌ Échec du téléchargement → Partage le lien direct
- ❌ Timeout réseau → Affiche un message d'erreur
- ❌ Média introuvable → Notification à l'utilisateur
- ❌ Erreur de partage → SnackBar avec détails

## 📝 Notes importantes

1. Les fichiers temporaires sont stockés dans le cache système
2. Le nettoyage se fait automatiquement après 30 secondes
3. Le partage fonctionne hors ligne une fois le média téléchargé
4. La taille des vidéos peut impacter le temps de téléchargement
5. Les permissions sont gérées automatiquement par `share_plus`

## 🔮 Évolutions futures

- [ ] Compression des vidéos avant partage
- [ ] Partage sur réseaux sociaux spécifiques (API natives)
- [ ] Statistiques de partage
- [ ] Prévisualisation du partage avant confirmation
- [ ] Support des GIFs animés
- [ ] Watermark automatique sur les médias
