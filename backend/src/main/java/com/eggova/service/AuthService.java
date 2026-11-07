package com.eggova.service;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.ChangePasswordRequest;
import com.eggova.dto.request.RegisterDetailsRequest;
import com.eggova.dto.request.UpdateProfileRequest;
import com.eggova.entity.User;
import com.eggova.repository.UserRepository;
import com.eggova.security.JwtTokenProvider;
import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final JwtTokenProvider jwtTokenProvider;
    private final PasswordEncoder passwordEncoder;
    private final PushNotificationService pushNotificationService;

    @Autowired(required = false)
    private FirebaseApp firebaseApp;

    @Value("${app.firebase.enabled:false}")
    private boolean firebaseEnabled;

    private static final Map<String, String> DISTRICT_STATE_MAP = new LinkedHashMap<>();

    static {
        DISTRICT_STATE_MAP.put("Chittoor", "Andhra Pradesh");
        DISTRICT_STATE_MAP.put("East Godavari", "Andhra Pradesh");
        DISTRICT_STATE_MAP.put("Vijayawada", "Andhra Pradesh");
        DISTRICT_STATE_MAP.put("Vizag", "Andhra Pradesh");
        DISTRICT_STATE_MAP.put("West Godavari", "Andhra Pradesh");
        DISTRICT_STATE_MAP.put("Hyderabad", "Telangana");
        DISTRICT_STATE_MAP.put("Warangal", "Telangana");
    }

    // ─────────────────────────── Google Sign-In ───────────────────────────

    @Transactional
    public ResponseEntity<?> googleSignIn(String idToken) {
        if (!firebaseEnabled || firebaseApp == null) {
            log.warn("[AuthService] Firebase not configured. Google sign-in unavailable.");
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(ApiResponse.error("Firebase not configured in dev mode. Use /api/auth/login instead."));
        }

        String email;
        String name;
        try {
            FirebaseToken decoded = FirebaseAuth.getInstance(firebaseApp).verifyIdToken(idToken);
            email = decoded.getEmail();
            name = decoded.getName();
            log.info("[AuthService] Google sign-in verified for email={}", email);
        } catch (Exception e) {
            log.error("[AuthService] Firebase token verification failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Invalid or expired Google token."));
        }

        Optional<User> userOpt = userRepository.findByEmail(email);

        if (userOpt.isEmpty()) {
            log.info("[AuthService] New Google user. Requires details. email={}", email);
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("requires_details", true);
            data.put("email", email);
            data.put("name", name);
            return ResponseEntity.ok(ApiResponse.ok("User not found. Please complete registration.", data));
        }

        User user = userOpt.get();

        if (user.getStatus() == User.Status.pending) {
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("status", "pending");
            return ResponseEntity.ok(ApiResponse.ok("Your account is pending admin approval.", data));
        }

        if (user.getStatus() == User.Status.rejected) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("Your account has been rejected. Please contact support."));
        }

        String token = jwtTokenProvider.generateToken(user.getId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user", safeUser(user));
        data.put("token", token);
        data.put("isNewUser", false);

        log.info("[AuthService] Google sign-in success for userId={}", user.getId());
        return ResponseEntity.ok(ApiResponse.ok("Login successful.", data));
    }

    // ─────────────────────────── Check Phone ───────────────────────────

    public ResponseEntity<?> checkPhone(String phone) {
        if (phone == null || phone.length() < 10) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Valid 10-digit phone number is required"));
        }
        boolean exists = userRepository.findByPhone(phone).isPresent();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("isExistingUser", exists);
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Register Details ───────────────────────────

    @Transactional
    public ResponseEntity<?> registerDetails(RegisterDetailsRequest req) {
        if (req == null || req.getIdToken() == null || req.getPhone() == null || req.getDistrict() == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Google Token, phone, and district are required"));
        }
        if (req.getPhone().length() < 10) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Valid 10-digit phone number is required"));
        }

        if (!firebaseEnabled || firebaseApp == null) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(ApiResponse.error("Firebase not configured in dev mode. Use /api/auth/login instead."));
        }

        String email;
        String name;
        try {
            FirebaseToken decoded = FirebaseAuth.getInstance(firebaseApp).verifyIdToken(req.getIdToken());
            email = decoded.getEmail();
            name = decoded.getName();
        } catch (Exception e) {
            log.error("[AuthService] Token verification failed during registerDetails: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Invalid or expired Google token."));
        }

        String state = DISTRICT_STATE_MAP.getOrDefault(req.getDistrict(), "Andhra Pradesh");

        // Check if phone already exists
        Optional<User> byPhone = userRepository.findByPhone(req.getPhone());
        if (byPhone.isPresent()) {
            User existingByPhone = byPhone.get();
            if (existingByPhone.getEmail() != null && !existingByPhone.getEmail().equalsIgnoreCase(email)) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(ApiResponse.error("This mobile number is already linked to a different Google account."));
            }
            existingByPhone.setEmail(email);
            if (existingByPhone.getName() == null) existingByPhone.setName(name);
            userRepository.save(existingByPhone);

            if (existingByPhone.getStatus() == User.Status.approved) {
                String token = jwtTokenProvider.generateToken(existingByPhone.getId());
                Map<String, Object> data = new LinkedHashMap<>();
                data.put("user", safeUser(existingByPhone));
                data.put("token", token);
                data.put("isNewUser", false);
                return ResponseEntity.ok(ApiResponse.ok("Account linked successfully", data));
            }

            Map<String, Object> data = new LinkedHashMap<>();
            data.put("status", existingByPhone.getStatus().name());
            return ResponseEntity.ok(ApiResponse.ok("Account linking requested. Waiting for Admin approval.", data));
        }

        // Check if email already exists
        Optional<User> byEmail = userRepository.findByEmail(email);
        if (byEmail.isPresent()) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(ApiResponse.error("An account with this email already exists but with a different phone number."));
        }

        // Create new user
        User newUser = User.builder()
                .name(name)
                .email(email)
                .phone(req.getPhone())
                .district(req.getDistrict())
                .state(state)
                .role(User.Role.user)
                .status(User.Status.pending)
                .build();
        User savedUser = userRepository.save(newUser);
        log.info("[AuthService] New user registered: email={}, phone={}", email, req.getPhone());

        // Notify admins
        try {
            List<User> admins = userRepository.findAllByRole(User.Role.admin);
            List<String> adminFcmTokens = admins.stream()
                    .map(User::getFcmToken)
                    .filter(t -> t != null && !t.isBlank())
                    .collect(Collectors.toList());

            Map<String, String> pushData = new HashMap<>();
            pushData.put("type", "pending_approval");
            pushData.put("userId", savedUser.getId().toString());

            pushNotificationService.sendPushToMany(
                    adminFcmTokens,
                    "New User Approval Required",
                    name + " (" + req.getPhone() + ") has registered and is waiting for your approval.",
                    pushData
            );
        } catch (Exception e) {
            log.warn("[AuthService] Failed to notify admins about new user: {}", e.getMessage());
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("status", "pending");
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Details submitted successfully. Waiting for Admin approval.", data));
    }

    // ─────────────────────────── Direct User Register (phone + password) ─────

    @Transactional
    public ResponseEntity<?> register(Map<String, String> body) {
        String phone = body.get("phone");
        String password = body.get("password");
        String name = body.get("name");
        String district = body.get("district");

        if (phone == null || phone.trim().length() < 10) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Valid 10-digit mobile number is required"));
        }
        if (password == null || password.trim().length() < 6) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Password must be at least 6 characters"));
        }
        if (name == null || name.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Full name is required"));
        }
        if (district == null || district.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("District is required"));
        }

        phone = phone.trim();
        name = name.trim();
        district = district.trim();

        if (userRepository.findByPhone(phone).isPresent()) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(ApiResponse.error("An account with this mobile number already exists"));
        }

        String state = DISTRICT_STATE_MAP.getOrDefault(district, "Andhra Pradesh");

        User newUser = User.builder()
                .name(name)
                .phone(phone)
                .passwordHash(passwordEncoder.encode(password))
                .district(district)
                .state(state)
                .role(User.Role.user)
                .status(User.Status.approved)
                .build();

        User savedUser = userRepository.save(newUser);
        log.info("[AuthService] New customer registered directly: phone={}, name={}", phone, name);

        String token = jwtTokenProvider.generateToken(savedUser.getId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user", safeUser(savedUser));
        data.put("token", token);
        data.put("isNewUser", true);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Registration successful", data));
    }

    // ─────────────────────────── User Login (phone) ───────────────────────────

    public ResponseEntity<?> userLogin(String phone, String password) {
        if (phone == null || password == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Phone and password are required"));
        }

        Optional<User> userOpt = userRepository.findByPhone(phone);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("No account found with this mobile number"));
        }

        User user = userOpt.get();

        if (user.getPasswordHash() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("This account has no password set. Please contact admin."));
        }

        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Incorrect password"));
        }

        String token = jwtTokenProvider.generateToken(user.getId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user", safeUser(user));
        data.put("token", token);
        data.put("isNewUser", false);

        log.info("[AuthService] User login success for phone={}", phone);
        return ResponseEntity.ok(ApiResponse.ok("Login successful", data));
    }

    // ─────────────────────────── Admin Login (email) ───────────────────────────

    public ResponseEntity<?> adminLogin(String email, String password) {
        if (email == null || password == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Email and password are required"));
        }

        Optional<User> userOpt = userRepository.findByEmail(email);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Invalid credentials"));
        }

        User user = userOpt.get();

        if (user.getPasswordHash() == null || !passwordEncoder.matches(password, user.getPasswordHash())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Invalid credentials"));
        }

        String token = jwtTokenProvider.generateToken(user.getId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user", safeUser(user));
        data.put("token", token);

        log.info("[AuthService] Admin login success for email={}", email);
        return ResponseEntity.ok(ApiResponse.ok("Login successful", data));
    }

    // ─────────────────────────── Forgot Password ───────────────────────────

    @Transactional
    public ResponseEntity<?> forgotPassword(String phone, String newPassword) {
        if (phone == null || newPassword == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Phone and new password are required"));
        }
        if (newPassword.length() < 6) {
            return ResponseEntity.badRequest().body(ApiResponse.error("New password must be at least 6 characters"));
        }

        Optional<User> userOpt = userRepository.findByPhone(phone);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("No account found with this mobile number"));
        }

        User user = userOpt.get();
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        log.info("[AuthService] Password reset for phone={}", phone);
        return ResponseEntity.ok(ApiResponse.ok("Password reset successfully"));
    }

    // ─────────────────────────── Get Profile ───────────────────────────

    public ResponseEntity<?> getProfile(User user) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user", safeUser(user));
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Update Profile ───────────────────────────

    @Transactional
    public ResponseEntity<?> updateProfile(UpdateProfileRequest req, User user) {
        if (req.getName() != null) user.setName(req.getName());
        if (req.getPhone() != null) user.setPhone(req.getPhone());
        if (req.getEmail() != null) user.setEmail(req.getEmail());
        if (req.getAddress() != null) user.setAddress(req.getAddress());
        if (req.getPincode() != null) user.setPincode(req.getPincode());

        if (req.getDistrict() != null) {
            user.setDistrict(req.getDistrict());
            String resolvedState = DISTRICT_STATE_MAP.get(req.getDistrict());
            if (resolvedState != null) {
                user.setState(resolvedState);
            } else if (req.getState() != null) {
                user.setState(req.getState());
            }
        } else if (req.getState() != null) {
            user.setState(req.getState());
        }

        User saved = userRepository.save(user);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user", safeUser(saved));
        log.info("[AuthService] Profile updated for userId={}", user.getId());
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Change Password ───────────────────────────

    @Transactional
    public ResponseEntity<?> changePassword(ChangePasswordRequest req, User user) {
        if (req.getCurrentPassword() == null || req.getNewPassword() == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Current and new password are required"));
        }
        if (req.getNewPassword().length() < 6) {
            return ResponseEntity.badRequest().body(ApiResponse.error("New password must be at least 6 characters"));
        }

        if (user.getPasswordHash() != null) {
            if (!passwordEncoder.matches(req.getCurrentPassword(), user.getPasswordHash())) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.error("Current password is incorrect"));
            }
        }

        user.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        userRepository.save(user);

        log.info("[AuthService] Password changed for userId={}", user.getId());
        return ResponseEntity.ok(ApiResponse.ok("Password changed successfully"));
    }

    // ─────────────────────────── Update FCM Token ───────────────────────────

    @Transactional
    public ResponseEntity<?> updateFcmToken(String fcmToken, User user) {
        user.setFcmToken(fcmToken);
        userRepository.save(user);
        log.info("[AuthService] FCM token updated for userId={}", user.getId());
        return ResponseEntity.ok(ApiResponse.ok("FCM token updated"));
    }

    // ─────────────────────────── Get Districts ───────────────────────────

    public ResponseEntity<?> getDistricts() {
        List<Map<String, String>> districts = DISTRICT_STATE_MAP.entrySet().stream()
                .map(entry -> {
                    Map<String, String> d = new LinkedHashMap<>();
                    d.put("district", entry.getKey());
                    d.put("state", entry.getValue());
                    d.put("label", entry.getKey() + ", " + entry.getValue());
                    return d;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(districts));
    }

    // ─────────────────────────── Request Phone Update ───────────────────────────

    @Transactional
    public ResponseEntity<?> requestPhoneUpdate(String newPhone, User user) {
        if (newPhone == null || newPhone.length() < 10) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Valid 10-digit phone number is required"));
        }

        user.setPendingPhone(newPhone);
        userRepository.save(user);

        // Notify admins
        try {
            List<User> admins = userRepository.findAllByRole(User.Role.admin);
            List<String> adminFcmTokens = admins.stream()
                    .map(User::getFcmToken)
                    .filter(t -> t != null && !t.isBlank())
                    .collect(Collectors.toList());

            Map<String, String> pushData = new HashMap<>();
            pushData.put("type", "phone_update_request");
            pushData.put("userId", user.getId().toString());
            pushData.put("newPhone", newPhone);

            pushNotificationService.sendPushToMany(
                    adminFcmTokens,
                    "Phone Update Request",
                    (user.getName() != null ? user.getName() : user.getPhone())
                            + " has requested to update their phone number to " + newPhone + ".",
                    pushData
            );
        } catch (Exception e) {
            log.warn("[AuthService] Failed to notify admins about phone update: {}", e.getMessage());
        }

        log.info("[AuthService] Phone update requested for userId={}, newPhone={}", user.getId(), newPhone);
        return ResponseEntity.ok(ApiResponse.ok("Your request for phone number update has been sent to admin for approval."));
    }

    // ─────────────────────────── Helper: safeUser ───────────────────────────

    public Map<String, Object> safeUser(User u) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", u.getId() != null ? u.getId().toString() : "");
        map.put("name", u.getName() != null ? u.getName() : "");
        map.put("email", u.getEmail() != null ? u.getEmail() : "");
        map.put("phone", u.getPhone() != null ? u.getPhone() : "");
        map.put("address", u.getAddress());
        map.put("district", u.getDistrict() != null ? u.getDistrict() : "");
        map.put("state", u.getState() != null ? u.getState() : "Andhra Pradesh");
        map.put("pincode", u.getPincode());
        map.put("role", u.getRole() != null ? u.getRole().name() : "user");
        map.put("fcmToken", u.getFcmToken());
        map.put("status", u.getStatus() != null ? u.getStatus().name() : "approved");
        map.put("pendingPhone", u.getPendingPhone());
        map.put("createdAt", u.getCreatedAt());
        map.put("updatedAt", u.getUpdatedAt());
        return map;
    }
}
