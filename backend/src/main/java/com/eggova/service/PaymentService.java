package com.eggova.service;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.VerifyPaymentRequest;
import com.eggova.entity.Notification;
import com.eggova.entity.Order;
import com.eggova.entity.User;
import com.eggova.repository.NotificationRepository;
import com.eggova.repository.OrderRepository;
import com.eggova.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class PaymentService {

    @Value("${app.razorpay.key-id:rzp_test_placeholder}")
    private String razorpayKeyId;

    @Value("${app.razorpay.key-secret:placeholder_secret}")
    private String razorpayKeySecret;

    @Value("${app.razorpay.webhook-secret:placeholder_webhook_secret}")
    private String webhookSecret;

    private final OrderRepository orderRepository;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotificationService;
    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;

    // ─────────────────────────── Create Razorpay Order ───────────────────────────

    @Transactional
    public ResponseEntity<?> createRazorpayOrder(UUID orderId, User user) {
        Optional<Order> orderOpt = orderRepository.findByIdAndUserId(orderId, user.getId());
        if (orderOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Order not found"));
        }

        Order order = orderOpt.get();
        long amountPaise = Math.round(order.getTotalAmount().doubleValue() * 100);

        String razorpayOrderId = null;

        // Try calling Razorpay API if real credentials configured
        if (!"rzp_test_placeholder".equals(razorpayKeyId) && !"placeholder_secret".equals(razorpayKeySecret)) {
            try {
                Map<String, Object> reqBody = new LinkedHashMap<>();
                reqBody.put("amount", amountPaise);
                reqBody.put("currency", "INR");
                reqBody.put("receipt", order.getOrderNumber());
                reqBody.put("notes", Map.of(
                        "orderId", order.getId().toString(),
                        "userId", user.getId().toString()
                ));

                String json = objectMapper.writeValueAsString(reqBody);
                RequestBody body = RequestBody.create(json, MediaType.parse("application/json; charset=utf-8"));
                String credentials = Credentials.basic(razorpayKeyId, razorpayKeySecret);

                Request request = new Request.Builder()
                        .url("https://api.razorpay.com/v1/orders")
                        .header("Authorization", credentials)
                        .post(body)
                        .build();

                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful() && response.body() != null) {
                        Map<String, Object> respMap = objectMapper.readValue(response.body().string(), Map.class);
                        razorpayOrderId = (String) respMap.get("id");
                    } else {
                        log.warn("Razorpay API call failed with code {}: {}", response.code(), response.body() != null ? response.body().string() : "");
                    }
                }
            } catch (Exception e) {
                log.warn("Error calling Razorpay API: {}", e.getMessage());
            }
        }

        // Fallback for local testing / dev mode
        if (razorpayOrderId == null) {
            razorpayOrderId = "order_dev_" + UUID.randomUUID().toString().replace("-", "").substring(0, 14);
            log.info("Using mock razorpayOrderId for dev: {}", razorpayOrderId);
        }

        order.setRazorpayOrderId(razorpayOrderId);
        orderRepository.save(order);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("razorpayOrderId", razorpayOrderId);
        data.put("amount", amountPaise);
        data.put("currency", "INR");
        data.put("keyId", razorpayKeyId);

        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Verify Payment ───────────────────────────

    @Transactional
    public ResponseEntity<?> verifyPayment(VerifyPaymentRequest req, User user) {
        if (req.getRazorpayOrderId() == null || req.getRazorpayPaymentId() == null || req.getRazorpaySignature() == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Missing payment verification details"));
        }

        // Verify HMAC-SHA256 signature (skip check if placeholder in dev)
        boolean isDevPlaceholder = "placeholder_secret".equals(razorpayKeySecret) || req.getRazorpayOrderId().startsWith("order_dev_");
        if (!isDevPlaceholder) {
            try {
                String payload = req.getRazorpayOrderId() + "|" + req.getRazorpayPaymentId();
                String expected = hmacSha256(payload, razorpayKeySecret);
                if (!expected.equals(req.getRazorpaySignature())) {
                    return ResponseEntity.badRequest().body(ApiResponse.error("Invalid payment signature"));
                }
            } catch (Exception e) {
                log.error("Signature verification failed: {}", e.getMessage());
                return ResponseEntity.badRequest().body(ApiResponse.error("Payment verification failed"));
            }
        }

        Optional<Order> orderOpt = orderRepository.findByRazorpayOrderIdAndUserId(req.getRazorpayOrderId(), user.getId());
        if (orderOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Order not found"));
        }

        Order order = orderOpt.get();
        order.setRazorpayPaymentId(req.getRazorpayPaymentId());
        order.setPaymentStatus(Order.PaymentStatus.completed);
        order.setOrderStatus(Order.OrderStatus.confirmed);
        order.setPaidAt(LocalDateTime.now());
        order.setPaidVia("upi");
        Order savedOrder = orderRepository.save(order);

        // Notify Admins
        List<User> admins = userRepository.findAllByRole(User.Role.admin);
        List<String> adminTokens = admins.stream()
                .map(User::getFcmToken)
                .filter(t -> t != null && !t.isBlank())
                .collect(Collectors.toList());

        for (User admin : admins) {
            createNotification(
                    admin.getId(),
                    "Payment Received! 💰",
                    "Online payment of ₹" + order.getTotalAmount() + " received from " + user.getName() + " for order " + order.getOrderNumber(),
                    Notification.NotifType.payment_received,
                    Map.of("orderId", order.getId().toString(), "amount", order.getTotalAmount(), "paidVia", "upi")
            );
        }

        pushNotificationService.sendPushToMany(
                adminTokens,
                "💰 Payment Received!",
                "₹" + order.getTotalAmount() + " from " + user.getName() + " (" + order.getOrderNumber() + ") via UPI",
                Map.of("orderId", order.getId().toString(), "type", "payment_received")
        );

        // Notify User
        createNotification(
                user.getId(),
                "Order Confirmed! 🥚✅",
                "Payment successful! Your order for " + order.getTrayCount() + " tray(s) has been confirmed and placed.",
                Notification.NotifType.order_update,
                Map.of("orderId", order.getId().toString(), "trayCount", order.getTrayCount())
        );

        if (user.getFcmToken() != null && !user.getFcmToken().isBlank()) {
            pushNotificationService.sendPush(
                    user.getFcmToken(),
                    "Order Confirmed! 🥚✅",
                    "Payment successful for " + order.getTrayCount() + " tray(s). Your order is now confirmed!",
                    Map.of("orderId", order.getId().toString(), "type", "order_confirmed")
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("Payment verified and confirmed successfully", savedOrder));
    }

    // ─────────────────────────── Cancel UPI Order ───────────────────────────

    @Transactional
    public ResponseEntity<?> cancelUpiOrder(UUID orderId, User user) {
        Optional<Order> orderOpt = orderRepository.findByIdAndUserId(orderId, user.getId());
        if (orderOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Order not found"));
        }

        Order order = orderOpt.get();
        if (order.getPaymentStatus() != Order.PaymentStatus.pending) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Order is not in a cancellable state"));
        }

        order.setPaymentStatus(Order.PaymentStatus.failed);
        order.setOrderStatus(Order.OrderStatus.cancelled);
        Order saved = orderRepository.save(order);

        return ResponseEntity.ok(ApiResponse.ok("Order cancelled due to payment failure", saved));
    }

    // ─────────────────────────── Request Completion ───────────────────────────

    @Transactional
    public ResponseEntity<?> requestCompletion(UUID orderId, String paidVia, User user) {
        Optional<Order> orderOpt = orderRepository.findByIdAndUserId(orderId, user.getId());
        if (orderOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Pending order not found"));
        }

        Order order = orderOpt.get();
        if (order.getPaymentStatus() != Order.PaymentStatus.pending) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Order is not pending payment"));
        }

        order.setPaymentStatus(Order.PaymentStatus.approval_pending);
        order.setPaidVia(paidVia != null ? paidVia : "cash");
        orderRepository.save(order);

        List<User> admins = userRepository.findAllByRole(User.Role.admin);
        for (User admin : admins) {
            createNotification(
                    admin.getId(),
                    "Payment Completion Request",
                    user.getName() + " claims to have paid ₹" + order.getTotalAmount() + " for order " + order.getOrderNumber(),
                    Notification.NotifType.payment_request,
                    Map.of("orderId", order.getId().toString(), "userName", user.getName(), "amount", order.getTotalAmount())
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("Payment completion request sent to admin"));
    }

    // ─────────────────────────── Admin Mark Paid ───────────────────────────

    @Transactional
    public ResponseEntity<?> markPaid(UUID orderId, String paidVia, User adminUser) {
        Optional<Order> orderOpt = orderRepository.findById(orderId);
        if (orderOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Order not found"));
        }

        Order order = orderOpt.get();
        order.setPaymentStatus(Order.PaymentStatus.completed);
        order.setOrderStatus(Order.OrderStatus.confirmed);
        order.setPaidAt(LocalDateTime.now());
        order.setPaidVia(paidVia != null ? paidVia : "cash");
        Order saved = orderRepository.save(order);

        if (order.getUserId() != null) {
            createNotification(
                    order.getUserId(),
                    "Payment Confirmed",
                    "Your payment of ₹" + order.getTotalAmount() + " for order " + order.getOrderNumber() + " has been confirmed by admin",
                    Notification.NotifType.payment_approved,
                    Map.of("orderId", order.getId().toString())
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("Payment marked as completed", saved));
    }

    // ─────────────────────────── Webhook Helpers ───────────────────────────

    public boolean verifyWebhookSignature(byte[] rawBody, String signature) {
        if ("placeholder_webhook_secret".equals(webhookSecret)) {
            return true; // allow in dev mode
        }
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec key = new SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(key);
            byte[] hash = mac.doFinal(rawBody);
            String expected = HexFormat.of().formatHex(hash);
            return expected.equalsIgnoreCase(signature);
        } catch (Exception e) {
            log.error("Webhook signature verify error: {}", e.getMessage());
            return false;
        }
    }

    @Transactional
    public void handleWebhookPayload(Map<String, Object> payload) {
        try {
            String event = (String) payload.get("event");
            if (event == null) return;

            Map<String, Object> payloadData = (Map<String, Object>) payload.get("payload");
            if (payloadData == null) return;

            Map<String, Object> payment = (Map<String, Object>) payloadData.get("payment");
            if (payment == null) return;

            Map<String, Object> entity = (Map<String, Object>) payment.get("entity");
            if (entity == null) return;

            String razorpayOrderId = (String) entity.get("order_id");
            String razorpayPaymentId = (String) entity.get("id");
            String method = (String) entity.get("method");

            if (razorpayOrderId == null) return;

            Optional<Order> orderOpt = orderRepository.findByRazorpayOrderId(razorpayOrderId);
            if (orderOpt.isEmpty()) {
                log.warn("Webhook: Order not found for Razorpay Order ID: {}", razorpayOrderId);
                return;
            }

            Order order = orderOpt.get();

            if ("payment.captured".equals(event) || "order.paid".equals(event)) {
                if (order.getPaymentStatus() == Order.PaymentStatus.completed) {
                    log.info("Webhook: Order {} already completed.", order.getOrderNumber());
                    return;
                }

                order.setRazorpayPaymentId(razorpayPaymentId);
                order.setPaymentStatus(Order.PaymentStatus.completed);
                order.setOrderStatus(Order.OrderStatus.confirmed);
                order.setPaidAt(LocalDateTime.now());
                order.setPaidVia(method != null ? method : "online");
                orderRepository.save(order);

                log.info("Webhook: Order {} marked completed.", order.getOrderNumber());
            } else if ("payment.failed".equals(event)) {
                if (order.getPaymentStatus() == Order.PaymentStatus.pending) {
                    order.setPaymentStatus(Order.PaymentStatus.failed);
                    order.setOrderStatus(Order.OrderStatus.cancelled);
                    orderRepository.save(order);
                    log.info("Webhook: Order {} marked failed.", order.getOrderNumber());
                }
            }
        } catch (Exception e) {
            log.error("Error handling webhook payload: {}", e.getMessage());
        }
    }

    // ── Helper ──
    private String hmacSha256(String data, String key) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        mac.init(secretKey);
        byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        return HexFormat.of().formatHex(hash);
    }

    private void createNotification(UUID userId, String title, String message, Notification.NotifType type, Map<String, Object> metadata) {
        try {
            String metaStr = metadata != null ? objectMapper.writeValueAsString(metadata) : null;
            Notification notif = Notification.builder()
                    .userId(userId)
                    .title(title)
                    .message(message)
                    .type(type)
                    .isRead(false)
                    .metadata(metaStr)
                    .build();
            notificationRepository.save(notif);
        } catch (Exception e) {
            log.warn("Failed to create notification: {}", e.getMessage());
        }
    }
}

