const express = require('express');
const { Op } = require('sequelize');
const { User, Order, Notification, DailyStock, EggPrice } = require('../models');
const auth = require('../middleware/auth');
const adminOnly = require('../middleware/adminOnly');

const router = express.Router();

// Get all registered users
router.get('/users', auth, adminOnly, async (req, res) => {
    try {
        const users = await User.findAll({
            where: { role: 'user' },
            attributes: { exclude: ['passwordHash', 'password_hash'] },
            order: [['created_at', 'DESC']],
        });

        res.json({ success: true, data: users });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch users' });
    }
});

// Get pending users
router.get('/users/pending', auth, adminOnly, async (req, res) => {
    try {
        const users = await User.findAll({
            where: { role: 'user', status: 'pending' },
            attributes: { exclude: ['passwordHash', 'password_hash'] },
            order: [['created_at', 'DESC']],
        });

        res.json({ success: true, data: users });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch pending users' });
    }
});

const { sendPush } = require('../services/push');

// Approve a pending user
router.put('/users/:id/approve', auth, adminOnly, async (req, res) => {
    try {
        const user = await User.findByPk(req.params.id);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        user.status = 'approved';
        await user.save();

        // Notify user
        try {
            await Notification.create({
                userId: user.id,
                title: 'Account Approved! 🎉',
                message: 'Your Eggova account has been approved. You can now access all features!',
                type: 'account_approved',
            });

            if (user.fcmToken) {
                await sendPush(
                    user.fcmToken,
                    'Account Approved! 🎉',
                    'Your Eggova account has been approved. You can now access all features!'
                );
            }
        } catch (notifierErr) {
            console.error('Failed to notify user of approval:', notifierErr);
        }

        res.json({ success: true, message: 'User approved successfully', data: user.toSafeJSON() });
    } catch (error) {
        console.error('Approve user error:', error);
        res.status(500).json({ success: false, message: 'Failed to approve user' });
    }
});

// Get pending payments
router.get('/pending-payments', auth, adminOnly, async (req, res) => {
    try {
        const orders = await Order.findAll({
            where: {
                paymentStatus: { [Op.in]: ['pending', 'approval_pending'] },
            },
            include: [{
                model: User,
                as: 'user',
                attributes: ['id', 'name', 'phone', 'email', 'address', 'district'],
                required: false,
            }],
            order: [['created_at', 'DESC']],
        });

        res.json({ success: true, data: orders });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch pending payments' });
    }
});

// Get completed payments
router.get('/completed-payments', auth, adminOnly, async (req, res) => {
    try {
        const orders = await Order.findAll({
            where: { paymentStatus: 'completed' },
            include: [{
                model: User,
                as: 'user',
                attributes: ['id', 'name', 'phone', 'email', 'address', 'district'],
                required: false,
            }],
            order: [['paid_at', 'DESC']],
        });

        res.json({ success: true, data: orders });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch completed payments' });
    }
});

