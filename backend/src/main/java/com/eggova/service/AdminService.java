package com.eggova.service;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.OfflineOrderRequest;
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
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class AdminService {

    private final UserRepository userRepository;
    private final OrderRepository orderRepository;
    private final DailyStockRepository dailyStockRepository;
    private final EggPriceRepository eggPriceRepository;
    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotificationService;
    private final ObjectMapper objectMapper;

    private static final Random RANDOM = new Random();

    private String generateOrderNumber() {
        String dateStr = LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE);
        int rand = 1000 + RANDOM.nextInt(9000);
        return "EGG-" + dateStr + "-" + rand;
    }

    // ─────────────────────────── Users Management ───────────────────────────

    public ResponseEntity<?> getAllUsers() {
        List<User> users = userRepository.findAllByRoleOrderByCreatedAtDesc(User.Role.user);
        List<Map<String, Object>> safeUsers = users.stream().map(this::safeUser).collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(safeUsers));
    }

    public ResponseEntity<?> getPendingUsers() {
        List<User> users = userRepository.findAllByRoleAndStatusOrderByCreatedAtDesc(User.Role.user, User.Status.pending);
        List<Map<String, Object>> safeUsers = users.stream().map(this::safeUser).collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(safeUsers));
    }

    @Transactional
    public ResponseEntity<?> approveUser(UUID id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("User not found"));
        }

        User user = userOpt.get();
        user.setStatus(User.Status.approved);
        userRepository.save(user);

        // Notify user
        createNotification(
                user.getId(),
                "Account Approved! 🎉",
                "Your Eggova account has been approved. You can now access all features!",
                Notification.NotifType.account_approved,
                null
        );

        if (user.getFcmToken() != null && !user.getFcmToken().isBlank()) {
            pushNotificationService.sendPush(
                    user.getFcmToken(),
                    "Account Approved! 🎉",
                    "Your Eggova account has been approved. You can now access all features!",
                    Map.of("type", "account_approved")
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("User approved successfully", safeUser(user)));
    }

    @Transactional
    public ResponseEntity<?> rejectUser(UUID id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("User not found"));
        }

        User user = userOpt.get();
        String fcmToken = user.getFcmToken();

        userRepository.delete(user);

        if (fcmToken != null && !fcmToken.isBlank()) {
            pushNotificationService.sendPush(
                    fcmToken,
                    "Account Registration Rejected",
                    "Your registration was rejected. Please contact support or try registering again with correct details.",
                    Map.of("type", "account_rejected")
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("User rejected and deleted successfully"));
    }

    public ResponseEntity<?> getPendingPhoneUpdates() {
        List<User> users = userRepository.findAllByPendingPhoneIsNotNullOrderByUpdatedAtDesc();
        List<Map<String, Object>> safeUsers = users.stream()
                .filter(u -> u.getRole() == User.Role.user)
                .map(this::safeUser)
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(safeUsers));
    }

    @Transactional
    public ResponseEntity<?> approvePhone(UUID id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty() || userOpt.get().getPendingPhone() == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("No phone request found"));
        }

        User user = userOpt.get();
        user.setPhone(user.getPendingPhone());
        user.setPendingPhone(null);
        userRepository.save(user);

        if (user.getFcmToken() != null && !user.getFcmToken().isBlank()) {
            pushNotificationService.sendPush(
                    user.getFcmToken(),
                    "Phone Number Updated ✅",
                    "Your phone number has been successfully updated by the admin",
                    Map.of("type", "phone_updated")
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("Phone number approved"));
    }

    @Transactional
    public ResponseEntity<?> rejectPhone(UUID id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty() || userOpt.get().getPendingPhone() == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("No phone request found"));
        }

        User user = userOpt.get();
        user.setPendingPhone(null);
        userRepository.save(user);

        if (user.getFcmToken() != null && !user.getFcmToken().isBlank()) {
            pushNotificationService.sendPush(
                    user.getFcmToken(),
                    "Phone Update Rejected ❌",
                    "Your request to update the phone number was rejected by the admin",
                    Map.of("type", "phone_rejected")
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("Phone update rejected"));
    }

    // ─────────────────────────── Payments Management ───────────────────────────

    public ResponseEntity<?> getPendingPayments() {
        List<Order> orders = orderRepository.findAllByPaymentStatusInOrderByCreatedAtDesc(
                List.of(Order.PaymentStatus.pending, Order.PaymentStatus.approval_pending)
        );
        return ResponseEntity.ok(ApiResponse.ok(orders));
    }

    public ResponseEntity<?> getCompletedPayments() {
        List<Order> orders = orderRepository.findAllByPaymentStatusOrderByPaidAtDesc(Order.PaymentStatus.completed);
        return ResponseEntity.ok(ApiResponse.ok(orders));
    }

    @Transactional
    public ResponseEntity<?> approvePayment(UUID orderId) {
        Optional<Order> orderOpt = orderRepository.findById(orderId);
        if (orderOpt.isEmpty() || orderOpt.get().getPaymentStatus() != Order.PaymentStatus.approval_pending) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Pending approval not found"));
        }

        Order order = orderOpt.get();
        order.setPaymentStatus(Order.PaymentStatus.completed);
        order.setOrderStatus(Order.OrderStatus.confirmed);
        order.setPaidAt(LocalDateTime.now());
        Order saved = orderRepository.save(order);

        if (order.getUserId() != null) {
            createNotification(
                    order.getUserId(),
                    "Payment Approved! ✅",
                    "Your payment of ₹" + order.getTotalAmount() + " for order " + order.getOrderNumber() + " has been approved",
                    Notification.NotifType.payment_approved,
                    Map.of("orderId", order.getId().toString())
            );
        }

        return ResponseEntity.ok(ApiResponse.ok("Payment approved", saved));
    }

    // ─────────────────────────── Dashboard Stats ───────────────────────────

    public ResponseEntity<?> getDashboardStats() {
        long totalUsers = userRepository.countByRole(User.Role.user);
        long totalOrders = orderRepository.count();
        long pendingPayments = orderRepository.countByPaymentStatusIn(
                List.of(Order.PaymentStatus.pending, Order.PaymentStatus.approval_pending)
        );
        long completedPayments = orderRepository.countByPaymentStatus(Order.PaymentStatus.completed);

        Double totalRevenue = orderRepository.sumTotalAmountByPaymentStatus(Order.PaymentStatus.completed);
        Double pendingAmount = orderRepository.sumTotalAmountByPaymentStatusIn(
                List.of(Order.PaymentStatus.pending, Order.PaymentStatus.approval_pending)
        );

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("totalUsers", totalUsers);
        data.put("totalOrders", totalOrders);
        data.put("pendingPayments", pendingPayments);
        data.put("completedPayments", completedPayments);
        data.put("totalRevenue", totalRevenue != null ? totalRevenue : 0.0);
        data.put("pendingAmount", pendingAmount != null ? pendingAmount : 0.0);

        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Place Offline Order ───────────────────────────

    @Transactional
    public ResponseEntity<?> placeOfflineOrder(OfflineOrderRequest req, User adminUser) {
        if (req.getTrayCount() == null || req.getTrayCount() < 1) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Minimum 1 tray required"));
        }
        if (req.getCustomerName() == null || req.getCustomerPhone() == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Customer name and phone are required"));
        }

        LocalDate today = LocalDate.now();

        // ── Stock Check ──
        Optional<DailyStock> stockOpt = dailyStockRepository.findByDate(today);
        if (stockOpt.isEmpty() || stockOpt.get().getTotalTrays() == 0) {
            Map<String, Object> errData = new LinkedHashMap<>();
            errData.put("availableTrays", 0);
            return ResponseEntity.badRequest().body(new ApiResponse<>(false, "No stock available for today. Please set the stock limit first.", errData));
        }

        DailyStock stock = stockOpt.get();
        int remaining = stock.getTotalTrays() - stock.getSoldTrays();
        if (req.getTrayCount() > remaining) {
            String msg = remaining > 0
                    ? "Only " + remaining + " tray(s) available today. Please reduce the count."
                    : "All stock for today has been sold out!";
            Map<String, Object> errData = new LinkedHashMap<>();
            errData.put("availableTrays", remaining);
            return ResponseEntity.badRequest().body(new ApiResponse<>(false, msg, errData));
        }

        // ── Price Check ──
        Optional<EggPrice> priceOpt = eggPriceRepository.findByDistrictAndPriceDate(adminUser.getDistrict(), today);
        if (priceOpt.isEmpty()) {
            priceOpt = eggPriceRepository.findFirstByDistrictOrderByPriceDateDesc(adminUser.getDistrict());
        }

        if (priceOpt.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("No egg price available. Please set the egg price first."));
        }

        EggPrice price = priceOpt.get();
        BigDecimal pricePerTray = price.getPricePerTray();
        BigDecimal totalAmount = pricePerTray.multiply(BigDecimal.valueOf(req.getTrayCount()));

        Order.PaymentMethod paymentMethod = "pay_later".equalsIgnoreCase(req.getPaymentMethod())
                ? Order.PaymentMethod.pay_later
                : Order.PaymentMethod.cash;

        Order.PaymentStatus paymentStatus = paymentMethod == Order.PaymentMethod.pay_later
                ? Order.PaymentStatus.pending
                : Order.PaymentStatus.completed;

        Order order = Order.builder()
                .orderNumber(generateOrderNumber())
                .userId(null)
                .customerName(req.getCustomerName())
                .customerPhone(req.getCustomerPhone())
                .trayCount(req.getTrayCount())
                .pricePerTray(pricePerTray)
                .totalAmount(totalAmount)
                .paymentMethod(paymentMethod)
                .paymentStatus(paymentStatus)
                .orderStatus(Order.OrderStatus.delivered)
                .isOffline(true)
                .paidAt(paymentMethod == Order.PaymentMethod.pay_later ? null : LocalDateTime.now())
                .build();

        Order saved = orderRepository.save(order);

        // ── Update Stock ──
        stock.setSoldTrays(stock.getSoldTrays() + req.getTrayCount());
        int newRemaining = stock.getTotalTrays() - stock.getSoldTrays();

        List<User> adminUsers = userRepository.findAllByRole(User.Role.admin);

        if (newRemaining <= 50 && newRemaining > 0 && !stock.isLowStockNotified()) {
            for (User admin : adminUsers) {
                createNotification(
                        admin.getId(),
                        "⚠️ Low Stock Alert (Offline Order)",
                        "Only " + newRemaining + " tray(s) left today after an offline order!",
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
                        "🚨 Stock Depleted! (Offline Order)",
                        "All " + stock.getTotalTrays() + " trays for today have been sold (including offline orders)!",
                        Notification.NotifType.stock_alert,
                        Map.of("totalSold", stock.getSoldTrays(), "date", today.toString())
                );
            }
            stock.setOutOfStockNotified(true);
        }

        dailyStockRepository.save(stock);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Offline order recorded successfully", saved));
    }

    // ── Helper: Safe User ──
    private Map<String, Object> safeUser(User u) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", u.getId());
        map.put("name", u.getName());
        map.put("email", u.getEmail());
        map.put("phone", u.getPhone());
        map.put("address", u.getAddress());
        map.put("district", u.getDistrict());
        map.put("state", u.getState());
        map.put("pincode", u.getPincode());
        map.put("role", u.getRole() != null ? u.getRole().name() : "user");
        map.put("fcmToken", u.getFcmToken());
        map.put("status", u.getStatus() != null ? u.getStatus().name() : "approved");
        map.put("pendingPhone", u.getPendingPhone());
        map.put("createdAt", u.getCreatedAt());
        map.put("updatedAt", u.getUpdatedAt());
        return map;
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

