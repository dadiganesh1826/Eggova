package com.eggova.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "daily_stock")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DailyStock {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false, unique = true)
    private LocalDate date;

    @Column(name = "total_trays", nullable = false)
    @Builder.Default
    private int totalTrays = 0;

    @Column(name = "sold_trays", nullable = false)
    @Builder.Default
    private int soldTrays = 0;

    @Column(name = "low_stock_notified")
    @Builder.Default
    private boolean lowStockNotified = false;

    @Column(name = "out_of_stock_notified")
    @Builder.Default
    private boolean outOfStockNotified = false;

    @Column(name = "set_by")
    private UUID setBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}

