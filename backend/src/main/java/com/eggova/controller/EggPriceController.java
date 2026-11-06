package com.eggova.controller;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.SetPriceRequest;
import com.eggova.dto.request.SetStockRequest;
import com.eggova.entity.User;
import com.eggova.service.EggPriceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Egg Prices & Stock", description = "Endpoints for district egg rates, NECC scraper auto-sync, and farm stock limits")
@RestController
@RequestMapping("/api/egg-prices")
@RequiredArgsConstructor
public class EggPriceController {

    private final EggPriceService eggPriceService;

    // ── Public / User endpoints ──────────────────────────────────────────────

    @Operation(summary = "Get Current Price", description = "Get current day's egg price for user's district (or specified district)")
    @GetMapping("/current")
    public ResponseEntity<?> getCurrent(
            @RequestParam(required = false) String district,
            Authentication auth) {
        User user = (User) auth.getPrincipal();
        return eggPriceService.getCurrent(district, user);
    }

    @Operation(summary = "Get Today's Stock", description = "Fetch today's total, sold, and remaining egg trays available")
    @GetMapping("/stock-today")
    public ResponseEntity<?> getStockToday() {
        return eggPriceService.getStockToday();
    }

    // ── Admin-only endpoints ─────────────────────────────────────────────────

    @Operation(summary = "Set District Price (Admin)", description = "Set egg price per egg and per tray for a specific district and date")
    @PostMapping("/set")
    public ResponseEntity<?> setPrice(@RequestBody SetPriceRequest req, Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(403).body(ApiResponse.error("Admin access required"));
        }
        return eggPriceService.setPrice(req, user);
    }

    @Operation(summary = "Price History (Admin)", description = "Get price history records optionally filtered by district")
    @GetMapping("/history")
    public ResponseEntity<?> getHistory(
            @RequestParam(required = false) String district,
            Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(403).body(ApiResponse.error("Admin access required"));
        }
        return eggPriceService.getHistory(district);
    }

    @Operation(summary = "All Districts Today (Admin)", description = "Fetch today's egg rates across all 7 monitored districts")
    @GetMapping("/today-all")
    public ResponseEntity<?> getTodayAll(Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(403).body(ApiResponse.error("Admin access required"));
        }
        return eggPriceService.getTodayAll();
    }

    @Operation(summary = "Auto-fetch NECC Rates (Admin)", description = "Trigger real-time scraping of official e2necc.com monthly rate grid")
    @PostMapping("/auto-fetch")
    public ResponseEntity<?> autoFetch(Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(403).body(ApiResponse.error("Admin access required"));
        }
        return eggPriceService.autoFetch(user);
    }

    @Operation(summary = "Set Daily Stock (Admin)", description = "Configure daily inventory limit of egg trays")
    @PostMapping("/set-stock")
    public ResponseEntity<?> setStock(@RequestBody SetStockRequest req, Authentication auth) {
        User user = (User) auth.getPrincipal();
        if (user.getRole() != User.Role.admin) {
            return ResponseEntity.status(403).body(ApiResponse.error("Admin access required"));
        }
        return eggPriceService.setStock(req, user);
    }
}
