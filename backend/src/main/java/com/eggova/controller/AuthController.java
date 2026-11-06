package com.eggova.controller;

import com.eggova.dto.request.ChangePasswordRequest;
import com.eggova.dto.request.RegisterDetailsRequest;
import com.eggova.dto.request.UpdateProfileRequest;
import com.eggova.entity.User;
import com.eggova.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Tag(name = "Authentication", description = "Endpoints for user registration, Google OAuth, mobile login, password recovery, and profile updates")
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "Google Sign-In", description = "Verify Firebase ID token and authenticate or request additional details")
    @PostMapping("/google")
    public ResponseEntity<?> googleSignIn(@RequestBody Map<String, String> body) {
        return authService.googleSignIn(body.get("idToken"));
    }

    @Operation(summary = "Check Phone Exists", description = "Checks whether a 10-digit phone number is already registered")
    @PostMapping("/check-phone")
    public ResponseEntity<?> checkPhone(@RequestBody Map<String, String> body) {
        return authService.checkPhone(body.get("phone"));
    }

    @Operation(summary = "Register Details", description = "Complete profile registration after Google Sign-In with phone and district")
    @PostMapping("/register-details")
    public ResponseEntity<?> registerDetails(@RequestBody RegisterDetailsRequest req) {
        return authService.registerDetails(req);
    }

    @Operation(summary = "User Mobile Login", description = "Authenticate an approved user via phone number and password")
    @PostMapping("/user-login")
    public ResponseEntity<?> userLogin(@RequestBody Map<String, String> body) {
        return authService.userLogin(body.get("phone"), body.get("password"));
    }

    @Operation(summary = "Admin Email Login", description = "Authenticate administrator via email and password")
    @PostMapping("/login")
    public ResponseEntity<?> adminLogin(@RequestBody Map<String, String> body) {
        return authService.adminLogin(body.get("email"), body.get("password"));
    }

    @Operation(summary = "Forgot Password", description = "Reset user password using registered mobile number")
    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, String> body) {
        return authService.forgotPassword(body.get("phone"), body.get("newPassword"));
    }

    @Operation(summary = "Get Profile", description = "Fetch currently authenticated user's profile details")
    @GetMapping("/profile")
    public ResponseEntity<?> getProfile(Authentication auth) {
        User user = (User) auth.getPrincipal();
        return authService.getProfile(user);
    }

    @Operation(summary = "Update Profile", description = "Update current user's profile data (name, email, address, district, state, pincode)")
    @PutMapping("/profile")
    public ResponseEntity<?> updateProfile(@RequestBody UpdateProfileRequest req, Authentication auth) {
        return authService.updateProfile(req, (User) auth.getPrincipal());
    }

    @Operation(summary = "Change Password", description = "Change user account password verifying current password")
    @PutMapping("/change-password")
    public ResponseEntity<?> changePassword(@RequestBody ChangePasswordRequest req, Authentication auth) {
        return authService.changePassword(req, (User) auth.getPrincipal());
    }

    @Operation(summary = "Update FCM Token", description = "Update Firebase Cloud Messaging device token for push notifications")
    @PutMapping("/fcm-token")
    public ResponseEntity<?> updateFcmToken(@RequestBody Map<String, String> body, Authentication auth) {
        return authService.updateFcmToken(body.get("fcmToken"), (User) auth.getPrincipal());
    }

    @Operation(summary = "List Districts", description = "Get list of supported poultry rate districts and their states")
    @GetMapping("/districts")
    public ResponseEntity<?> getDistricts() {
        return authService.getDistricts();
    }

    @Operation(summary = "Request Phone Update", description = "Submit a request to update phone number, requiring admin approval")
    @PostMapping("/request-phone-update")
    public ResponseEntity<?> requestPhoneUpdate(@RequestBody Map<String, String> body, Authentication auth) {
        return authService.requestPhoneUpdate(body.get("newPhone"), (User) auth.getPrincipal());
    }
}
