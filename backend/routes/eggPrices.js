const express = require('express');
const { Op } = require('sequelize');
const { EggPrice, DailyStock, User, Notification } = require('../models');
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

// Admin: Get today's prices for ALL districts
const ALL_DISTRICTS = ['Chittoor', 'East Godavari', 'Vijayawada', 'Vizag', 'West Godavari', 'Hyderabad', 'Warangal'];

router.get('/today-all', auth, adminOnly, async (req, res) => {
    try {
        const today = new Date().toISOString().split('T')[0];

        const prices = await EggPrice.findAll({
            where: { priceDate: today },
            order: [['district', 'ASC']],
        });

        const priceMap = {};
        prices.forEach(p => {
            priceMap[p.district] = {
                id: p.id,
                district: p.district,
                pricePerEgg: parseFloat(p.pricePerEgg),
                pricePerTray: parseFloat(p.pricePerTray),
                priceDate: p.priceDate,
            };
        });

        const result = ALL_DISTRICTS.map(d => priceMap[d] || {
            id: null,
            district: d,
            pricePerEgg: null,
            pricePerTray: null,
            priceDate: today,
        });

        res.json({ success: true, data: result, date: today });
    } catch (error) {
        console.error('Today-all prices error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch prices' });
    }
});

// ─── STOCK MANAGEMENT ────────────────────────────────────

// Admin: Set / update daily stock limit
router.post('/set-stock', auth, adminOnly, async (req, res) => {
    try {
        const { totalTrays, date } = req.body;
        const stockDate = date || new Date().toISOString().split('T')[0];

        if (!totalTrays || totalTrays < 0) {
            return res.status(400).json({ success: false, message: 'Please provide a valid tray count' });
        }

        let stock = await DailyStock.findOne({ where: { date: stockDate } });

        let message = stock ? 'Stock limit updated' : 'Stock limit set';
        if (stock) {
            // Don't allow setting below already-sold count
            if (totalTrays < stock.soldTrays) {
                return res.status(400).json({
                    success: false,
                    message: `Cannot set below ${stock.soldTrays} (already sold). Increase to at least ${stock.soldTrays}.`,
                });
            }
            if (totalTrays > stock.totalTrays) {
                message = `Stock limit increased to ${totalTrays} trays`;
            } else if (totalTrays < stock.totalTrays) {
                message = `Stock limit reduced to ${totalTrays} trays`;
            }
            await stock.update({ totalTrays, setBy: req.user.id });
        } else {
            stock = await DailyStock.create({
                date: stockDate,
                totalTrays,
                soldTrays: 0,
                setBy: req.user.id,
            });
            message = `Daily stock limit set to ${totalTrays} trays`;
        }

        res.json({
            success: true,
            message,
            data: {
                date: stock.date,
                totalTrays: stock.totalTrays,
                soldTrays: stock.soldTrays,
                remainingTrays: stock.totalTrays - stock.soldTrays,
                isSet: true,
            },
        });
    } catch (error) {
        console.error('Set stock error:', error);
        res.status(500).json({ success: false, message: 'Failed to set stock' });
    }
});

// Get today's stock info (available to all authenticated users)
router.get('/stock-today', auth, async (req, res) => {
    try {
        const today = new Date().toISOString().split('T')[0];
        const stock = await DailyStock.findOne({ where: { date: today } });

        if (!stock) {
            return res.json({
                success: true,
                data: {
                    date: today,
                    totalTrays: 0,
                    soldTrays: 0,
                    remainingTrays: 0,
                    isSet: false,
                },
            });
        }

        res.json({
            success: true,
            data: {
                date: stock.date,
                totalTrays: stock.totalTrays,
                soldTrays: stock.soldTrays,
                remainingTrays: stock.totalTrays - stock.soldTrays,
                isSet: true,
            },
        });
    } catch (error) {
        console.error('Get stock error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch stock' });
    }
});

module.exports = router;
