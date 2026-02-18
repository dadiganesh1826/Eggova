const express = require('express');
const { Op } = require('sequelize');
const { User, Order, Notification } = require('../models');
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

module.exports = router;
