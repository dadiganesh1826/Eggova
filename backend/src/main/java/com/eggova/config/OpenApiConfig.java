package com.eggova.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    private static final String SECURITY_SCHEME_NAME = "bearerAuth";

    @Bean
    public OpenAPI eggovaOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Eggova API - Poultry Farm Management System")
                        .description("Official REST API documentation for Eggova poultry farm management platform. "
                                + "Provides authentication, daily NECC egg price tracking, stock management, order handling, "
                                + "Razorpay UPI integration, admin approval workflows, and push notifications.")
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("Eggova Support Team")
                                .email("support@eggova.com")
                                .url("https://eggova.com"))
                        .license(new License()
                                .name("Proprietary")
                                .url("https://eggova.com/terms")))
                .servers(List.of(
                        new Server().url("/").description("Current Server Context"),
                        new Server().url("http://localhost:3000").description("Local Development (Port 3000)"),
                        new Server().url("http://localhost:8080").description("Local Docker / Spring Boot (Port 8080)")
                ))
                // Attach security globally so authorized requests pass the JWT automatically in Swagger
                .addSecurityItem(new SecurityRequirement().addList(SECURITY_SCHEME_NAME))
                .components(new Components()
                        .addSecuritySchemes(SECURITY_SCHEME_NAME,
                                new SecurityScheme()
                                        .name(SECURITY_SCHEME_NAME)
                                        .type(SecurityScheme.Type.HTTP)
                                        .scheme("bearer")
                                        .bearerFormat("JWT")
                                        .description("Enter your JWT token (without 'Bearer ' prefix). Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")));
    }
}

