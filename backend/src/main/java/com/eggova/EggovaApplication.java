package com.eggova;

import com.eggova.entity.User;
import com.eggova.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.security.crypto.password.PasswordEncoder;

@SpringBootApplication
@EnableScheduling
@Slf4j
public class EggovaApplication {

    public static void main(String[] args) {
        SpringApplication.run(EggovaApplication.class, args);
    }

    @Bean
    public CommandLineRunner adminSeeder(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            @Value("${app.admin.email:admin@eggova.com}") String adminEmail,
            @Value("${app.admin.password:admin123}") String adminPassword) {
        return args -> {
            var adminOpt = userRepository.findFirstByRole(User.Role.admin);
            if (adminOpt.isEmpty()) {
                User admin = User.builder()
                        .name("Admin Superuser")
                        .email(adminEmail)
                        .phone("0000000000")
                        .passwordHash(passwordEncoder.encode(adminPassword))
                        .role(User.Role.admin)
                        .district("Admin District")
                        .state("Admin State")
                        .status(User.Status.approved)
                        .build();
                userRepository.save(admin);
                log.info("✅ Default Admin created from config");
            } else {
                User admin = adminOpt.get();
                boolean emailChanged = !adminEmail.equals(admin.getEmail());
                boolean passwordChanged = !passwordEncoder.matches(adminPassword, admin.getPasswordHash());
                if (emailChanged || passwordChanged) {
                    admin.setEmail(adminEmail);
                    admin.setPasswordHash(passwordEncoder.encode(adminPassword));
                    userRepository.save(admin);
                    log.info("✅ Admin credentials updated from config");
                }
            }
            log.info("🚀 Eggova API is running!");
        };
    }
}
