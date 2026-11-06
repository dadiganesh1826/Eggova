package com.eggova.controller;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.OfflineOrderRequest;
import com.eggova.entity.User;
import com.eggova.service.AdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Tag(name = "Admin Management", description = "Endpoints restricted to administrators for managing user approvals, phone update requests, offline sales, and dashboard analytics")
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    // ── Helper ───────────────────────────────────────────────────────────────

    private User requireAdmin(Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Admin access required");
        }
        return user;
    }

    // ── Users ────────────────────────────────────────────────────────────────

    @Operation(summary = "Get All Users", description = "List all registered regular users")
    @GetMapping("/users")
    public ResponseEntity<?> getAllUsers(Authentication auth) {
        requireAdmin(auth);
        return adminService.getAllUsers();
    }

    @Operation(summary = "Get Pending Users", description = "List registered users awaiting account approval")
    @GetMapping("/users/pending")
    public ResponseEntity<?> getPendingUsers(Authentication auth) {
        requireAdmin(auth);
        return adminService.getPendingUsers();
    }

    @Operation(summary = "Approve User", description = "Approve a user account and send FCM approval notification")
    @PutMapping("/users/{id}/approve")
    public ResponseEntity<?> approveUser(@PathVariable String id, Authentication auth) {
        requireAdmin(auth);
        return adminService.approveUser(UUID.fromString(id));
    }

    @Operation(summary = "Reject User", description = "Reject and delete a pending user registration")
    @PutMapping("/users/{id}/reject")
    public ResponseEntity<?> rejectUser(@PathVariable String id, Authentication auth) {
        requireAdmin(auth);
        return adminService.rejectUser(UUID.fromString(id));
    }

    @Operation(summary = "Get Pending Phone Updates", description = "List all pending user phone number change requests")
    @GetMapping("/users/pending-phone")
    public ResponseEntity<?> getPendingPhoneUpdates(Authentication auth) {
        requireAdmin(auth);
        return adminService.getPendingPhoneUpdates();
    }

    @Operation(summary = "Approve Phone Update", description = "Approve a user's requested new phone number")
    @PutMapping("/users/{id}/approve-phone")
    public ResponseEntity<?> approvePhone(@PathVariable String id, Authentication auth) {
        requireAdmin(auth);
        return adminService.approvePhone(UUID.fromString(id));
    }

    @Operation(summary = "Reject Phone Update", description = "Reject a user's requested phone number change")
    @PutMapping("/users/{id}/reject-phone")
    public ResponseEntity<?> rejectPhone(@PathVariable String id, Authentication auth) {
        requireAdmin(auth);
        return adminService.rejectPhone(UUID.fromString(id));
    }

    // ── Payments ─────────────────────────────────────────────────────────────

    @Operation(summary = "Get Pending Payments", description = "List all orders with pending or approval-pending payment statuses")
    @GetMapping("/pending-payments")
    public ResponseEntity<?> getPendingPayments(Authentication auth) {
        requireAdmin(auth);
        return adminService.getPendingPayments();
    }

    @Operation(summary = "Get Completed Payments", description = "List all orders with completed payment status")
    @GetMapping("/completed-payments")
    public ResponseEntity<?> getCompletedPayments(Authentication auth) {
        requireAdmin(auth);
        return adminService.getCompletedPayments();
    }

    @Operation(summary = "Approve Pending Payment", description = "Approve an order payment claimed by user")
    @PostMapping("/approve-payment/{orderId}")
    public ResponseEntity<?> approvePayment(@PathVariable String orderId, Authentication auth) {
        requireAdmin(auth);
        return adminService.approvePayment(UUID.fromString(orderId));
    }

    // ── Dashboard & Offline Orders ───────────────────────────────────────────

    @Operation(summary = "Get Dashboard Stats", description = "Aggregated KPI stats: users, orders, revenue, pending amounts")
    @GetMapping("/dashboard")
    public ResponseEntity<?> getDashboardStats(Authentication auth) {
        requireAdmin(auth);
        return adminService.getDashboardStats();
    }

    @Operation(summary = "Record Offline Order", description = "Record cash/pay-later sale directly to walk-in farm customers")
    @PostMapping("/place-offline-order")
    public ResponseEntity<?> placeOfflineOrder(@RequestBody OfflineOrderRequest req, Authentication auth) {
        User adminUser = requireAdmin(auth);
        return adminService.placeOfflineOrder(req, adminUser);
    }
}
