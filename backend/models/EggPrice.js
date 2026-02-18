const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const EggPrice = sequelize.define('EggPrice', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    district: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    pricePerEgg: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
        field: 'price_per_egg',
    },
    pricePerTray: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
        field: 'price_per_tray',
    },
    priceDate: {
        type: DataTypes.DATEONLY,
        allowNull: false,
        field: 'price_date',
    },
    setBy: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'set_by',
        references: { model: 'users', key: 'id' },
    },
}, {
    tableName: 'egg_prices',
    underscored: true,
});

module.exports = EggPrice;
