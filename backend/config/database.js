const { Sequelize } = require('sequelize');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'eggova.sqlite');

const sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: dbPath,
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
});

module.exports = sequelize;
