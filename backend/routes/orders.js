const express = require('express');
const { Order, User, EggPrice, DailyStock, Notification } = require('../models');
const auth = require('../middleware/auth');
const { sendPushToMany } = require('../services/push');

const router = express.Router();

// Generate order number: EGG-20260218-001
function generateOrderNumber() {
    const date = new Date().toISOString().split('T')[0].replace(/-/g, '');
    const rand = Math.floor(Math.random() * 9000) + 1000;
    return `EGG-${date}-${rand}`;
}

// Place order
router.post('/place', auth, async (req, res) => {
    try {
        const { trayCount, paymentMethod } = req.body;

        if (!trayCount || trayCount < 1) {
            return res.status(400).json({ success: false, message: 'Minimum 1 tray required' });
        }

        if (!['upi', 'pay_later'].includes(paymentMethod)) {
            return res.status(400).json({ success: false, message: 'Invalid payment method' });
        }

        // ── Stock check ──
        const today = new Date().toISOString().split('T')[0];
        const stock = await DailyStock.findOne({ where: { date: today } });

        if (!stock || stock.totalTrays === 0) {
            return res.status(400).json({
                success: false,
                message: 'No stock available for today. Please check back later.',
                availableTrays: 0,
            });
        }

        const remaining = stock.totalTrays - stock.soldTrays;
        if (trayCount > remaining) {
            return res.status(400).json({
                success: false,
                message: remaining > 0
                    ? `Only ${remaining} tray(s) available today. Please reduce your order.`
                    : 'All stock for today has been sold out!',
                availableTrays: remaining,
            });
        }

        // Get current price (Strictly today's)
        const price = await EggPrice.findOne({
            where: { district: req.user.district, priceDate: today },
        });

        if (!price) {
            return res.status(400).json({
                message: 'Egg rates for today have not been updated yet for your district. Please try again later.',
            });
        }

        const pricePerTray = parseFloat(price.pricePerTray);
        const totalAmount = pricePerTray * trayCount;

        const order = await Order.create({
            orderNumber: generateOrderNumber(),
            userId: req.user.id,
            trayCount,
            pricePerTray,
            totalAmount,
            paymentMethod,
            paymentStatus: paymentMethod === 'pay_later' ? 'pending' : 'pending',
            orderStatus: 'placed',
        });

        // ── Update sold count ──
        await stock.increment('soldTrays', { by: trayCount });
        await stock.reload();

        const newRemaining = stock.totalTrays - stock.soldTrays;

        // ── Admin notifications ──
        const adminUsers = await User.findAll({ where: { role: 'admin' } });

        if (newRemaining <= 50 && newRemaining > 0 && !stock.lowStockNotified) {
            // Low stock warning
            for (const admin of adminUsers) {
                await Notification.create({
                    userId: admin.id,
                    title: '⚠️ Low Stock Alert',
                    message: `Only ${newRemaining} tray(s) left today! Consider increasing the daily stock limit.`,
                    type: 'stock_alert',
                    metadata: { remainingTrays: newRemaining, date: today },
                });
            }
            await stock.update({ lowStockNotified: true });
        }

        if (newRemaining === 0 && !stock.outOfStockNotified) {
            // Out of stock
            for (const admin of adminUsers) {
                await Notification.create({
                    userId: admin.id,
                    title: '🚨 Stock Depleted!',
                    message: `All ${stock.totalTrays} trays for today have been sold! Increase the stock limit to accept more orders.`,
                    type: 'stock_alert',
                    metadata: { totalSold: stock.soldTrays, date: today },
                });
            }
            await stock.update({ outOfStockNotified: true });
        }

        // ── Push notification: only for pay_later (cash) orders ──
        // UPI orders get notified ONLY after payment is verified (in /payments/verify)
        if (paymentMethod === 'pay_later') {
            const adminFcmTokens = adminUsers.map(a => a.fcmToken).filter(Boolean);
            await sendPushToMany(
                adminFcmTokens,
                '📋 New Cash Order!',
                `${req.user.name} ordered ${trayCount} tray(s) — ₹${totalAmount.toFixed(2)} (Pay Later)`,
                { orderId: order.id, type: 'new_order_cash' },
            );
        }

        res.status(201).json({
            success: true,
            message: 'Order placed successfully',
            data: order,
        });
    } catch (error) {
        console.error('Place order error:', error);
        res.status(500).json({ success: false, message: 'Failed to place order' });
    }
});

// Get user's order history
router.get('/history', auth, async (req, res) => {
    try {
        const orders = await Order.findAll({
            where: { userId: req.user.id },
            order: [['created_at', 'DESC']],
        });

        res.json({ success: true, data: orders });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch orders' });
    }
});

// Get single order details
router.get('/:id', auth, async (req, res) => {
    try {
        const order = await Order.findOne({
            where: { id: req.params.id, userId: req.user.id },
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        res.json({ success: true, data: order });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch order' });
    }
});

module.exports = router;
