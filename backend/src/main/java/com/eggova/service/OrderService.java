package com.eggova.service;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.PlaceOrderRequest;
import com.eggova.entity.*;
import com.eggova.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final DailyStockRepository dailyStockRepository;
    private final EggPriceRepository eggPriceRepository;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotificationService;
    private final ObjectMapper objectMapper;

    private static final Random RANDOM = new Random();

    private String generateOrderNumber() {
        String dateStr = LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE); // YYYYMMDD
        int rand = 1000 + RANDOM.nextInt(9000);
        return "EGG-" + dateStr + "-" + rand;
    }

    // ─────────────────────────── Place Order ───────────────────────────

    @Transactional
    public ResponseEntity<?> placeOrder(PlaceOrderRequest req, User user) {
        if (req.getTrayCount() == null || req.getTrayCount() < 1) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Minimum 1 tray required"));
        }

        if (req.getPaymentMethod() == null ||
                (!req.getPaymentMethod().equalsIgnoreCase("upi") && !req.getPaymentMethod().equalsIgnoreCase("pay_later"))) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Invalid payment method"));
        }

        Order.PaymentMethod paymentMethod;
        try {
            paymentMethod = Order.PaymentMethod.valueOf(req.getPaymentMethod().toLowerCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Invalid payment method"));
        }

        LocalDate today = LocalDate.now();

        // ── Stock Check ──
        Optional<DailyStock> stockOpt = dailyStockRepository.findByDate(today);
        if (stockOpt.isEmpty() || stockOpt.get().getTotalTrays() == 0) {
            Map<String, Object> errData = new LinkedHashMap<>();
            errData.put("availableTrays", 0);
            return ResponseEntity.badRequest().body(new ApiResponse<>(false, "No stock available for today. Please check back later.", errData));
        }

        DailyStock stock = stockOpt.get();
        int remaining = stock.getTotalTrays() - stock.getSoldTrays();

        if (req.getTrayCount() > remaining) {
            String msg = remaining > 0
                    ? "Only " + remaining + " tray(s) available today. Please reduce your order."
                    : "All stock for today has been sold out!";
            Map<String, Object> errData = new LinkedHashMap<>();
            errData.put("availableTrays", remaining);
            return ResponseEntity.badRequest().body(new ApiResponse<>(false, msg, errData));
        }

        // ── Price Check ──
        Optional<EggPrice> priceOpt = eggPriceRepository.findByDistrictAndPriceDate(user.getDistrict(), today);
        if (priceOpt.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error(
                    "Egg rates for today have not been updated yet for your district. Please try again later."
            ));
        }

        EggPrice eggPrice = priceOpt.get();
        BigDecimal pricePerTray = eggPrice.getPricePerTray();
        BigDecimal totalAmount = pricePerTray.multiply(BigDecimal.valueOf(req.getTrayCount()));

        Order order = Order.builder()
                .orderNumber(generateOrderNumber())
                .userId(user.getId())
                .trayCount(req.getTrayCount())
                .pricePerTray(pricePerTray)
                .totalAmount(totalAmount)
                .paymentMethod(paymentMethod)
                .paymentStatus(Order.PaymentStatus.pending)
                .orderStatus(Order.OrderStatus.placed)
                .isOffline(false)
                .build();

        Order savedOrder = orderRepository.save(order);

        // ── Update Stock ──
        stock.setSoldTrays(stock.getSoldTrays() + req.getTrayCount());
        int newRemaining = stock.getTotalTrays() - stock.getSoldTrays();

        List<User> adminUsers = userRepository.findAllByRole(User.Role.admin);

        if (newRemaining <= 50 && newRemaining > 0 && !stock.isLowStockNotified()) {
            for (User admin : adminUsers) {
                createNotification(
                        admin.getId(),
                        "⚠️ Low Stock Alert",
                        "Only " + newRemaining + " tray(s) left today! Consider increasing the daily stock limit.",
                        Notification.NotifType.stock_alert,
                        Map.of("remainingTrays", newRemaining, "date", today.toString())
                );
            }
            stock.setLowStockNotified(true);
        }

        if (newRemaining == 0 && !stock.isOutOfStockNotified()) {
            for (User admin : adminUsers) {
                createNotification(
                        admin.getId(),
                        "🚨 Stock Depleted!",
                        "All " + stock.getTotalTrays() + " trays for today have been sold! Increase the stock limit to accept more orders.",
                        Notification.NotifType.stock_alert,
                        Map.of("totalSold", stock.getSoldTrays(), "date", today.toString())
                );
            }
            stock.setOutOfStockNotified(true);
        }

        dailyStockRepository.save(stock);

        // ── Pay Later Handling ──
        if (paymentMethod == Order.PaymentMethod.pay_later) {
            List<String> adminTokens = adminUsers.stream()
                    .map(User::getFcmToken)
                    .filter(t -> t != null && !t.isBlank())
                    .collect(Collectors.toList());

            Map<String, String> pushData = new HashMap<>();
            pushData.put("orderId", savedOrder.getId().toString());
            pushData.put("type", "new_order_cash");

            pushNotificationService.sendPushToMany(
                    adminTokens,
                    "📋 New Cash Order!",
                    user.getName() + " ordered " + req.getTrayCount() + " tray(s) — ₹" + totalAmount + " (Pay Later)",
                    pushData
            );

            createNotification(
                    user.getId(),
                    "Order Placed Successfully! 🎉",
                    "Your order for " + req.getTrayCount() + " tray(s) has been placed. Please pay when eggs are delivered.",
                    Notification.NotifType.order_update,
                    Map.of("orderId", savedOrder.getId().toString(), "trayCount", req.getTrayCount())
            );

            if (user.getFcmToken() != null && !user.getFcmToken().isBlank()) {
                Map<String, String> userPushData = new HashMap<>();
                userPushData.put("orderId", savedOrder.getId().toString());
                userPushData.put("type", "order_placed");

                pushNotificationService.sendPush(
                        user.getFcmToken(),
                        "Order Placed Successfully! 🎉",
                        "Your order for " + req.getTrayCount() + " tray(s) has been placed. Thank you for choosing Eggova!",
                        userPushData
                );
            }
        }

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Order placed successfully", savedOrder));
    }

    // ─────────────────────────── Order History ───────────────────────────

    public ResponseEntity<?> getHistory(User user) {
        List<Order> orders = orderRepository.findAllByUserIdOrderByCreatedAtDesc(user.getId());
        return ResponseEntity.ok(ApiResponse.ok(orders));
    }

    // ─────────────────────────── Single Order ───────────────────────────

    public ResponseEntity<?> getOrder(UUID id, User user) {
        Optional<Order> orderOpt = orderRepository.findByIdAndUserId(id, user.getId());
        if (orderOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Order not found"));
        }
        return ResponseEntity.ok(ApiResponse.ok(orderOpt.get()));
    }

    // ── Helper ──
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

