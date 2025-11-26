#!/usr/bin/env node

/**
 * Script de test de connexion à l'URL de production
 * Vérifie que le serveur Render répond correctement
 */

const https = require('https');

const PRODUCTION_URL = 'https://center-backend-v9rf.onrender.com';
const TEST_ENDPOINT = '/api/server-info';

console.log('🧪 TEST DE CONNEXION À L\'URL DE PRODUCTION');
console.log('==========================================');
console.log(`🌐 URL de production: ${PRODUCTION_URL}`);
console.log(`📡 Endpoint de test: ${TEST_ENDPOINT}`);
console.log('');

const testUrl = PRODUCTION_URL + TEST_ENDPOINT;

console.log(`🔍 Test de connexion à: ${testUrl}`);

const request = https.get(testUrl, (res) => {
  console.log(`📊 Code de statut: ${res.statusCode}`);

  if (res.statusCode === 200) {
    console.log('✅ CONNEXION RÉUSSIE - Le serveur Render répond correctement');
    console.log('🎯 L\'application Flutter utilisera cette URL en production');
  } else {
    console.log('❌ CONNEXION ÉCHOUÉE - Code de statut inattendu');
  }

  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log('📄 Réponse du serveur:', jsonData);
    } catch (e) {
      console.log('📄 Réponse brute:', data.substring(0, 100) + '...');
    }
    console.log('');
    console.log('✅ TEST TERMINÉ - URL de production confirmée');
  });
});

request.on('error', (err) => {
  console.log('❌ ERREUR DE CONNEXION:', err.message);
  console.log('💡 Vérifiez que le serveur Render est déployé et accessible');
});

request.setTimeout(10000, () => {
  console.log('⏱️ TIMEOUT - La connexion prend trop de temps');
  request.destroy();
});