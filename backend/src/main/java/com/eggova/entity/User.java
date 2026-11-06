package com.eggova.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(unique = true)
    private String email;

    @Column(nullable = false, unique = true, length = 15)
    private String phone;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Column(nullable = false)
    private String district;

    @Column(nullable = false)
    @Builder.Default
    private String state = "Andhra Pradesh";

    @Column(length = 10)
    private String pincode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private Role role = Role.user;

    @Column(name = "fcm_token")
    private String fcmToken;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private Status status = Status.approved;

    @Column(name = "pending_phone", length = 15)
    private String pendingPhone;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public enum Role {
        admin, user
    }

    public enum Status {
        pending, approved, rejected
    }
}

