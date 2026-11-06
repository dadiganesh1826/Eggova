package com.eggova.dto.request;

import lombok.Data;

@Data
public class PlaceOrderRequest {
    private Integer trayCount;
    private String paymentMethod;
}

