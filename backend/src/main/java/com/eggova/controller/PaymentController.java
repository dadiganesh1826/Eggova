package com.eggova.controller;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.VerifyPaymentRequest;
import com.eggova.entity.User;
import com.eggova.service.PaymentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Tag(name = "Payments", description = "Endpoints for Razorpay order generation, signature verification, and payment completion workflows")
@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    @Operation(summary = "Create Razorpay Order", description = "Generate Razorpay order for online UPI payment checkout")
    @PostMapping("/create-razorpay")
    public ResponseEntity<?> createRazorpayOrder(@RequestBody Map<String, String> body, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return paymentService.createRazorpayOrder(UUID.fromString(body.get("orderId")), user);
    }

    @Operation(summary = "Verify Razorpay Payment", description = "Verify HMAC-SHA256 signature and mark order confirmed and paid")
    @PostMapping("/verify")
    public ResponseEntity<?> verifyPayment(@RequestBody VerifyPaymentRequest req, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return paymentService.verifyPayment(req, user);
    }

    @Operation(summary = "Cancel UPI Order", description = "Cancel an abandoned or failed UPI order")
    @PostMapping("/cancel-upi")
    public ResponseEntity<?> cancelUpiOrder(@RequestBody Map<String, String> body, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return paymentService.cancelUpiOrder(UUID.fromString(body.get("orderId")), user);
    }

    @Operation(summary = "Request Payment Completion", description = "User claims payment for pay-later order, submitting request for admin approval")
    @PostMapping("/request-completion")
    public ResponseEntity<?> requestCompletion(@RequestBody Map<String, String> body, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return paymentService.requestCompletion(
                UUID.fromString(body.get("orderId")),
                body.get("paidVia"),
                user);
    }

    @Operation(summary = "Mark Paid (Admin)", description = "Admin marks payment as completed for an order")
    @PostMapping("/mark-paid")
    public ResponseEntity<?> markPaid(@RequestBody Map<String, String> body, Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(403).body(ApiResponse.error("Admin access required"));
        }
        return paymentService.markPaid(
                UUID.fromString(body.get("orderId")),
                body.get("paidVia"),
                user);
    }
}
