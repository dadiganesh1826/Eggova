package com.eggova.controller;

import com.eggova.service.PaymentService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Tag(name = "Webhooks", description = "Asynchronous webhook callbacks from payment gateways (Razorpay)")
@RestController
@RequestMapping("/api/webhooks")
@RequiredArgsConstructor
@Slf4j
public class WebhookController {

    private final PaymentService paymentService;
    private final ObjectMapper objectMapper;

    @Operation(summary = "Razorpay Webhook Handler", description = "Process real-time payment capture and failure webhooks verifying HMAC-SHA256 signature")
    @PostMapping
    public ResponseEntity<String> handleWebhook(
            @RequestHeader(value = "X-Razorpay-Signature", required = false) String signature,
            @RequestBody(required = false) byte[] rawBody) {
        try {
            if (rawBody == null || rawBody.length == 0) {
                return ResponseEntity.badRequest().body("Invalid request body");
            }

            if (signature != null && !paymentService.verifyWebhookSignature(rawBody, signature)) {
                return ResponseEntity.badRequest().body("Invalid signature");
            }

            Map<String, Object> payload = objectMapper.readValue(rawBody, Map.class);
            String event = (String) payload.get("event");
            log.info("Received Razorpay Webhook: {}", event);

            paymentService.handleWebhookPayload(payload);

            return ResponseEntity.ok("OK");
        } catch (Exception e) {
            log.error("Webhook processing error: {}", e.getMessage());
            return ResponseEntity.internalServerError().body("Internal Server Error");
        }
    }
}
