const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { User } = require('../models');
const auth = require('../middleware/auth');
const admin = require('../config/firebase-admin');

const router = express.Router();

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

function generateToken(userId) {
    return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });
}

// ─── Google Sign-In ──────────────────────────────────────────────────────────
router.post('/google', async (req, res) => {
    try {
        const { idToken } = req.body;
        if (!idToken) return res.status(400).json({ success: false, message: 'Google ID token required' });

        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const { email, name, picture } = decodedToken;

        let user = await User.findOne({ where: { email } });

        if (!user) {
            // New Google user, requires additional details (phone & district)
            return res.json({
                success: true,
                message: 'Additional details required',
                data: { requires_details: true, email, name }
            });
        }

        if (user.status === 'pending') {
            return res.json({
                success: true,
                message: 'Account pending admin approval',
                data: { status: 'pending' }
            });
        }

        if (user.status === 'rejected') {
            return res.status(403).json({ success: false, message: 'Your account has been rejected. Contact admin.' });
        }

        // User is approved. Issue our own JWT token for them.
        const token = generateToken(user.id);
        res.json({
            success: true,
            message: 'Login successful',
            data: { user: user.toSafeJSON(), token, isNewUser: false }
        });
    } catch (error) {
        console.error('Google login error:', error);
        res.status(500).json({ success: false, message: 'Google Sign-In failed' });
    }
});

