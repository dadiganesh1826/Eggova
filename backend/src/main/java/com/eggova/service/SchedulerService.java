package com.eggova.service;

import com.eggova.entity.EggPrice;
import com.eggova.entity.User;
import com.eggova.repository.EggPriceRepository;
import com.eggova.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@Slf4j
@RequiredArgsConstructor
public class SchedulerService {

    private final EggPriceRepository eggPriceRepository;
    private final UserRepository userRepository;
    private final NeccScraperService neccScraperService;

    private static final List<String> ALL_DISTRICTS = Arrays.asList(
            "Chittoor", "East Godavari", "Vijayawada", "Vizag",
            "West Godavari", "Hyderabad", "Warangal"
    );

    @Scheduled(cron = "0 0 6 * * *", zone = "Asia/Kolkata")
    @Transactional
    public void dailyNeccSync() {
        log.info("[SchedulerService] Starting daily NECC sync at {}", LocalDateTime.now());

        Optional<User> adminOpt = userRepository.findFirstByRole(User.Role.admin);
        if (adminOpt.isEmpty()) {
            log.error("[SchedulerService] No admin user found. Cannot perform NECC sync.");
            return;
        }
        User admin = adminOpt.get();

        Map<String, Map<Integer, Double>> scraped;
        try {
            scraped = neccScraperService.scrapeNeccRates();
        } catch (Exception e) {
            log.error("[SchedulerService] Failed to scrape NECC rates: {}", e.getMessage(), e);
            return;
        }

        LocalDate now = LocalDate.now();
        int currentYear = now.getYear();
        int currentMonth = now.getMonthValue();
        int totalSaved = 0;

        for (String district : ALL_DISTRICTS) {
            Map<Integer, Double> districtRates = scraped.get(district);
            if (districtRates == null || districtRates.isEmpty()) {
                log.warn("[SchedulerService] No scraped rates for district '{}'", district);
                continue;
            }

            for (Map.Entry<Integer, Double> entry : districtRates.entrySet()) {
                int day = entry.getKey();
                double pricePerEggDouble = entry.getValue();

                LocalDate date;
                try {
                    date = LocalDate.of(currentYear, currentMonth, day);
                } catch (DateTimeException e) {
                    continue;
                }

                BigDecimal pricePerEgg = BigDecimal.valueOf(pricePerEggDouble).setScale(2, RoundingMode.HALF_UP);
                BigDecimal pricePerTray = BigDecimal.valueOf(Math.round(pricePerEggDouble * 30));

                eggPriceRepository.deleteByDistrictAndPriceDate(district, date);

                EggPrice eggPrice = EggPrice.builder()
                        .district(district)
                        .pricePerEgg(pricePerEgg)
                        .pricePerTray(pricePerTray)
                        .priceDate(date)
                        .setBy(admin.getId())
                        .build();

                eggPriceRepository.save(eggPrice);
                totalSaved++;
            }
        }

        log.info("[SchedulerService] Daily NECC sync completed. Total records saved: {}", totalSaved);
    }
}
