package com.eggova.dto.request;

import lombok.Data;

@Data
public class SetStockRequest {
    private Integer totalTrays;
    private String date; // "YYYY-MM-DD" or null for today
}

