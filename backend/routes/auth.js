const express = require('express');
const jwt = require('jsonwebtoken');
const { User } = require('../models');
const auth = require('../middleware/auth');

const router = express.Router();

// Register
router.post('/register', async (req, res) => {
    try {
        const { name, email, phone, password, address, district, state, pincode } = req.body;

        // Check existing
        const existingUser = await User.findOne({ where: { email } });
        if (existingUser) {
            return res.status(400).json({ success: false, message: 'Email already registered' });
        }

        const existingPhone = await User.findOne({ where: { phone } });
        if (existingPhone) {
            return res.status(400).json({ success: false, message: 'Phone number already registered' });
        }

        const user = await User.create({
            name,
            email,
            phone,
            passwordHash: password,
            address,
            district,
            state: state || 'Andhra Pradesh',
            pincode,
        });

        const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
            expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        });

        res.status(201).json({
            success: true,
            message: 'Registration successful',
            data: { user: user.toSafeJSON(), token },
        });
    } catch (error) {
        console.error('Register error:', error);
        res.status(500).json({ success: false, message: 'Registration failed' });
    }
});

// Login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        const user = await User.findOne({ where: { email } });
        if (!user) {
            return res.status(401).json({ success: false, message: 'Invalid credentials' });
        }

        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
            return res.status(401).json({ success: false, message: 'Invalid credentials' });
        }

        const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
            expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        });

        res.json({
            success: true,
            message: 'Login successful',
            data: { user: user.toSafeJSON(), token },
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ success: false, message: 'Login failed' });
    }
});

// Get profile
router.get('/profile', auth, async (req, res) => {
    res.json({ success: true, data: { user: req.user.toSafeJSON() } });
});

// Update profile
router.put('/profile', auth, async (req, res) => {
    try {
        const { name, phone, address, district, state, pincode } = req.body;
        await req.user.update({ name, phone, address, district, state, pincode });
        res.json({ success: true, data: { user: req.user.toSafeJSON() } });
    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ success: false, message: 'Profile update failed' });
    }
});

// Update FCM token
router.put('/fcm-token', auth, async (req, res) => {
    try {
        const { fcmToken } = req.body;
        await req.user.update({ fcmToken });
        res.json({ success: true, message: 'FCM token updated' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to update FCM token' });
    }
});

module.exports = router;
