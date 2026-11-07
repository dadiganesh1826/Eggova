package com.eggova.config;

import com.eggova.entity.DailyStock;
import com.eggova.entity.EggPrice;
import com.eggova.entity.User;
import com.eggova.repository.DailyStockRepository;
import com.eggova.repository.EggPriceRepository;
import com.eggova.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Controlled database seeder.
 * Runs only when app.seed.enabled=true (enabled for local development / testing).
 * Never logs raw passwords to console or logs for security.
 */
@Component
@ConditionalOnProperty(name = "app.seed.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
@Slf4j
public class DatabaseSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final EggPriceRepository eggPriceRepository;
    private final DailyStockRepository dailyStockRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.admin.email:admin@eggova.com}")
    private String adminEmail;

    @Value("${app.admin.password:admin123}")
    private String adminPassword;

    @Value("${app.seed.demo-customer:false}")
    private boolean seedDemoCustomer;

    @Override
    public void run(String... args) {
        log.info("[DatabaseSeeder] Checking initial data configuration...");

        // ── 1. Seed or Update Admin (Credentials never printed to logs) ──
        var adminOpt = userRepository.findFirstByRole(User.Role.admin);
        User admin;
        if (adminOpt.isEmpty()) {
            admin = User.builder()
                    .name("Admin Superuser")
                    .email(adminEmail)
                    .phone("0000000000")
                    .passwordHash(passwordEncoder.encode(adminPassword))
                    .role(User.Role.admin)
                    .district("Chittoor")
                    .state("Andhra Pradesh")
                    .status(User.Status.approved)
                    .build();
            admin = userRepository.save(admin);
            log.info("[DatabaseSeeder] Default Admin account initialized for email: {}", adminEmail);
        } else {
            admin = adminOpt.get();
            boolean emailChanged = !adminEmail.equals(admin.getEmail());
            boolean passwordChanged = !passwordEncoder.matches(adminPassword, admin.getPasswordHash());
            if (emailChanged || passwordChanged) {
                admin.setEmail(adminEmail);
                admin.setPasswordHash(passwordEncoder.encode(adminPassword));
                admin = userRepository.save(admin);
                log.info("[DatabaseSeeder] Admin credentials updated from secure environment properties.");
            }
        }

        // ── 2. Optional Demo Customer for local testing (Controlled by flag) ──
        if (seedDemoCustomer && userRepository.findByPhone("9999999999").isEmpty()) {
            User demoUser = User.builder()
                    .name("Demo Customer")
                    .email("customer@eggova.com")
                    .phone("9999999999")
                    .passwordHash(passwordEncoder.encode("user123"))
                    .role(User.Role.user)
                    .district("Chittoor")
                    .state("Andhra Pradesh")
                    .status(User.Status.approved)
                    .build();
            userRepository.save(demoUser);
            log.info("[DatabaseSeeder] Demo customer seeded for local testing.");
        }

        // ── 3. Seed Today's Stock and Egg Rate if missing ──
        LocalDate today = LocalDate.now();
        if (dailyStockRepository.findByDate(today).isEmpty()) {
            DailyStock stock = DailyStock.builder()
                    .date(today)
                    .totalTrays(300)
                    .soldTrays(0)
                    .setBy(admin.getId())
                    .build();
            dailyStockRepository.save(stock);
            log.info("[DatabaseSeeder] Today's initial stock initialized: 300 trays.");
        }

        if (eggPriceRepository.findByDistrictAndPriceDate("Chittoor", today).isEmpty()) {
            EggPrice price = EggPrice.builder()
                    .district("Chittoor")
                    .pricePerEgg(BigDecimal.valueOf(5.50))
                    .pricePerTray(BigDecimal.valueOf(165.00))
                    .priceDate(today)
                    .setBy(admin.getId())
                    .build();
            eggPriceRepository.save(price);
            log.info("[DatabaseSeeder] Today's initial egg price initialized for Chittoor.");
        }

        log.info("[DatabaseSeeder] Initialization complete.");
    }
}

