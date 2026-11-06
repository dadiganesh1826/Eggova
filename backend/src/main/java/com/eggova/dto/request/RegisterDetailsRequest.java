package com.eggova.dto.request;

import lombok.Data;

@Data
public class RegisterDetailsRequest {
    private String idToken;
    private String phone;
    private String district;
}

