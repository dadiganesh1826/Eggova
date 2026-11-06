package com.eggova.controller;

import com.eggova.dto.request.PlaceOrderRequest;
import com.eggova.entity.User;
import com.eggova.service.OrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Tag(name = "Orders", description = "Endpoints for placing and tracking egg tray orders")
@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @Operation(summary = "Place Order", description = "Place an order for egg trays validating available daily stock limit and current district price")
    @PostMapping("/place")
    public ResponseEntity<?> placeOrder(@RequestBody PlaceOrderRequest req, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return orderService.placeOrder(req, user);
    }

    @Operation(summary = "Order History", description = "Get list of all past orders placed by the current user")
    @GetMapping("/history")
    public ResponseEntity<?> getHistory(Authentication auth) {
        User user = (User) auth.getPrincipal();
        return orderService.getHistory(user);
    }

    @Operation(summary = "Get Order by ID", description = "Fetch details of a single order by UUID")
    @GetMapping("/{id}")
    public ResponseEntity<?> getOrder(@PathVariable String id, Authentication auth) {
        User user = (User) auth.getPrincipal();
        return orderService.getOrder(UUID.fromString(id), user);
    }
}
