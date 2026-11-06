package com.eggova.service;

import lombok.extern.slf4j.Slf4j;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class NeccScraperService {

    private static final String SOURCE_URL = "https://e2necc.com/home/eggprice";

    private static final Map<String, String> DISTRICT_MAPPING = new HashMap<>();

    static {
        DISTRICT_MAPPING.put("Chittoor", "Chittoor");
        DISTRICT_MAPPING.put("East Godavari", "E.Godavari");
        DISTRICT_MAPPING.put("Vijayawada", "Vijayawada");
        DISTRICT_MAPPING.put("Vizag", "Vizag");
        DISTRICT_MAPPING.put("West Godavari", "W.Godavari");
        DISTRICT_MAPPING.put("Hyderabad", "Hyderabad");
        DISTRICT_MAPPING.put("Warangal", "Warangal");
    }

    /**
     * Scrapes NECC egg rates from the source URL.
     *
     * @return Map of { appDistrict -> { dayOfMonth -> pricePerEgg } }
     * @throws IOException if scraping fails
     */
    public Map<String, Map<Integer, Double>> scrapeNeccRates() throws IOException {
        log.info("[NeccScraper] Starting scrape from {}", SOURCE_URL);

        Document doc = Jsoup.connect(SOURCE_URL)
                .userAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                .timeout(15000)
                .get();

        // Build reverse map: neccName -> appDistrict
        Map<String, String> reverseMap = new HashMap<>();
        for (Map.Entry<String, String> entry : DISTRICT_MAPPING.entrySet()) {
            reverseMap.put(entry.getValue().toLowerCase(), entry.getKey());
        }

        Map<String, Map<Integer, Double>> result = new HashMap<>();

        Elements rows = doc.select("table tr");
        log.info("[NeccScraper] Found {} table rows", rows.size());

        for (Element row : rows) {
            Elements cells = row.select("td");
            if (cells.size() <= 2) {
                continue;
            }

            String cityName = cells.get(0).text().trim();
            String appDistrict = reverseMap.get(cityName.toLowerCase());

            if (appDistrict == null) {
                log.debug("[NeccScraper] Skipping unrecognized city: '{}'", cityName);
                continue;
            }

            Map<Integer, Double> dailyPrices = new HashMap<>();

            for (int day = 1; day < cells.size(); day++) {
                String cellText = cells.get(day).text().trim();
                if (cellText.isEmpty() || cellText.equals("-") || cellText.equals("N/A")) {
                    continue;
                }
                try {
                    double pricePer100 = Double.parseDouble(cellText.replaceAll("[^0-9.]", ""));
                    double pricePerEgg = pricePer100 / 100.0;
                    dailyPrices.put(day, pricePerEgg);
                } catch (NumberFormatException e) {
                    log.warn("[NeccScraper] Could not parse price '{}' for city '{}' day {}", cellText, cityName, day);
                }
            }

            if (!dailyPrices.isEmpty()) {
                result.put(appDistrict, dailyPrices);
                log.info("[NeccScraper] Scraped {} entries for district '{}'", dailyPrices.size(), appDistrict);
            }
        }

        log.info("[NeccScraper] Scrape complete. Found data for {} districts.", result.size());
        return result;
    }
}
