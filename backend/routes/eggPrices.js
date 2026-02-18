const express = require('express');
const { Op } = require('sequelize');
const { EggPrice } = require('../models');
const auth = require('../middleware/auth');
const adminOnly = require('../middleware/adminOnly');

const router = express.Router();

// Get current egg price for user's district
router.get('/current', auth, async (req, res) => {
    try {
        const district = req.query.district || req.user.district;
        const today = new Date().toISOString().split('T')[0];

        // Try today's price first, then most recent
        let price = await EggPrice.findOne({
            where: { district, priceDate: today },
            order: [['created_at', 'DESC']],
        });

        if (!price) {
            price = await EggPrice.findOne({
                where: { district },
                order: [['price_date', 'DESC']],
            });
        }

        if (!price) {
            return res.status(404).json({
                success: false,
                message: 'No egg price set for your district yet',
            });
        }

        res.json({
            success: true,
            data: {
                district: price.district,
                pricePerEgg: parseFloat(price.pricePerEgg),
                pricePerTray: parseFloat(price.pricePerTray),
                priceDate: price.priceDate,
                isToday: price.priceDate === today,
            },
        });
    } catch (error) {
        console.error('Get price error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch egg price' });
    }
});

// Admin: Set egg price for a district
router.post('/set', auth, adminOnly, async (req, res) => {
    try {
        const { district, pricePerEgg, pricePerTray, priceDate } = req.body;
        const date = priceDate || new Date().toISOString().split('T')[0];
        const trayPrice = pricePerTray || pricePerEgg * 30;

        // Delete any existing price for this district+date, then create fresh
        await EggPrice.destroy({
            where: { district, priceDate: date },
        });

        const price = await EggPrice.create({
            district,
            pricePerEgg,
            pricePerTray: trayPrice,
            priceDate: date,
            setBy: req.user.id,
        });

        res.status(201).json({
            success: true,
            message: 'Price set successfully',
            data: price,
        });
    } catch (error) {
        console.error('Set price error:', error);
        res.status(500).json({ success: false, message: 'Failed to set egg price' });
    }
});

// Admin: Get price history
router.get('/history', auth, adminOnly, async (req, res) => {
    try {
        const { district } = req.query;
        const where = district ? { district } : {};

        const prices = await EggPrice.findAll({
            where,
            order: [['price_date', 'DESC']],
            limit: 30,
        });

        res.json({ success: true, data: prices });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to fetch price history' });
    }
});

module.exports = router;
