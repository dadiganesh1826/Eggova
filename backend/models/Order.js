const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Order = sequelize.define('Order', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    orderNumber: {
        type: DataTypes.STRING,
        allowNull: false,
        unique: true,
        field: 'order_number',
    },
    userId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'user_id',
        references: { model: 'users', key: 'id' },
    },
    trayCount: {
        type: DataTypes.INTEGER,
        allowNull: false,
        field: 'tray_count',
        validate: { min: 1 },
    },
    pricePerTray: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
        field: 'price_per_tray',
    },
    totalAmount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
        field: 'total_amount',
    },
    paymentMethod: {
        type: DataTypes.ENUM('upi', 'pay_later'),
        allowNull: false,
        field: 'payment_method',
    },
    paymentStatus: {
        type: DataTypes.ENUM('pending', 'completed', 'approval_pending'),
        defaultValue: 'pending',
        field: 'payment_status',
    },
    orderStatus: {
        type: DataTypes.ENUM('placed', 'confirmed', 'delivered', 'cancelled'),
        defaultValue: 'placed',
        field: 'order_status',
    },
    razorpayOrderId: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'razorpay_order_id',
    },
    razorpayPaymentId: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'razorpay_payment_id',
    },
    paidAt: {
        type: DataTypes.DATE,
        allowNull: true,
        field: 'paid_at',
    },
    paidVia: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'paid_via',
    },
}, {
    tableName: 'orders',
    underscored: true,
});

module.exports = Order;
