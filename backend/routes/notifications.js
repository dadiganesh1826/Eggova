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

module.exports = router;
