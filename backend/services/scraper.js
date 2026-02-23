const axios = require('axios');
const cheerio = require('cheerio');

const SOURCE_URL = 'https://e2necc.com/home/eggprice';

const DISTRICT_MAPPING = {
    'Chittoor': ['Chittoor'],
    'East Godavari': ['E.Godavari'],
    'Vijayawada': ['Vijayawada'],
    'Vizag': ['Vizag'],
    'West Godavari': ['W.Godavari'],
    'Hyderabad': ['Hyderabad'],
    'Warangal': ['Warangal']
};

/**
 * Scrapes all available days for the current month from official e2necc.com.
 * @returns {Promise<Object>} Object with { district: { day: price } } structure.
 */
async function scrapeNeccRates() {
    try {
        const response = await axios.get(SOURCE_URL, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            timeout: 15000
        });

        const $ = cheerio.load(response.data);
        const allRates = {};

        $('table tr').each((_, row) => {
            const cells = $(row).find('td').map((_, cell) => $(cell).text().trim()).get();
            if (cells.length > 2) {
                const cityName = cells[0];

                // Identify which district this row belongs to
                let matchedDistrict = null;
                for (const [district, keywords] of Object.entries(DISTRICT_MAPPING)) {
                    for (const keyword of keywords) {
                        if (cityName === keyword) {
                            matchedDistrict = district;
                            break;
                        }
                    }
                    if (matchedDistrict) break;
                }

                if (matchedDistrict) {
                    const monthlyData = {};
                    // Day 1 starts at index 1, Day 31 max index is index 31
                    for (let day = 1; day < cells.length; day++) {
                        const rateStr = cells[day];
                        if (rateStr && rateStr !== '-' && rateStr !== '') {
                            const pricePer100 = parseFloat(rateStr.replace(/[^\d.]/g, ''));
                            if (!isNaN(pricePer100)) {
                                monthlyData[day] = pricePer100 / 100;
                            }
                        }
                    }
                    allRates[matchedDistrict] = monthlyData;
                }
            }
        });

        return allRates;
    } catch (error) {
        console.error('Official NECC Scraping error:', error.message);
        throw new Error('Failed to fetch official NECC rates: ' + error.message);
    }
}

module.exports = { scrapeNeccRates };
