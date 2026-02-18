const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Notification = sequelize.define('Notification', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    userId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'user_id',
        references: { model: 'users', key: 'id' },
    },
    title: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    message: {
        type: DataTypes.TEXT,
        allowNull: false,
    },
    type: {
        type: DataTypes.ENUM('payment_request', 'payment_approved', 'order_update', 'general'),
        defaultValue: 'general',
    },
    isRead: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
        field: 'is_read',
    },
    metadata: {
        type: DataTypes.JSON,
        allowNull: true,
    },
}, {
    tableName: 'notifications',
    underscored: true,
});

module.exports = Notification;
