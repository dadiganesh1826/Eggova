require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { sequelize } = require('./models');
const { initScheduler } = require('./services/scheduler');

const authRoutes = require('./routes/auth');
const eggPriceRoutes = require('./routes/eggPrices');
const orderRoutes = require('./routes/orders');
const paymentRoutes = require('./routes/payments');
const adminRoutes = require('./routes/admin');
const notificationRoutes = require('./routes/notifications');
const webhookRoutes = require('./routes/webhooks');

const app = express();

// Middleware
app.use(cors());
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/egg-prices', eggPriceRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/webhooks', webhookRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');
    await sequelize.sync();
    console.log('✅ Models synchronized');

    // Auto-sync Admin Credentials from .env
    const { User } = require('./models');
    const bcrypt = require('bcryptjs');
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@eggova.com';
    const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';

    const [admin, created] = await User.findOrCreate({
      where: { role: 'admin' },
      defaults: {
        name: 'Admin Superuser',
        email: adminEmail,
        phone: '0000000000',
        passwordHash: await bcrypt.hash(adminPassword, 10),
        role: 'admin',
        district: 'Admin District',
        state: 'Admin State'
      }
    });

    if (!created && (admin.email !== adminEmail || !await bcrypt.compare(adminPassword, admin.passwordHash))) {
      await admin.update({
        email: adminEmail,
        passwordHash: await bcrypt.hash(adminPassword, 10)
      });
      console.log('✅ Admin credentials updated from .env');
    } else if (created) {
      console.log('✅ Default Admin created from .env');
    }

    // Initialize Daily Egg Rate Scheduler (Runs at 6 AM IST)
    initScheduler();

    app.listen(PORT, () => {
      console.log(`🚀 Eggova API running on port ${PORT}`);
    });
  } catch (error) {
    console.error('❌ Unable to start server:', error);
    process.exit(1);
  }
}

start();
