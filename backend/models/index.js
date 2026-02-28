const sequelize = require('../config/database');
const User = require('./User');
const EggPrice = require('./EggPrice');
const Order = require('./Order');
const Notification = require('./Notification');
const DailyStock = require('./DailyStock');

// Associations
User.hasMany(Order, { foreignKey: 'userId', as: 'orders' });
Order.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(Notification, { foreignKey: 'userId', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(EggPrice, { foreignKey: 'setBy', as: 'pricesSet' });
EggPrice.belongsTo(User, { foreignKey: 'setBy', as: 'setByUser' });

module.exports = {
    sequelize,
    User,
    EggPrice,
    Order,
    Notification,
    DailyStock,
};
