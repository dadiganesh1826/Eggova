const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const bcrypt = require('bcryptjs');

const User = sequelize.define('User', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    name: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    email: {
        type: DataTypes.STRING,
        allowNull: true,
        unique: true,
        validate: { isEmail: true },
    },
    phone: {
        type: DataTypes.STRING(15),
        allowNull: false,
        unique: true,
    },
    passwordHash: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'password_hash',
    },
    address: {
        type: DataTypes.TEXT,
        allowNull: true,
    },
    district: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    state: {
        type: DataTypes.STRING,
        allowNull: false,
        defaultValue: 'Andhra Pradesh',
    },
    pincode: {
        type: DataTypes.STRING(10),
        allowNull: true,
    },
    role: {
        type: DataTypes.ENUM('admin', 'user'),
        defaultValue: 'user',
    },
    fcmToken: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'fcm_token',
    },
    status: {
        type: DataTypes.ENUM('pending', 'approved', 'rejected'),
        defaultValue: 'approved', // Legacy users default to approved
    },
    pendingPhone: {
        type: DataTypes.STRING(15),
        allowNull: true,
        field: 'pending_phone',
    },
}, {
    tableName: 'users',
    underscored: true,
    hooks: {
        beforeCreate: async (user) => {
            if (user.passwordHash) {
                user.passwordHash = await bcrypt.hash(user.passwordHash, 12);
            }
        },
    },
});

User.prototype.comparePassword = async function (password) {
    return bcrypt.compare(password, this.passwordHash);
};

User.prototype.toSafeJSON = function () {
    const values = { ...this.get() };
    delete values.passwordHash;
    delete values.password_hash;
    return values;
};

module.exports = User;
