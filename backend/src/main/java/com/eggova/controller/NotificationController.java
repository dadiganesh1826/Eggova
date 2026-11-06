package com.eggova.controller;

import com.eggova.entity.User;
import com.eggova.service.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Tag(name = "Notifications", description = "Endpoints for user alerts, marking read, and FCM push notification management")
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @Operation(summary = "Get My Notifications", description = "Fetch past 50 notifications and unread count for current user")
    @GetMapping("/my")
    public ResponseEntity<?> getMyNotifications(Authentication auth) {
        User user = (User) auth.getPrincipal();
        return notificationService.getMyNotifications(user);
    }

    @Operation(summary = "Mark Notification as Read", description = "Mark a single notification as read by UUID")
    @PutMapping("/read/{id}")
    public ResponseEntity<?> markRead(@PathVariable String id, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return notificationService.markRead(UUID.fromString(id), user);
    }

    @Operation(summary = "Mark All Notifications Read", description = "Mark all unread notifications as read for current user")
    @PutMapping("/read-all")
    public ResponseEntity<?> markAllRead(Authentication auth) {
        User user = (User) auth.getPrincipal();
        return notificationService.markAllRead(user);
    }

    @Operation(summary = "Save FCM Token", description = "Register or refresh device FCM token for push notifications")
    @PostMapping("/fcm-token")
    public ResponseEntity<?> saveFcmToken(@RequestBody Map<String, String> body, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return notificationService.saveFcmToken(body.get("token"), user);
    }

    @Operation(summary = "Check Admin Tokens (Admin)", description = "Debug endpoint to list all admin devices with active FCM tokens")
    @GetMapping("/check-tokens")
    public ResponseEntity<?> checkTokens(Authentication auth) {
        User user = (User) auth.getPrincipal();
        return notificationService.checkTokens(user);
    }

    @Operation(summary = "Test Push Notification", description = "Send a test push notification to caller's registered device")
    @PostMapping("/test-push")
    public ResponseEntity<?> testPush(Authentication auth) {
        User user = (User) auth.getPrincipal();
        return notificationService.testPush(user);
    }
}
