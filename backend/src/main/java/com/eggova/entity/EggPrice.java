package com.eggova.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "egg_prices")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EggPrice {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false)
    private String district;

    @Column(name = "price_per_egg", nullable = false, precision = 10, scale = 2)
    private BigDecimal pricePerEgg;

    @Column(name = "price_per_tray", nullable = false, precision = 10, scale = 2)
    private BigDecimal pricePerTray;

    @Column(name = "price_date", nullable = false)
    private LocalDate priceDate;

    @Column(name = "set_by", nullable = false)
    private UUID setBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}