// Approve user's payment request
router.post('/approve-payment/:orderId', auth, adminOnly, async (req, res) => {
    try {
        const order = await Order.findOne({
            where: { id: req.params.orderId, paymentStatus: 'approval_pending' },
            include: [{ model: User, as: 'user' }],
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Pending approval not found' });
        }

        await order.update({
            paymentStatus: 'completed',
            orderStatus: 'confirmed',
            paidAt: new Date(),
        });

        // Notify user
        await Notification.create({
            userId: order.userId,
            title: 'Payment Approved! ✅',
            message: `Your payment of ₹${order.totalAmount} for order ${order.orderNumber} has been approved`,
            type: 'payment_approved',
            metadata: { orderId: order.id },
        });

        res.json({ success: true, message: 'Payment approved', data: order });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to approve payment' });
    }
});

// Dashboard stats
router.get('/dashboard', auth, adminOnly, async (req, res) => {
    try {
        const totalUsers = await User.count({ where: { role: 'user' } });
        const totalOrders = await Order.count();
        const pendingPayments = await Order.count({
            where: { paymentStatus: { [Op.in]: ['pending', 'approval_pending'] } },
        });
        const completedPayments = await Order.count({ where: { paymentStatus: 'completed' } });

        const totalRevenue = await Order.sum('total_amount', {
            where: { paymentStatus: 'completed' },
        });
        const pendingAmount = await Order.sum('total_amount', {
            where: { paymentStatus: { [Op.in]: ['pending', 'approval_pending'] } },
        });

        res.json({
            success: true,
            data: {
                totalUsers,
                totalOrders,
                pendingPayments,
                completedPayments,
                totalRevenue: totalRevenue || 0,
                pendingAmount: pendingAmount || 0,
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch dashboard stats' });
    }
});

// Generate order number helper
function generateOrderNumber() {
    const date = new Date().toISOString().split('T')[0].replace(/-/g, '');
    const rand = Math.floor(Math.random() * 9000) + 1000;
    return `EGG-${date}-${rand}`;
}

// Place offline order (Farm visitors)
router.post('/place-offline-order', auth, adminOnly, async (req, res) => {
    try {
        const { trayCount, customerName, customerPhone, paymentMethod } = req.body;

        if (!trayCount || trayCount < 1) {
            return res.status(400).json({ success: false, message: 'Minimum 1 tray required' });
        }

        if (!customerName || !customerPhone) {
            return res.status(400).json({ success: false, message: 'Customer name and phone are required' });
        }

        // ── Stock check ──
        const today = new Date().toISOString().split('T')[0];
        const stock = await DailyStock.findOne({ where: { date: today } });

        if (!stock || stock.totalTrays === 0) {
            return res.status(400).json({
                success: false,
                message: 'No stock available for today. Please set the stock limit first.',
                availableTrays: 0,
            });
        }

        const remaining = stock.totalTrays - stock.soldTrays;
        if (trayCount > remaining) {
            return res.status(400).json({
                success: false,
                message: remaining > 0
                    ? `Only ${remaining} tray(s) available today. Please reduce the count.`
                    : 'All stock for today has been sold out!',
                availableTrays: remaining,
            });
        }

        // Get current price (Use admin's district or a default one if needed)
        let price = await EggPrice.findOne({
            where: { district: req.user.district, priceDate: today },
        });

        if (!price) {
            price = await EggPrice.findOne({
                where: { district: req.user.district },
                order: [['price_date', 'DESC']],
            });
        }

        if (!price) {
            return res.status(400).json({
                success: false,
                message: 'No egg price available. Please set the egg price first.',
            });
        }

        const pricePerTray = parseFloat(price.pricePerTray);
        const totalAmount = pricePerTray * trayCount;

        const order = await Order.create({
            orderNumber: generateOrderNumber(),
            userId: null,
            customerName,
            customerPhone,
            trayCount,
            pricePerTray,
            totalAmount,
            paymentMethod: paymentMethod || 'cash',
            paymentStatus: paymentMethod === 'pay_later' ? 'pending' : 'completed',
            orderStatus: 'delivered', // Handed over at the farm
            isOffline: true,
            paidAt: paymentMethod === 'pay_later' ? null : new Date(),
        });

        // ── Update sold count ──
        await stock.increment('soldTrays', { by: trayCount });
        await stock.reload();

        const newRemaining = stock.totalTrays - stock.soldTrays;

        // ── Admin notifications ──
        const adminUsers = await User.findAll({ where: { role: 'admin' } });

        if (newRemaining <= 50 && newRemaining > 0 && !stock.lowStockNotified) {
            for (const admin of adminUsers) {
                await Notification.create({
                    userId: admin.id,
                    title: '⚠️ Low Stock Alert (Offline Order)',
                    message: `Only ${newRemaining} tray(s) left today after an offline order!`,
                    type: 'stock_alert',
                    metadata: { remainingTrays: newRemaining, date: today },
                });
            }
            await stock.update({ lowStockNotified: true });
        }

        if (newRemaining === 0 && !stock.outOfStockNotified) {
            for (const admin of adminUsers) {
                await Notification.create({
                    userId: admin.id,
                    title: '🚨 Stock Depleted! (Offline Order)',
                    message: `All ${stock.totalTrays} trays for today have been sold (including offline orders)!`,
                    type: 'stock_alert',
                    metadata: { totalSold: stock.soldTrays, date: today },
                });
            }
            await stock.update({ outOfStockNotified: true });
        }

        res.status(201).json({
            success: true,
            message: 'Offline order recorded successfully',
            data: order,
        });
    } catch (error) {
        console.error('Place offline order error:', error);
        res.status(500).json({ success: false, message: 'Failed to record offline order' });
    }
});

module.exports = router;
