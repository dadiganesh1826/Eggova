const express = require('express');
const { Order, User, EggPrice } = require('../models');
const auth = require('../middleware/auth');

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

        // Get current price
        const today = new Date().toISOString().split('T')[0];
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
                message: 'No egg price available for your district',
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
