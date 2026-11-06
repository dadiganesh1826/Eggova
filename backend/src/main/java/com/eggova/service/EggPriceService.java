package com.eggova.service;

import com.eggova.dto.ApiResponse;
import com.eggova.dto.request.SetPriceRequest;
import com.eggova.dto.request.SetStockRequest;
import com.eggova.entity.DailyStock;
import com.eggova.entity.EggPrice;
import com.eggova.entity.User;
import com.eggova.repository.DailyStockRepository;
import com.eggova.repository.EggPriceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.*;

@Service
@Slf4j
@RequiredArgsConstructor
public class EggPriceService {

    private final EggPriceRepository eggPriceRepository;
    private final DailyStockRepository dailyStockRepository;
    private final NeccScraperService neccScraperService;

    private static final List<String> ALL_DISTRICTS = Arrays.asList(
            "Chittoor", "East Godavari", "Vijayawada", "Vizag",
            "West Godavari", "Hyderabad", "Warangal"
    );

    // ─────────────────────────── Current Egg Price ───────────────────────────

    public ResponseEntity<?> getCurrent(String districtParam, User user) {
        String district = (districtParam != null && !districtParam.isBlank()) ? districtParam : user.getDistrict();
        LocalDate today = LocalDate.now();

        Optional<EggPrice> priceOpt = eggPriceRepository.findByDistrictAndPriceDate(district, today);
        if (priceOpt.isEmpty()) {
            priceOpt = eggPriceRepository.findFirstByDistrictOrderByPriceDateDesc(district);
        }

        if (priceOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("No egg price set for your district yet"));
        }

        EggPrice price = priceOpt.get();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("district", price.getDistrict());
        data.put("pricePerEgg", price.getPricePerEgg().doubleValue());
        data.put("pricePerTray", price.getPricePerTray().doubleValue());
        data.put("priceDate", price.getPriceDate());
        data.put("isToday", price.getPriceDate().equals(today));

        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    // ─────────────────────────── Set Egg Price ───────────────────────────

    @Transactional
    public ResponseEntity<?> setPrice(SetPriceRequest req, User user) {
        if (req.getDistrict() == null || req.getPricePerEgg() == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("District and pricePerEgg are required"));
        }

        LocalDate date = (req.getPriceDate() != null && !req.getPriceDate().isBlank())
                ? LocalDate.parse(req.getPriceDate())
                : LocalDate.now();

        BigDecimal trayPrice = req.getPricePerTray() != null
                ? req.getPricePerTray()
                : req.getPricePerEgg().multiply(BigDecimal.valueOf(30));

        eggPriceRepository.deleteByDistrictAndPriceDate(req.getDistrict(), date);

        EggPrice price = EggPrice.builder()
                .district(req.getDistrict())
                .pricePerEgg(req.getPricePerEgg())
                .pricePerTray(trayPrice)
                .priceDate(date)
                .setBy(user.getId())
                .build();

