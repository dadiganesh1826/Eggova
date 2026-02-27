/**
 * firebase-admin.js
 * Exports the firebase-admin instance.
 * The SDK is initialized in services/push.js on startup.
 * This module just re-exports the same admin object for use in other modules.
 */
const admin = require('firebase-admin');
module.exports = admin;
