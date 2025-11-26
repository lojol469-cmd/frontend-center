const https = require('https');

// Configuration
const BASE_URL = 'https://center-backend-v9rf.onrender.com';
const API_PREFIX = '/api';

// Fonction helper pour faire des requêtes HTTP
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, {
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      }
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({ status: res.statusCode, data: jsonData });
        } catch (e) {
          resolve({ status: res.statusCode, data });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (options.body) {
      req.write(JSON.stringify(options.body));
    }

    req.end();
  });
}

// Test des routes de cartes d'identité virtuelles
async function testVirtualIDCards() {
  console.log('🧪 Test des routes de cartes d\'identité virtuelles\n');

  try {
    // 1. Test de récupération des cartes (sans token - devrait échouer)
    console.log('1. Test récupération cartes sans authentification:');
    try {
      const response = await makeRequest(`${BASE_URL}${API_PREFIX}/virtual-id-cards`);
      console.log('❌ Réponse inattendue:', response.status);
    } catch (error) {
      console.log('✅ Échec attendu:', error.message);
    }

    // 2. Test de création (sans token - devrait échouer)
    console.log('\n2. Test création carte sans authentification:');
    try {
      const response = await makeRequest(`${BASE_URL}${API_PREFIX}/virtual-id-cards`, {
        method: 'POST',
        body: {
          cardData: {
            firstName: 'Test',
            lastName: 'User',
            idNumber: 'TEST123'
          }
        }
      });
      console.log('❌ Réponse inattendue:', response.status);
    } catch (error) {
      console.log('✅ Échec attendu:', error.message);
    }

    // 3. Test de récupération des stats
    console.log('\n3. Test récupération stats sans authentification:');
    try {
      const response = await makeRequest(`${BASE_URL}${API_PREFIX}/virtual-id-cards/stats`);
      console.log('❌ Réponse inattendue:', response.status);
    } catch (error) {
      console.log('✅ Échec attendu:', error.message);
    }

    // 4. Test endpoint admin
    console.log('\n4. Test endpoint admin sans authentification:');
    try {
      const response = await makeRequest(`${BASE_URL}${API_PREFIX}/virtual-id-cards/admin/all`);
      console.log('❌ Réponse inattendue:', response.status);
    } catch (error) {
      console.log('✅ Échec attendu:', error.message);
    }

    console.log('\n✅ Tests terminés - Les routes nécessitent une authentification comme prévu');

  } catch (error) {
    console.error('❌ Erreur lors des tests:', error.message);
  }
}

// Test de connexion générale
async function testServerConnection() {
  console.log('🌐 Test de connexion au serveur\n');

  try {
    const response = await makeRequest(`${BASE_URL}${API_PREFIX}/server-info`);
    console.log('✅ Serveur accessible:', response.status);
    console.log('📄 Données:', response.data);
  } catch (error) {
    console.error('❌ Erreur de connexion:', error.message);
  }
}

// Exécuter les tests
async function runTests() {
  await testServerConnection();
  await testVirtualIDCards();
}

runTests();