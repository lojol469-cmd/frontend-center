/**
 * Configuration Firebase Admin SDK pour les Push Notifications
 * 
 * IMPORTANT: Avant d'utiliser ce fichier, tu dois:
 * 1. Télécharger la clé privée depuis Firebase Console
 * 2. La placer dans: backend/firebase-service-account.json
 * 3. Installer: npm install firebase-admin
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let firebaseInitialized = false;

/**
 * Initialiser Firebase Admin SDK
 */
function initializeFirebase() {
  if (firebaseInitialized) {
    console.log('✅ Firebase déjà initialisé');
    return true;
  }

  try {
    // Chemin vers le fichier de clé privée
    const serviceAccountPath = path.join(__dirname, 'firebase-service-account.json');
    
    // Vérifier si le fichier existe
    if (!fs.existsSync(serviceAccountPath)) {
      console.warn('⚠️ Fichier firebase-service-account.json non trouvé');
      console.warn('📝 Pour activer les push notifications:');
      console.warn('   1. Va sur https://console.firebase.google.com');
      console.warn('   2. Projet: msdos-6eb64');
      console.warn('   3. Paramètres → Comptes de service → Générer une clé privée');
      console.warn('   4. Place le fichier dans: backend/firebase-service-account.json');
      return false;
    }

    // Initialiser Firebase Admin
    const serviceAccount = require('./firebase-service-account.json');
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: 'https://msdos-6eb64-default-rtdb.firebaseio.com'
    });

    firebaseInitialized = true;
    console.log('✅ Firebase Admin SDK initialisé avec succès');
    console.log('🔔 Push notifications activées pour: msdos-6eb64');
    return true;
  } catch (error) {
    console.error('❌ Erreur initialisation Firebase:', error.message);
    return false;
  }
}

/**
 * Envoyer une notification push à un appareil via FCM
 * @param {string} fcmToken - Token FCM de l'appareil
 * @param {object} notification - Contenu de la notification
 * @param {string} notification.title - Titre
 * @param {string} notification.body - Message
 * @param {object} notification.data - Données additionnelles
 */
async function sendPushNotificationFCM(fcmToken, notification) {
  if (!firebaseInitialized) {
    console.log('⚠️ Firebase non initialisé, impossible d\'envoyer la notification');
    return { success: false, error: 'Firebase not initialized' };
  }

  if (!fcmToken) {
    console.log('⚠️ Pas de token FCM fourni');
    return { success: false, error: 'No FCM token' };
  }

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title || 'Center App',
        body: notification.body || 'Nouvelle notification',
        // Image du logo de l'app (optionnel)
        imageUrl: notification.imageUrl || undefined
      },
      data: {
        // Données custom pour navigation deepLink
        ...(notification.data || {}),
        // Convertir tous les champs en string (requis par FCM)
        ...Object.fromEntries(
          Object.entries(notification.data || {}).map(([k, v]) => [k, String(v)])
        )
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'center_notifications', // Canal de notification Android
          icon: 'ic_notification', // Icône personnalisée
          color: '#00D4FF', // Couleur accent (cyan Center App)
          sound: 'default',
          tag: notification.data?.type || 'general', // Grouper par type
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            contentAvailable: true
          }
        }
      }
    };

    console.log(`📤 Envoi notification FCM: "${notification.title}"`);
    const response = await admin.messaging().send(message);
    console.log('✅ Notification envoyée avec succès:', response);
    
    return { success: true, messageId: response };
  } catch (error) {
    console.error('❌ Erreur envoi notification FCM:', error.message);
    
    // Gestion des erreurs spécifiques
    if (error.code === 'messaging/invalid-registration-token' || 
        error.code === 'messaging/registration-token-not-registered') {
      console.log('⚠️ Token FCM invalide ou expiré');
      return { success: false, error: 'Invalid FCM token', shouldRemoveToken: true };
    }
    
    return { success: false, error: error.message };
  }
}

/**
 * Envoyer des notifications à plusieurs appareils
 * @param {string[]} fcmTokens - Liste des tokens FCM
 * @param {object} notification - Contenu de la notification
 */
async function sendMulticastNotification(fcmTokens, notification) {
  if (!firebaseInitialized) {
    console.log('⚠️ Firebase non initialisé');
    return { success: false, error: 'Firebase not initialized' };
  }

  if (!fcmTokens || fcmTokens.length === 0) {
    console.log('⚠️ Aucun token FCM fourni');
    return { success: false, error: 'No FCM tokens' };
  }

  try {
    const message = {
      tokens: fcmTokens.slice(0, 500), // Max 500 tokens par batch
      notification: {
        title: notification.title || 'Center App',
        body: notification.body || 'Nouvelle notification'
      },
      data: Object.fromEntries(
        Object.entries(notification.data || {}).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: 'center_notifications',
          icon: 'ic_notification',
          color: '#00D4FF',
          sound: 'default'
        }
      }
    };

    console.log(`📤 Envoi notification multicast à ${fcmTokens.length} appareils`);
    const response = await admin.messaging().sendMulticast(message);
    
    console.log(`✅ ${response.successCount}/${fcmTokens.length} notifications envoyées`);
    if (response.failureCount > 0) {
      console.log(`⚠️ ${response.failureCount} échecs`);
    }
    
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses
    };
  } catch (error) {
    console.error('❌ Erreur envoi multicast:', error.message);
    return { success: false, error: error.message };
  }
}

module.exports = {
  initializeFirebase,
  sendPushNotificationFCM,
  sendMulticastNotification,
  isInitialized: () => firebaseInitialized
};
