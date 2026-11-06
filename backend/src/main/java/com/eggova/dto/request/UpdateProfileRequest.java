package com.eggova.dto.request;

import lombok.Data;

@Data
public class UpdateProfileRequest {
    private String name;
    private String phone;
    private String email;
    private String address;
    private String district;
    private String state;
    private String pincode;
}

