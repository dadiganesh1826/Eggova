package com.eggova.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
@Slf4j
public class PushNotificationService {

    @Autowired(required = false)
    private FirebaseApp firebaseApp;

    @Value("${app.firebase.enabled:false}")
    private boolean firebaseEnabled;

    public void sendPush(String fcmToken, String title, String body, Map<String, String> data) {
        if (!firebaseEnabled || firebaseApp == null) {
            log.info("[PushNotification] Firebase disabled or not configured. Would send: title='{}', body='{}'", title, body);
            return;
        }
        if (fcmToken == null || fcmToken.isBlank()) {
            log.warn("[PushNotification] FCM token is null or blank. Skipping push for title='{}'", title);
            return;
        }
        try {
            AndroidConfig androidConfig = AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setNotification(AndroidNotification.builder()
                            .setChannelId("eggova_notifications")
                            .build())
                    .build();

            Message.Builder messageBuilder = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .setAndroidConfig(androidConfig);

            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String response = FirebaseMessaging.getInstance(firebaseApp).send(messageBuilder.build());
            log.info("[PushNotification] Sent successfully. MessageId={}", response);
        } catch (FirebaseMessagingException e) {
            log.error("[PushNotification] Failed to send push to token={}: {}", fcmToken, e.getMessage());
        }
    }

    public void sendPushToMany(List<String> tokens, String title, String body, Map<String, String> data) {
        if (tokens == null || tokens.isEmpty()) {
            log.info("[PushNotification] No tokens provided for broadcast push: title='{}'", title);
            return;
        }
        tokens.stream()
                .filter(t -> t != null && !t.isBlank())
                .forEach(token -> sendPush(token, title, body, data));
    }
}
