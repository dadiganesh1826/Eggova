const sequelize = require('../config/database');
const User = require('./User');
const EggPrice = require('./EggPrice');
const Order = require('./Order');
const Notification = require('./Notification');
const DailyStock = require('./DailyStock');

// Associations
User.hasMany(Order, { foreignKey: 'user_id', as: 'orders' });
Order.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

User.hasMany(Notification, { foreignKey: 'user_id', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

User.hasMany(EggPrice, { foreignKey: 'set_by', as: 'pricesSet' });
EggPrice.belongsTo(User, { foreignKey: 'set_by', as: 'setByUser' });

module.exports = {
    sequelize,
    User,
    EggPrice,
    Order,
    Notification,
    DailyStock,
};
