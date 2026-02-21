const express = require('express');
const jwt = require('jsonwebtoken');
const { User } = require('../models');
const auth = require('../middleware/auth');

const router = express.Router();

// In-memory OTP store: { phone: { otp, expiresAt } }
const otpStore = {};
// Verified phones waiting for profile completion: { phone: expiresAt }
const verifiedPhones = {};

// District-to-State mapping (egg price districts only)
const DISTRICT_STATE_MAP = {
    'Chittoor': 'Andhra Pradesh',
    'East Godavari': 'Andhra Pradesh',
    'Vijayawada': 'Andhra Pradesh',
    'Vizag': 'Andhra Pradesh',
    'West Godavari': 'Andhra Pradesh',
    'Hyderabad': 'Telangana',
    'Warangal': 'Telangana',
};

// Send OTP
router.post('/send-otp', async (req, res) => {
    try {
        const { phone } = req.body;

        if (!phone || phone.length < 10) {
            return res.status(400).json({ success: false, message: 'Valid phone number is required' });
        }

        // Generate OTP (fixed 1234 for development)
        const otp = '1234';
        otpStore[phone] = {
            otp,
            expiresAt: Date.now() + 5 * 60 * 1000, // 5 minutes
        };

        console.log(`📱 OTP for ${phone}: ${otp}`);

        // Check if user already exists
        const existingUser = await User.findOne({ where: { phone } });

        res.json({
            success: true,
            message: 'OTP sent successfully',
            data: { isExistingUser: !!existingUser },
        });
    } catch (error) {
        console.error('Send OTP error:', error);
        res.status(500).json({ success: false, message: 'Failed to send OTP' });
    }
});

// Verify OTP & Login/Register
router.post('/verify-otp', async (req, res) => {
    try {
        const { phone, otp, name, district } = req.body;

        // Validate OTP — or check if phone was already verified (for profile completion)
        const stored = otpStore[phone];
        const alreadyVerified = verifiedPhones[phone] && Date.now() < verifiedPhones[phone];

        if (!stored && !alreadyVerified) {
            return res.status(400).json({ success: false, message: 'OTP not found. Please request a new one.' });
        }

        if (stored) {
            if (Date.now() > stored.expiresAt) {
                delete otpStore[phone];
                return res.status(400).json({ success: false, message: 'OTP expired. Please request a new one.' });
            }
            if (stored.otp !== otp) {
                return res.status(400).json({ success: false, message: 'Invalid OTP' });
            }
            // OTP verified — clean up
            delete otpStore[phone];
        }

        // Check if user exists
        let user = await User.findOne({ where: { phone } });

        if (user) {
            // Existing user — login
            delete verifiedPhones[phone];
            const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
                expiresIn: process.env.JWT_EXPIRES_IN || '7d',
            });

            return res.json({
                success: true,
                message: 'Login successful',
                data: { user: user.toSafeJSON(), token, isNewUser: false },
            });
        }

        // New user — need name and district
        if (!name || !district) {
            // Mark phone as verified for 10 minutes (for profile completion screen)
            verifiedPhones[phone] = Date.now() + 10 * 60 * 1000;
            return res.json({
                success: true,
                message: 'OTP verified. Please complete your profile.',
                data: { isNewUser: true, otpVerified: true },
            });
        }

        // Determine state from district
        const state = DISTRICT_STATE_MAP[district] || 'Andhra Pradesh';

        // Create new user
        user = await User.create({
            name,
            phone,
            district,
            state,
        });

        // Clean up verified phone
        delete verifiedPhones[phone];

        const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
            expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        });

        res.status(201).json({
            success: true,
            message: 'Account created successfully',
            data: { user: user.toSafeJSON(), token, isNewUser: true },
        });
    } catch (error) {
        console.error('Verify OTP error:', error);
        res.status(500).json({ success: false, message: 'Verification failed' });
    }
});

// Legacy login (kept for admin access)
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
        const { name, phone, email, address, district, state, pincode } = req.body;

        // Auto-map state from district if district changed
        let resolvedState = state;
        if (district && DISTRICT_STATE_MAP[district]) {
            resolvedState = DISTRICT_STATE_MAP[district];
        }

        await req.user.update({
            name, phone, email, address, district,
            state: resolvedState || req.user.state,
            pincode,
        });
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

// Get available districts
router.get('/districts', (req, res) => {
    const districts = Object.entries(DISTRICT_STATE_MAP).map(([district, state]) => ({
        district,
        state,
        label: `${district}, ${state}`,
    }));
    res.json({ success: true, data: districts });
});

module.exports = router;
