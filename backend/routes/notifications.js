const express = require('express');
const { Notification } = require('../models');
const auth = require('../middleware/auth');

const router = express.Router();

// Get my notifications
router.get('/my', auth, async (req, res) => {
    try {
        const notifications = await Notification.findAll({
            where: { userId: req.user.id },
            order: [['created_at', 'DESC']],
            limit: 50,
        });

        const unreadCount = await Notification.count({
            where: { userId: req.user.id, isRead: false },
        });

        res.json({ success: true, data: { notifications, unreadCount } });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch notifications' });
    }
});

// Mark as read
router.put('/read/:id', auth, async (req, res) => {
    try {
        const notification = await Notification.findOne({
            where: { id: req.params.id, userId: req.user.id },
        });

        if (!notification) {
            return res.status(404).json({ success: false, message: 'Notification not found' });
        }

        await notification.update({ isRead: true });
        res.json({ success: true, message: 'Marked as read' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to update notification' });
    }
});

// Mark all as read
router.put('/read-all', auth, async (req, res) => {
    try {
        await Notification.update(
            { isRead: true },
            { where: { userId: req.user.id, isRead: false } }
        );
        res.json({ success: true, message: 'All notifications marked as read' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to update notifications' });
    }
});

// Save or update FCM device token (called on app launch/login)
router.post('/fcm-token', auth, async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) return res.status(400).json({ success: false, message: 'Token required' });

        const { User } = require('../models');
        await User.update({ fcmToken: token }, { where: { id: req.user.id } });
        res.json({ success: true, message: 'FCM token saved' });
    } catch (error) {
        console.error('FCM token save error:', error);
        res.status(500).json({ success: false, message: 'Failed to save FCM token' });
    }
});

// ── DEBUG: Check FCM tokens for all admins (admin only)
router.get('/check-tokens', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ success: false, message: 'Admin only' });
    try {
        const { User } = require('../models');
        const admins = await User.findAll({ where: { role: 'admin' }, attributes: ['id', 'name', 'phone', 'fcmToken'] });
        const allUsers = await User.findAll({ attributes: ['id', 'name', 'role', 'fcmToken'] });
        res.json({
            success: true,
            data: {
                adminTokens: admins.map(a => ({ name: a.name, hasToken: !!a.fcmToken, tokenStart: a.fcmToken ? a.fcmToken.substring(0, 20) : null })),
                allUsersWithTokens: allUsers.filter(u => u.fcmToken).length,
                totalUsers: allUsers.length,
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// ── DEBUG: Send a test push to yourself
router.post('/test-push', auth, async (req, res) => {
    try {
        const { User } = require('../models');
        const { sendPush } = require('../services/push');
        const user = await User.findByPk(req.user.id);
        if (!user.fcmToken) {
            return res.json({ success: false, message: 'No FCM token saved for your account. Login again with the latest app.' });
        }
        await sendPush(user.fcmToken, '🔔 Test Notification', 'Push notifications are working! 🎉', { type: 'test' });
        res.json({ success: true, message: `Test push sent to ${user.name}` });
    } catch (error) {
        console.error('Test push error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;
