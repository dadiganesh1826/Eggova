/**
 * Seed Script — Creates an admin user, a test user, and sample egg prices
 * Run: node seed.js
 */
require('dotenv').config();
const { sequelize, User, EggPrice } = require('./models');

async function seed() {
    try {
        await sequelize.authenticate();
        await sequelize.sync({ force: true }); // Reset DB for fresh seed
        console.log('✅ Database synced\n');

        // 1. Create Admin
        const admin = await User.create({
            name: 'Farm Admin',
            email: 'admin@eggova.com',
            phone: '9999999999',
            passwordHash: 'admin123',
            address: 'Eggova Farm, Main Road',
            district: 'Guntur',
            state: 'Andhra Pradesh',
            pincode: '522001',
            role: 'admin',
        });
        console.log('👤 Admin created:');
        console.log('   Email: admin@eggova.com');
        console.log('   Password: admin123\n');

        // 2. Create Test User
        const user = await User.create({
            name: 'Ravi Kumar',
            email: 'ravi@test.com',
            phone: '9876543210',
            passwordHash: 'user123',
            address: '123 Market Street',
            district: 'Guntur',
            state: 'Andhra Pradesh',
            pincode: '522002',
            role: 'user',
        });
        console.log('👤 Test user created:');
        console.log('   Email: ravi@test.com');
        console.log('   Password: user123\n');

        // 3. Set today's egg price
        const today = new Date().toISOString().split('T')[0];
        await EggPrice.create({
            district: 'Guntur',
            pricePerEgg: 6.50,
            pricePerTray: 195.00,
            priceDate: today,
            setBy: admin.id,
        });
        console.log('🥚 Egg price set for Guntur:');
        console.log('   ₹6.50 per egg | ₹195.00 per tray');
        console.log(`   Date: ${today}\n`);

        console.log('═══════════════════════════════════════');
        console.log('  ✅ Seed complete! You can now login');
        console.log('  Admin: admin@eggova.com / admin123');
        console.log('  User:  ravi@test.com / user123');
        console.log('═══════════════════════════════════════');

        process.exit(0);
    } catch (error) {
        console.error('❌ Seed failed:', error);
        process.exit(1);
    }
}

seed();
