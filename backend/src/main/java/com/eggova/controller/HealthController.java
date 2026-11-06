package com.eggova.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Tag(name = "Health", description = "Server availability and heartbeat probes")
@RestController
@RequestMapping("/api")
public class HealthController {

    @Operation(summary = "System Health Check", description = "Returns server status and UTC timestamp")
    @GetMapping("/health")
    public ResponseEntity<?> health() {
        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("status", "ok");
        resp.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(resp);
    }
}
