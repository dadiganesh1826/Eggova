package com.eggova.service;

import com.eggova.dto.ApiResponse;
import com.eggova.entity.Notification;
import com.eggova.entity.User;
import com.eggova.repository.NotificationRepository;
import com.eggova.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final PushNotificationService pushNotificationService;

    // ─────────────────────────── Get My Notifications ───────────────────────────

    public ResponseEntity<?> getMyNotifications(User user) {
        List<Notification> notifications = notificationRepository.findAllByUserIdOrderByCreatedAtDesc(
                user.getId(), PageRequest.of(0, 50)
        );
        long unreadCount = notificationRepository.countByUserIdAndIsReadFalse(user.getId());

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("notifications", notifications);
        data.put("unreadCount", unreadCount);

        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Mark As Read ───────────────────────────

    @Transactional
    public ResponseEntity<?> markRead(UUID id, User user) {
        Optional<Notification> notifOpt = notificationRepository.findByIdAndUserId(id, user.getId());
        if (notifOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error("Notification not found"));
        }

        Notification notification = notifOpt.get();
        notification.setRead(true);
        notificationRepository.save(notification);

        return ResponseEntity.ok(ApiResponse.ok("Marked as read"));
    }

    // ─────────────────────────── Mark All As Read ───────────────────────────

    @Transactional
    public ResponseEntity<?> markAllRead(User user) {
        notificationRepository.markAllReadByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.ok("All notifications marked as read"));
    }

    // ─────────────────────────── Save FCM Token ───────────────────────────

    @Transactional
    public ResponseEntity<?> saveFcmToken(String token, User user) {
        if (token == null || token.isBlank()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Token required"));
        }

        user.setFcmToken(token);
        userRepository.save(user);

        return ResponseEntity.ok(ApiResponse.ok("FCM token saved"));
    }

    // ─────────────────────────── Check Tokens (Admin) ───────────────────────────

    public ResponseEntity<?> checkTokens(User user) {
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error("Admin only"));
        }

        List<User> admins = userRepository.findAllByRole(User.Role.admin);
        List<User> allUsers = userRepository.findAll();

        List<Map<String, Object>> adminTokens = admins.stream().map(a -> {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("name", a.getName());
            map.put("hasToken", a.getFcmToken() != null && !a.getFcmToken().isBlank());
            map.put("tokenStart", a.getFcmToken() != null && a.getFcmToken().length() >= 20
                    ? a.getFcmToken().substring(0, 20) : null);
            return map;
        }).collect(Collectors.toList());

        long allUsersWithTokens = allUsers.stream()
                .filter(u -> u.getFcmToken() != null && !u.getFcmToken().isBlank())
                .count();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("adminTokens", adminTokens);
        data.put("allUsersWithTokens", allUsersWithTokens);
        data.put("totalUsers", allUsers.size());

        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Test Push ───────────────────────────

    public ResponseEntity<?> testPush(User user) {
        Optional<User> freshUserOpt = userRepository.findById(user.getId());
        if (freshUserOpt.isEmpty() || freshUserOpt.get().getFcmToken() == null || freshUserOpt.get().getFcmToken().isBlank()) {
            return ResponseEntity.ok(ApiResponse.error("No FCM token saved for your account. Login again with the latest app."));
        }

        User freshUser = freshUserOpt.get();
        pushNotificationService.sendPush(
                freshUser.getFcmToken(),
                "🔔 Test Notification",
                "Push notifications are working! 🎉",
                Map.of("type", "test")
        );

        return ResponseEntity.ok(ApiResponse.ok("Test push sent to " + freshUser.getName()));
    }
}

