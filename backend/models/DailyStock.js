const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const DailyStock = sequelize.define('DailyStock', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    date: {
        type: DataTypes.DATEONLY,
        allowNull: false,
        unique: true,
    },
    totalTrays: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0,
        field: 'total_trays',
    },
    soldTrays: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0,
        field: 'sold_trays',
    },
    lowStockNotified: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        field: 'low_stock_notified',
    },
    outOfStockNotified: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        field: 'out_of_stock_notified',
    },
    setBy: {
        type: DataTypes.UUID,
        allowNull: true,
        field: 'set_by',
        references: { model: 'users', key: 'id' },
    },
}, {
    tableName: 'daily_stock',
    underscored: true,
});

module.exports = DailyStock;
