const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin eagerly on module load
let initialized = false;

function ensureInitialized() {
    if (initialized) return;
    try {
        const serviceAccountPath = path.join(__dirname, '../firebase-service-account.json');
        if (!fs.existsSync(serviceAccountPath)) {
            console.warn('⚠️  firebase-service-account.json not found at:', serviceAccountPath);
            return;
        }
        const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });
        initialized = true;
        console.log('✅ Firebase Admin SDK initialized — push notifications enabled');
    } catch (error) {
        console.error('❌ Firebase Admin SDK init failed:', error.message);
    }
}

// Initialize immediately when this module is loaded
ensureInitialized();

/**
 * Send a push notification to a single FCM token.
 * @param {string} fcmToken - Device FCM token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Optional extra data
 */
async function sendPush(fcmToken, title, body, data = {}) {
    if (!fcmToken) return;
    ensureInitialized();
    if (!initialized) return;

    try {
        await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'eggova_notifications',
                },
            },
        });
        console.log(`📲 Push sent to ${fcmToken.substring(0, 20)}...`);
    } catch (error) {
        console.warn(`⚠️  Push failed for token: ${error.message}`);
    }
}

/**
 * Send a push to multiple FCM tokens.
 * @param {string[]} tokens
 */
async function sendPushToMany(tokens, title, body, data = {}) {
    const validTokens = tokens.filter(Boolean);
    if (!validTokens.length) return;
    await Promise.all(validTokens.map(t => sendPush(t, title, body, data)));
}

module.exports = { sendPush, sendPushToMany };
