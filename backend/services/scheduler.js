const cron = require('node-cron');
const { scrapeNeccRates } = require('./scraper');
const { EggPrice, User } = require('../models');

/**
 * Initializes the daily egg rate scraper.
 * Scheduled to run every day at 06:00 AM.
 * (Cron format: minute hour dayOfMonth month dayOfWeek)
 */
function initScheduler() {
    console.log('📅 Egg Rate Scheduler Initialized: 06:00 AM Daily Task Running...');

    // Runs every day at 06:00 (6 AM)
    cron.schedule('0 6 * * *', async () => {
        console.log('⏰ Standardized Daily Auto-Fetch Triggered: Syncing full monthly grid...');
        try {
            const now = new Date();
            const currentYear = now.getFullYear();
            const currentMonth = now.getMonth(); // 0-indexed

            // Get a default admin for the set_by field
            const admin = await User.findOne({ where: { role: 'admin' } });
            const adminId = admin ? admin.id : null;

            if (!adminId) {
                console.error('❌ Scheduler Error: No admin user found to attribute auto-fetch to.');
                return;
            }

            const scrapedRates = await scrapeNeccRates(); // { district: { day: price } }
            const ALL_DISTRICTS = ['Chittoor', 'East Godavari', 'Vijayawada', 'Vizag', 'West Godavari', 'Hyderabad', 'Warangal'];

            let totalRecordCount = 0;
            for (const district of ALL_DISTRICTS) {
                const dailyData = scrapedRates[district];
                if (dailyData) {
                    for (const [day, pricePerEgg] of Object.entries(dailyData)) {
                        const dateStr = `${currentYear}-${(currentMonth + 1).toString().padStart(2, '0')}-${day.padStart(2, '0')}`;
                        const pricePerTray = Math.round(pricePerEgg * 30);

                        await EggPrice.destroy({ where: { district, priceDate: dateStr } });
                        await EggPrice.create({
                            district,
                            pricePerEgg: parseFloat(pricePerEgg.toFixed(2)),
                            pricePerTray,
                            priceDate: dateStr,
                            setBy: adminId
                        });
                        totalRecordCount++;
                    }
                }
            }

            console.log(`✅ Daily Auto-Fetch Successful: Updated ${totalRecordCount} historical records across districts.`);
        } catch (error) {
            console.error('❌ Daily Auto-Fetch Error:', error.message);
        }
    }, {
        scheduled: true,
        timezone: "Asia/Kolkata" // Ensuring it runs on Indian time
    });
}

/**
 * Manually trigger the auto-fetch (can be used for testing or on-demand via internal logs)
 */
async function triggerImmediateFetch() {
    console.log('🚀 Manually triggering immediate NECC rate sync...');
    // This logic is identical to what's in the cron job, 
    // but the route eggPrices.js already handles this for the 'magic button'.
}

module.exports = { initScheduler };
