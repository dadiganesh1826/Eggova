package com.eggova.dto.request;

import lombok.Data;

@Data
public class OfflineOrderRequest {
    private Integer trayCount;
    private String customerName;
    private String customerPhone;
    private String paymentMethod; // "cash" or "pay_later"
}