        EggPrice saved = eggPriceRepository.save(price);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Price set successfully", saved));
    }

    // ─────────────────────────── Price History ───────────────────────────

    public ResponseEntity<?> getHistory(String district) {
        List<EggPrice> prices;
        if (district != null && !district.isBlank()) {
            prices = eggPriceRepository.findAllByDistrictOrderByPriceDateDesc(district, PageRequest.of(0, 30));
        } else {
            prices = eggPriceRepository.findAllByOrderByPriceDateDesc(PageRequest.of(0, 30));
        }
        return ResponseEntity.ok(ApiResponse.ok(prices));
    }

    // ─────────────────────────── Today's Prices for All Districts ───────────────────────────

    public ResponseEntity<?> getTodayAll() {
        LocalDate today = LocalDate.now();
        List<EggPrice> prices = eggPriceRepository.findAllByPriceDateOrderByDistrictAsc(today);

        Map<String, EggPrice> priceMap = new HashMap<>();
        for (EggPrice p : prices) {
            priceMap.put(p.getDistrict(), p);
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (String d : ALL_DISTRICTS) {
            Map<String, Object> item = new LinkedHashMap<>();
            EggPrice ep = priceMap.get(d);
            if (ep != null) {
                item.put("id", ep.getId());
                item.put("district", ep.getDistrict());
                item.put("pricePerEgg", ep.getPricePerEgg().doubleValue());
                item.put("pricePerTray", ep.getPricePerTray().doubleValue());
                item.put("priceDate", ep.getPriceDate());
            } else {
                item.put("id", null);
                item.put("district", d);
                item.put("pricePerEgg", null);
                item.put("pricePerTray", null);
                item.put("priceDate", today);
            }
            result.add(item);
        }

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("data", result);
        res.put("date", today);
        return ResponseEntity.ok(ApiResponse.ok("Prices fetched", result));
    }

    // ─────────────────────────── Auto-fetch NECC Rates ───────────────────────────

    @Transactional
    public ResponseEntity<?> autoFetch(User user) {
        log.info("Admin triggered auto-fetch. Scraping NECC grid...");
        Map<String, Map<Integer, Double>> scrapedRates;
        try {
            scrapedRates = neccScraperService.scrapeNeccRates();
        } catch (Exception e) {
            log.error("Scraping error: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("Failed to fetch official NECC rates: " + e.getMessage()));
        }

        LocalDate now = LocalDate.now();
        int currentYear = now.getYear();
        int currentMonth = now.getMonthValue();

        List<Map<String, Object>> syncResults = new ArrayList<>();
        int totalUpdated = 0;

        for (String district : ALL_DISTRICTS) {
            Map<Integer, Double> dailyData = scrapedRates.get(district);
            if (dailyData != null) {
                int districtCount = 0;
                for (Map.Entry<Integer, Double> entry : dailyData.entrySet()) {
                    int day = entry.getKey();
                    double pricePerEgg = entry.getValue();

                    LocalDate date;
                    try {
                        date = LocalDate.of(currentYear, currentMonth, day);
                    } catch (DateTimeException ex) {
                        continue;
                    }

                    BigDecimal pEgg = BigDecimal.valueOf(pricePerEgg).setScale(2, RoundingMode.HALF_UP);
                    BigDecimal pTray = BigDecimal.valueOf(Math.round(pricePerEgg * 30));

                    eggPriceRepository.deleteByDistrictAndPriceDate(district, date);
                    EggPrice ep = EggPrice.builder()
                            .district(district)
                            .pricePerEgg(pEgg)
                            .pricePerTray(pTray)
                            .priceDate(date)
                            .setBy(user.getId())
                            .build();
                    eggPriceRepository.save(ep);
                    districtCount++;
                    totalUpdated++;
                }
                Map<String, Object> resItem = new LinkedHashMap<>();
                resItem.put("district", district);
                resItem.put("records", districtCount);
                syncResults.add(resItem);
            }
        }

        if (syncResults.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("No rates found on NECC source. Please check connectivity."));
        }

        return ResponseEntity.ok(ApiResponse.ok(
                "Successfully synchronized " + totalUpdated + " historical records for " + syncResults.size() + " districts.",
                syncResults
        ));
    }

    // ─────────────────────────── Stock Management ───────────────────────────

    @Transactional
    public ResponseEntity<?> setStock(SetStockRequest req, User user) {
        if (req.getTotalTrays() == null || req.getTotalTrays() < 0) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Please provide a valid tray count"));
        }

        LocalDate stockDate = (req.getDate() != null && !req.getDate().isBlank())
                ? LocalDate.parse(req.getDate())
                : LocalDate.now();

        Optional<DailyStock> stockOpt = dailyStockRepository.findByDate(stockDate);
        DailyStock stock;
        String message;

        if (stockOpt.isPresent()) {
            stock = stockOpt.get();
            if (req.getTotalTrays() < stock.getSoldTrays()) {
                return ResponseEntity.badRequest().body(ApiResponse.error(
                        "Cannot set below " + stock.getSoldTrays() + " (already sold). Increase to at least " + stock.getSoldTrays() + "."
                ));
            }
            if (req.getTotalTrays() > stock.getTotalTrays()) {
                message = "Stock limit increased to " + req.getTotalTrays() + " trays";
            } else if (req.getTotalTrays() < stock.getTotalTrays()) {
                message = "Stock limit reduced to " + req.getTotalTrays() + " trays";
            } else {
                message = "Stock limit updated";
            }
            stock.setTotalTrays(req.getTotalTrays());
            stock.setSetBy(user.getId());
        } else {
            stock = DailyStock.builder()
                    .date(stockDate)
                    .totalTrays(req.getTotalTrays())
                    .soldTrays(0)
                    .lowStockNotified(false)
                    .outOfStockNotified(false)
                    .setBy(user.getId())
                    .build();
            message = "Daily stock limit set to " + req.getTotalTrays() + " trays";
        }

        DailyStock saved = dailyStockRepository.save(stock);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("date", saved.getDate());
        data.put("totalTrays", saved.getTotalTrays());
        data.put("soldTrays", saved.getSoldTrays());
        data.put("remainingTrays", saved.getTotalTrays() - saved.getSoldTrays());
        data.put("isSet", true);

        return ResponseEntity.ok(ApiResponse.ok(message, data));
    }

    public ResponseEntity<?> getStockToday() {
        LocalDate today = LocalDate.now();
        Optional<DailyStock> stockOpt = dailyStockRepository.findByDate(today);

        Map<String, Object> data = new LinkedHashMap<>();
        if (stockOpt.isEmpty()) {
            data.put("date", today);
            data.put("totalTrays", 0);
            data.put("soldTrays", 0);
            data.put("remainingTrays", 0);
            data.put("isSet", false);
        } else {
            DailyStock stock = stockOpt.get();
            data.put("date", stock.getDate());
            data.put("totalTrays", stock.getTotalTrays());
            data.put("soldTrays", stock.getSoldTrays());
            data.put("remainingTrays", stock.getTotalTrays() - stock.getSoldTrays());
            data.put("isSet", true);
        }

        return ResponseEntity.ok(ApiResponse.ok(data));
    }
}

