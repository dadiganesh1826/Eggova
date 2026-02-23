const express = require('express');
const crypto = require('crypto');
const { Order, User, Notification } = require('../models');
const auth = require('../middleware/auth');
const adminOnly = require('../middleware/adminOnly');
const razorpay = require('../config/razorpay');

const router = express.Router();

// Create Razorpay order
router.post('/create-razorpay', auth, async (req, res) => {
    try {
        const { orderId } = req.body;

        const order = await Order.findOne({
            where: { id: orderId, userId: req.user.id },
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        const razorpayOrder = await razorpay.orders.create({
            amount: Math.round(parseFloat(order.totalAmount) * 100), // paise
            currency: 'INR',
            receipt: order.orderNumber,
            notes: {
                orderId: order.id,
                userId: req.user.id,
            },
        });

        await order.update({ razorpayOrderId: razorpayOrder.id });

        res.json({
            success: true,
            data: {
                razorpayOrderId: razorpayOrder.id,
                amount: razorpayOrder.amount,
                currency: razorpayOrder.currency,
                keyId: process.env.RAZORPAY_KEY_ID,
            },
        });
    } catch (error) {
        console.error('Create Razorpay order error:', error);
        res.status(500).json({ success: false, message: 'Failed to create payment' });
    }
});

// Verify Razorpay payment
router.post('/verify', auth, async (req, res) => {
    try {
        const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body;

        // Verify signature
        const body = razorpayOrderId + '|' + razorpayPaymentId;
        const expectedSignature = crypto
            .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
            .update(body)
            .digest('hex');

        if (expectedSignature !== razorpaySignature) {
            return res.status(400).json({ success: false, message: 'Invalid payment signature' });
        }

        const order = await Order.findOne({
            where: { razorpayOrderId, userId: req.user.id },
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        await order.update({
            razorpayPaymentId,
            paymentStatus: 'completed',
            orderStatus: 'confirmed',
            paidAt: new Date(),
            paidVia: 'upi', // Standardizing as 'upi' for Razorpay in this context
        });

        // Notify Admins about the receipt
        const admins = await User.findAll({ where: { role: 'admin' } });
        for (const admin of admins) {
            await Notification.create({
                userId: admin.id,
                title: 'Payment Received! 💰',
                message: `Online payment of ₹${order.totalAmount} received from ${req.user.name} for order ${order.orderNumber}`,
                type: 'payment_received',
                metadata: { orderId: order.id, amount: order.totalAmount, paidVia: 'upi' },
            });
        }

        res.json({
            success: true,
            message: 'Payment verified and confirmed successfully',
            data: order,
        });
    } catch (error) {
        console.error('Verify payment error:', error);
        res.status(500).json({ success: false, message: 'Payment verification failed' });
    }
});

// User: Request payment completion (for pay-later orders)
router.post('/request-completion', auth, async (req, res) => {
    try {
        const { orderId, paidVia } = req.body;

        const order = await Order.findOne({
            where: { id: orderId, userId: req.user.id, paymentStatus: 'pending' },
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Pending order not found' });
        }

        await order.update({ paymentStatus: 'approval_pending', paidVia: paidVia || 'cash' });

        // Notify admin(s)
        const admins = await User.findAll({ where: { role: 'admin' } });
        for (const admin of admins) {
            await Notification.create({
                userId: admin.id,
                title: 'Payment Completion Request',
                message: `${req.user.name} claims to have paid ₹${order.totalAmount} for order ${order.orderNumber}`,
                type: 'payment_request',
                metadata: { orderId: order.id, userName: req.user.name, amount: order.totalAmount },
            });
        }

        res.json({
            success: true,
            message: 'Payment completion request sent to admin',
        });
    } catch (error) {
        console.error('Request completion error:', error);
        res.status(500).json({ success: false, message: 'Failed to request payment completion' });
    }
});

// Admin: Mark payment as completed
router.post('/mark-paid', auth, adminOnly, async (req, res) => {
    try {
        const { orderId, paidVia } = req.body;

        const order = await Order.findOne({
            where: { id: orderId },
            include: [{ model: User, as: 'user', required: false }],
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        await order.update({
            paymentStatus: 'completed',
            orderStatus: 'confirmed',
            paidAt: new Date(),
            paidVia: paidVia || 'cash',
        });

        // Notify user (if app user)
        if (order.userId) {
            await Notification.create({
                userId: order.userId,
                title: 'Payment Confirmed',
                message: `Your payment of ₹${order.totalAmount} for order ${order.orderNumber} has been confirmed by admin`,
                type: 'payment_approved',
                metadata: { orderId: order.id },
            });
        }

        res.json({
            success: true,
            message: 'Payment marked as completed',
            data: order,
        });
    } catch (error) {
        console.error('Mark paid error:', error);
        res.status(500).json({ success: false, message: 'Failed to mark payment' });
    }
});

module.exports = router;
