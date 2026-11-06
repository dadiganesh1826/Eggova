package com.eggova.dto.request;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class SetPriceRequest {
    private String district;
    private BigDecimal pricePerEgg;
    private BigDecimal pricePerTray;
    private String priceDate; // "YYYY-MM-DD" or null for today
}

