const { Sequelize } = require('sequelize');
const path = require('path');

let sequelize;

if (process.env.DATABASE_URL) {
    // ── Production: PostgreSQL via DATABASE_URL ─────────────────────────────
    sequelize = new Sequelize(process.env.DATABASE_URL, {
        dialect: 'postgres',
        logging: false,
        dialectOptions: {
            ssl: process.env.DB_SSL === 'true'
                ? { require: true, rejectUnauthorized: false }
                : false,
        },
        pool: {
            max: 10,
            min: 0,
            acquire: 30000,
            idle: 10000,
        },
    });
} else {
    // ── Development: SQLite (file-based, zero setup) ────────────────────────
    const dbPath = path.join(__dirname, '..', 'eggova.sqlite');
    sequelize = new Sequelize({
        dialect: 'sqlite',
        storage: dbPath,
        logging: process.env.NODE_ENV === 'development' ? console.log : false,
    });
}

module.exports = sequelize;
