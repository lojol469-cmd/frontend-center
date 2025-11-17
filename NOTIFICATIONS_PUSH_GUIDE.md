# 🔔 Guide des Notifications Push - Configuration Complète

## ✅ Ce qui a été configuré

### 1. **Firebase Cloud Messaging (FCM)**
- ✅ `firebase_core` et `firebase_messaging` ajoutés
- ✅ `google-services.json` créé pour Android
- ✅ Plugin Google Services configuré dans `build.gradle.kts`
- ✅ Firebase initialisé dans `main.dart`

### 2. **Service de Notifications**
Le `notification_service.dart` gère maintenant :
- 📱 **Notifications FCM** (vraies push notifications système)
- 🌐 **WebSocket** (notifications temps réel)
- 📲 **Local Notifications** (affichage des notifications)

### 3. **Flux des Notifications**

```
Backend (Firebase Admin SDK)
    ↓
    Envoie notification FCM
    ↓
Firebase Cloud Messaging (Google)
    ↓
    Notification reçue sur le téléphone
    ↓
Flutter App (FirebaseMessaging.onMessage)
    ↓
    Affichage notification système
```

## 🎯 Types de Notifications

### 1. **App au premier plan (foreground)**
- La notification est affichée localement
- Son et vibration personnalisés
- Badge mis à jour automatiquement

### 2. **App en arrière-plan (background)**
- Notification affichée par le système Android
- Son et icône par défaut
- Clic ouvre l'app à la bonne page

### 3. **App fermée (terminated)**
- Notification reçue par Firebase
- Affichée dans la barre de notifications
- Clic lance l'app

## 📱 Test des Notifications

### 1. Vérifier que Firebase est initialisé
Au démarrage de l'app, tu devrais voir dans les logs :
```
✅ Firebase initialisé
✅ Permission notifications accordée
🔑 Token FCM obtenu: eA3f...
✅ Token FCM enregistré sur le serveur
```

### 2. Tester l'envoi depuis le backend
Le backend envoie automatiquement des notifications pour :
- ❤️ Likes sur publications
- 💬 Commentaires
- 👤 Nouveaux followers
- 📬 Messages

### 3. Tester manuellement depuis Firebase Console
1. Va sur https://console.firebase.google.com
2. Projet `msdos-6eb64`
3. Cloud Messaging → Nouvelle campagne
4. Envoie une notification test

## 🔧 Permissions Nécessaires

### Android (déjà configuré dans AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

L'app demande automatiquement la permission au démarrage.

## 🐛 Résolution de Problèmes

### Problème : Notifications non reçues
**Solution** :
1. Vérifie que Firebase est initialisé (logs)
2. Vérifie que le token FCM est envoyé au backend
3. Redémarre l'app après installation

### Problème : "Please set your Application ID"
**Solution** :
- ✅ Déjà résolu ! Le fichier `google-services.json` est maintenant présent
- Nettoie et rebuild : `flutter clean && flutter run`

### Problème : Notifications seulement dans l'app
**Solution** :
- ✅ Déjà résolu ! FCM est maintenant configuré
- Les notifications s'affichent maintenant même quand l'app est fermée

## 📊 Architecture Complète

```
┌─────────────────────────────────────────────┐
│          Backend (Render)                   │
│  ┌─────────────────────────────────────┐   │
│  │  Firebase Admin SDK                 │   │
│  │  - Envoie notifications FCM         │   │
│  │  - Gère les tokens utilisateurs     │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│    Firebase Cloud Messaging (FCM)           │
│    - Serveurs Google                        │
│    - Routage des notifications              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           Flutter App (Mobile)              │
│  ┌─────────────────────────────────────┐   │
│  │  FirebaseMessaging                  │   │
│  │  - Reçoit les notifications         │   │
│  │  - Gère foreground/background       │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │  LocalNotifications                 │   │
│  │  - Affiche les notifications        │   │
│  │  - Sons et vibrations               │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │  WebSocket                          │   │
│  │  - Notifications temps réel         │   │
│  │  - Badge count                      │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## 🚀 Prochaines Étapes (Optionnel)

### 1. Personnaliser les Sons
Ajoute des fichiers `.mp3` dans `android/app/src/main/res/raw/`

### 2. Grouper les Notifications
Configure les canaux dans `notification_service.dart`

### 3. Actions Rapides
Ajoute des boutons dans les notifications (Répondre, Archiver, etc.)

### 4. Images dans les Notifications
Le backend peut déjà envoyer des images via FCM

## 📝 Notes Importantes

1. **Token FCM** : Expire et change parfois
   - Le service écoute `onTokenRefresh` automatiquement
   - Le nouveau token est envoyé au backend

2. **Backend déjà configuré** :
   - Firebase Admin SDK initialisé
   - Variable d'environnement `FIREBASE_SERVICE_ACCOUNT` configurée
   - Notifications envoyées automatiquement

3. **Mode Production** :
   - Connexion à Render : `https://center-backend-v9rf.onrender.com`
   - WebSocket : `wss://center-backend-v9rf.onrender.com`

---

**Dernière mise à jour** : 17 novembre 2025  
**Status** : ✅ Notifications Push Complètement Fonctionnelles
