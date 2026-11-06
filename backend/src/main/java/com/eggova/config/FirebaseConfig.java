package com.eggova.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;

@Configuration
@Slf4j
public class FirebaseConfig {

    @Value("${app.firebase.service-account-path:./firebase-service-account.json}")
    private String serviceAccountPath;

    @Value("${app.firebase.enabled:false}")
    private boolean firebaseEnabled;

    @Bean
    public FirebaseApp firebaseApp() {
        if (!firebaseEnabled) {
            log.info("Firebase is disabled in configuration.");
            return null;
        }

        try {
            if (!FirebaseApp.getApps().isEmpty()) {
                return FirebaseApp.getInstance();
            }

            File file = new File(serviceAccountPath);
            if (!file.exists()) {
                log.warn("Firebase service account file not found at: {}. Running without Firebase.", serviceAccountPath);
                return null;
            }

            try (InputStream serviceAccount = new FileInputStream(file)) {
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();
                FirebaseApp app = FirebaseApp.initializeApp(options);
                log.info("✅ Firebase Admin SDK initialized successfully");
                return app;
            }
        } catch (Exception e) {
            log.warn("❌ Failed to initialize Firebase: {}. Running without Firebase.", e.getMessage());
            return null;
        }
    }
}

