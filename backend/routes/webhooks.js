const express = require('express');
const crypto = require('crypto');
const { Order, User, Notification } = require('../models');
const { sendPush, sendPushToMany } = require('../services/push');

const router = express.Router();

router.post('/', async (req, res) => {
    try {
        const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

        if (!webhookSecret) {
            console.error('Webhook secret is not configured.');
            return res.status(500).send('Webhook secretly missing');
        }

        const signature = req.headers['x-razorpay-signature'];

        if (!signature || !req.rawBody) {
            return res.status(400).send('Invalid signature or body');
        }

        // Verify the signature
        const expectedSignature = crypto
            .createHmac('sha256', webhookSecret)
            .update(req.rawBody)
            .digest('hex');

        if (expectedSignature !== signature) {
            return res.status(400).send('Invalid signature');
        }

        // Signature is valid, process event
        const event = req.body.event;
        console.log(`Received Razorpay Webhook: ${event}`);

        // Handle Payment Captured
        if (event === 'payment.captured' || event === 'order.paid') {
            const paymentEntity = req.body.payload.payment.entity;
            const razorpayOrderId = paymentEntity.order_id;
            const razorpayPaymentId = paymentEntity.id;
            const method = paymentEntity.method; // e.g. 'upi'

            if (!razorpayOrderId) {
                // Not linked to an order, skip safely
                return res.status(200).send('OK');
            }

            const order = await Order.findOne({
                where: { razorpayOrderId },
                include: [{ model: User, as: 'user' }]
            });

            if (!order) {
                console.warn(`Webhook: Order not found for Razorpay Order ID: ${razorpayOrderId}`);
                return res.status(200).send('OK');
            }

            // Idempotency: Check if order is already processed
            if (order.paymentStatus === 'completed') {
                console.log(`Webhook: Order ${order.orderNumber} already completed.`);
                return res.status(200).send('OK');
            }

            // Update order and mark completed
            await order.update({
                razorpayPaymentId,
                paymentStatus: 'completed',
                orderStatus: 'confirmed',
                paidAt: new Date(),
                paidVia: method || 'online',
            });

            console.log(`Webhook: Order ${order.orderNumber} successfully marked as completed.`);

            // Notify Admins
            const admins = await User.findAll({ where: { role: 'admin' } });
            const adminFcmTokens = admins.map(a => a.fcmToken).filter(Boolean);
            const customerName = order.user ? order.user.name : (order.customerName || 'Customer');

            for (const admin of admins) {
                await Notification.create({
                    userId: admin.id,
                    title: 'Payment Received via Webhook! 💰',
                    message: `Online payment of ₹${order.totalAmount} received from ${customerName} for order ${order.orderNumber}`,
                    type: 'payment_received',
                    metadata: { orderId: order.id, amount: order.totalAmount, paidVia: method },
                });
            }

            await sendPushToMany(
                adminFcmTokens,
                '💰 Payment Received!',
                `₹${order.totalAmount} from ${customerName} (${order.orderNumber}) via ${method}`,
                { orderId: order.id, type: 'payment_received' }
            );

            // Notify User
            if (order.userId && order.user) {
                await Notification.create({
                    userId: order.userId,
                    title: 'Order Confirmed! 🥚✅',
                    message: `Payment successful! Your order for ${order.trayCount} tray(s) has been confirmed and placed (Webhook).`,
                    type: 'order_update',
                    metadata: { orderId: order.id, trayCount: order.trayCount },
                });

                if (order.user.fcmToken) {
                    await sendPush(
                        order.user.fcmToken,
                        'Order Confirmed! 🥚✅',
                        `Payment successful for ${order.trayCount} tray(s). Your order is now confirmed!`,
                        { orderId: order.id, type: 'order_confirmed' }
                    );
                }
            }
        }

        // Handle Payment Failed
        else if (event === 'payment.failed') {
            const paymentEntity = req.body.payload.payment.entity;
            const razorpayOrderId = paymentEntity.order_id;

            if (razorpayOrderId) {
                const order = await Order.findOne({
                    where: { razorpayOrderId }
                });

                // Only cancel if it was still pending
                if (order && order.paymentStatus === 'pending') {
                    await order.update({
                        paymentStatus: 'failed',
                        orderStatus: 'cancelled',
                    });
                    console.log(`Webhook: Order ${order.orderNumber} marked as failed due to payment failure.`);
                }
            }
        }

        // Always return 200 OK so Razorpay doesn't retry infinitely
        res.status(200).send('OK');

    } catch (error) {
        console.error('Webhook processing error:', error);
        res.status(500).send('Internal Server Error');
    }
});

module.exports = router;