// ─── Check Phone ─────────────────────────────────────────────────────────────
// Returns { isExistingUser: bool } so the app knows whether to show
// Login form or Registration form.
router.post('/check-phone', async (req, res) => {
    try {
        const { phone } = req.body;
        if (!phone || String(phone).length < 10) {
            return res.status(400).json({ success: false, message: 'Valid 10-digit phone number is required' });
        }
        const user = await User.findOne({ where: { phone } });
        res.json({ success: true, data: { isExistingUser: !!user } });
    } catch (error) {
        console.error('Check phone error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

const { sendPushToMany } = require('../services/push');

// ─── Register Details (After Google Sign-in for New Users) ────────────────
router.post('/register-details', async (req, res) => {
    try {
        const { idToken, phone, district } = req.body;

        if (!idToken || !phone || !district) {
            return res.status(400).json({ success: false, message: 'Google Token, phone, and district are required' });
        }
        if (String(phone).length < 10) {
            return res.status(400).json({ success: false, message: 'Valid 10-digit phone number is required' });
        }

        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const { email, name } = decodedToken;

        let user = await User.findOne({ where: { phone } });

        if (user) {
            if (user.email && user.email !== email) {
                return res.status(409).json({ success: false, message: 'This mobile number is already linked to a different Google account.' });
            }
            // Link legacy account
            user.email = email;
            await user.save();
            const token = generateToken(user.id);
            return res.status(200).json({
                success: true,
                message: 'Account linked successfully',
                data: { user: user.toSafeJSON(), token, isNewUser: false }
            });
        }

        const existingEmail = await User.findOne({ where: { email } });
        if (existingEmail) {
            return res.status(409).json({ success: false, message: 'An account with this email already exists but with a different phone number.' });
        }

        const state = DISTRICT_STATE_MAP[district] || 'Andhra Pradesh';
        user = await User.create({ name, email, phone, district, state, status: 'pending' });

        // Notify Admins
        try {
            const admins = await User.findAll({ where: { role: 'admin' } });
            const adminTokens = admins.map(a => a.fcmToken).filter(Boolean);
            if (adminTokens.length > 0) {
                await sendPushToMany(
                    adminTokens,
                    'New User Approval Required',
                    `${name} (${phone}) has registered and is waiting for your approval.`,
                    { type: 'pending_approval', userId: user.id }
                );
            }
        } catch (pushErr) {
            console.error('Failed to notify admins:', pushErr);
        }

        res.status(201).json({
            success: true,
            message: 'Details submitted successfully. Waiting for Admin approval.',
            data: { status: 'pending' },
        });
    } catch (error) {
        console.error('Register details error:', error);
        res.status(500).json({ success: false, message: 'Submission failed' });
    }
});

// ─── User Login (Mobile + Password) ──────────────────────────────────────────
router.post('/user-login', async (req, res) => {
    try {
        const { phone, password } = req.body;

        if (!phone || !password) {
            return res.status(400).json({ success: false, message: 'Phone and password are required' });
        }

        const user = await User.findOne({ where: { phone } });
        if (!user) {
            return res.status(401).json({ success: false, message: 'No account found with this mobile number' });
        }

        if (!user.passwordHash) {
            return res.status(401).json({ success: false, message: 'This account has no password set. Please contact admin.' });
        }

        const isMatch = await bcrypt.compare(password, user.passwordHash);
        if (!isMatch) {
            return res.status(401).json({ success: false, message: 'Incorrect password' });
        }

        const token = generateToken(user.id);
        res.json({
            success: true,
            message: 'Login successful',
            data: { user: user.toSafeJSON(), token, isNewUser: false },
        });
    } catch (error) {
        console.error('User login error:', error);
        res.status(500).json({ success: false, message: 'Login failed' });
    }
});

// ─── Forgot Password (for existing users to set a new password) ─────────────
router.post('/forgot-password', async (req, res) => {
    try {
        const { phone, newPassword } = req.body;

        if (!phone || !newPassword) {
            return res.status(400).json({ success: false, message: 'Phone and new password are required' });
        }
        if (newPassword.length < 6) {
            return res.status(400).json({ success: false, message: 'New password must be at least 6 characters' });
        }

        const user = await User.findOne({ where: { phone } });
        if (!user) {
            return res.status(404).json({ success: false, message: 'No account found with this mobile number' });
        }

        const passwordHash = await bcrypt.hash(newPassword, 12);
        await user.update({ passwordHash });

        res.json({ success: true, message: 'Password reset successfully' });
    } catch (error) {
        console.error('Forgot password error:', error);
        res.status(500).json({ success: false, message: 'Failed to reset password' });
    }
});

// ─── Admin Login (Email + Password) ──────────────────────────────────────────
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

        const token = generateToken(user.id);
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

// ─── Get Profile ──────────────────────────────────────────────────────────────
router.get('/profile', auth, async (req, res) => {
    res.json({ success: true, data: { user: req.user.toSafeJSON() } });
});

// ─── Update Profile ───────────────────────────────────────────────────────────
router.put('/profile', auth, async (req, res) => {
    try {
        const { name, phone, email, address, district, state, pincode } = req.body;

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

// ─── Change Password ──────────────────────────────────────────────────────────
router.put('/change-password', auth, async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;

        if (!currentPassword || !newPassword) {
            return res.status(400).json({ success: false, message: 'Current and new password are required' });
        }
        if (newPassword.length < 6) {
            return res.status(400).json({ success: false, message: 'New password must be at least 6 characters' });
        }

        if (req.user.passwordHash) {
            const isMatch = await bcrypt.compare(currentPassword, req.user.passwordHash);
            if (!isMatch) {
                return res.status(401).json({ success: false, message: 'Current password is incorrect' });
            }
        }

        const passwordHash = await bcrypt.hash(newPassword, 12);
        await req.user.update({ passwordHash });
        res.json({ success: true, message: 'Password changed successfully' });
    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ success: false, message: 'Failed to change password' });
    }
});

// ─── Update FCM Token ─────────────────────────────────────────────────────────
router.put('/fcm-token', auth, async (req, res) => {
    try {
        const { fcmToken } = req.body;
        await req.user.update({ fcmToken });
        res.json({ success: true, message: 'FCM token updated' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Failed to update FCM token' });
    }
});

// ─── Get Districts ────────────────────────────────────────────────────────────
router.get('/districts', (req, res) => {
    const districts = Object.entries(DISTRICT_STATE_MAP).map(([district, state]) => ({
        district,
        state,
        label: `${district}, ${state}`,
    }));
    res.json({ success: true, data: districts });
});

// ─── Request Phone Update ──────────────────────────────────────────────────
router.post('/request-phone-update', auth, async (req, res) => {
    try {
        const { newPhone } = req.body;
        if (!newPhone || String(newPhone).length < 10) {
            return res.status(400).json({ success: false, message: 'Valid 10-digit phone number is required' });
        }

        // Notify Admins
        try {
            const admins = await User.findAll({ where: { role: 'admin' } });
            const adminTokens = admins.map(a => a.fcmToken).filter(Boolean);
            if (adminTokens.length > 0) {
                await sendPushToMany(
                    adminTokens,
                    'Phone Update Request',
                    `${req.user.name} has requested to update their phone number to ${newPhone}.`,
                    { type: 'phone_update_request', userId: req.user.id, newPhone }
                );
            }
        } catch (pushErr) {
            console.error('Failed to notify admins of phone update:', pushErr);
        }

        res.json({ success: true, message: 'Your request for phone number update has been sent to admin for approval.' });
    } catch (error) {
        console.error('Phone update request error:', error);
        res.status(500).json({ success: false, message: 'Failed to send request' });
    }
});

module.exports = router;
