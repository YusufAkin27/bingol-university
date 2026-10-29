package edu.bingol.backend.menu;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.menu.dto.MenuCalorieDtos.BulkDay;
import edu.bingol.backend.menu.dto.MenuCalorieDtos.BulkResult;
import edu.bingol.backend.menu.dto.MenuCalorieDtos.Entry;
import edu.bingol.backend.menu.dto.MenuCalorieDtos.Skipped;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yemek kalorileri: okuma (menu cevabina eklemek icin) ve yonetici yazimi. Senkron (MenuSyncService) bu sinifi
 * KULLANMAZ ve kalori tablosuna yazmaz; yonetici degeri her zaman onceliklidir.
 */
@Service
public class MenuCalorieService {

    public static final int MAX_KCAL = 5000;
    public static final int MAX_ITEMS_PER_DAY = 60;
    public static final int MAX_DAYS = 62;
    private static final int MAX_SKIPPED_REPORTED = 100;

    private final MenuItemCalorieRepository cal;
    private final MenuRepository days;

    public MenuCalorieService(MenuItemCalorieRepository cal, MenuRepository days) {
        this.cal = cal;
        this.days = days;
    }

    /** Tarih -> (yemek anahtari -> kcal). Aralik cagiran tarafindan sinirlidir. */
    @Transactional(readOnly = true)
    public Map<LocalDate, Map<String, Integer>> range(LocalDate from, LocalDate to) {
        Map<LocalDate, Map<String, Integer>> out = new HashMap<>();
        for (MenuItemCalorie c : cal.findByMenuDateBetween(from, to)) {
            out.computeIfAbsent(c.getMenuDate(), d -> new HashMap<>()).put(c.getItemKey(), c.getKcal());
        }
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, Integer> forDate(LocalDate date) {
        Map<String, Integer> out = new HashMap<>();
        for (MenuItemCalorie c : cal.findByMenuDate(date)) {
            out.put(c.getItemKey(), c.getKcal());
        }
        return out;
    }

    /** Tek gun, SIKI: bilinmeyen gun 404, gunde olmayan yemek 400; gecersiz kalori 400. Gunun guncel cevabini doner. */
    @Transactional
    public MenuResponse applyDay(LocalDate date, List<Entry> entries) {
        List<Entry> list = checked(entries);
        MenuDay day = days.findByMenuDate(date).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "MENU_DAY_NOT_FOUND", "Bu tarih için menü kaydı bulunamadı."));
        Counters c = new Counters();
        applyToDay(day, list, true, c, new ArrayList<>());
        AuditContext.target("MENU", date).summary("kalori: " + c.summary());
        return MenuResponse.of(day, forDate(date));
    }

    /** Toplu, GEVSEK: uygulanamayan satirlar atlanir ve raporlanir; gecersiz kalori tum istegi reddeder. */
    @Transactional
    public BulkResult applyBulk(List<BulkDay> request) {
        if (request == null || request.isEmpty() || request.size() > MAX_DAYS) {
            throw limit();
        }
        Map<LocalDate, List<Entry>> byDate = new LinkedHashMap<>();
        for (BulkDay d : request) {
            if (d == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_DATE_INVALID",
                        "Tarih yyyy-MM-dd biçiminde olmalıdır.");
            }
            LocalDate date = MenuAdminService.parseDate(d.date());
            byDate.computeIfAbsent(date, k -> new ArrayList<>()).addAll(checked(d.items()));
        }
        Counters c = new Counters();
        List<Skipped> skipped = new ArrayList<>();
        for (Map.Entry<LocalDate, List<Entry>> e : byDate.entrySet()) {
            MenuDay day = days.findByMenuDate(e.getKey()).orElse(null);
            if (day == null) {
                for (Entry en : e.getValue()) {
                    skip(skipped, c, e.getKey(), en.name(), "DAY_NOT_FOUND");
                }
                continue;
            }
            applyToDay(day, e.getValue(), false, c, skipped);
        }
        AuditContext.target("MENU", null).summary("toplu kalori: " + c.summary() + ", gün: " + byDate.size());
        return new BulkResult(c.updated, c.cleared, c.unchanged, skipped);
    }

    // ---- ic ----

    private static ApiException limit() {
        return new ApiException(HttpStatus.BAD_REQUEST, "MENU_KCAL_LIMIT",
                "Tek istekte en çok {0} gün ve gün başına {1} yemek güncellenebilir.",
                String.valueOf(MAX_DAYS), String.valueOf(MAX_ITEMS_PER_DAY));
    }

    private List<Entry> checked(List<Entry> entries) {
        if (entries == null || entries.isEmpty() || entries.size() > MAX_ITEMS_PER_DAY) {
            throw limit();
        }
        for (Entry e : entries) {
            if (e == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_ITEM_NOT_FOUND",
                        "Bu yemek, ilgili günün menüsünde bulunamadı.");
            }
            if (e.kcal() != null && (e.kcal() < 0 || e.kcal() > MAX_KCAL)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_KCAL_INVALID",
                        "Kalori 0 ile {0} arasında bir tam sayı olmalıdır.", String.valueOf(MAX_KCAL));
            }
        }
        return entries;
    }

    private void applyToDay(MenuDay day, List<Entry> entries, boolean strict, Counters c, List<Skipped> skipped) {
        LocalDate date = day.getMenuDate();
        Map<String, String> dayNames = new LinkedHashMap<>();
        for (String it : day.getItems().split("\n")) {
            dayNames.putIfAbsent(MenuItemKey.of(it), it.trim());
        }
        Map<String, MenuItemCalorie> existing = new HashMap<>();
        for (MenuItemCalorie row : cal.findByMenuDate(date)) {
            existing.put(row.getItemKey(), row);
        }
        String actor = actor();
        for (Entry en : entries) {
            String key = MenuItemKey.of(en.name());
            String display = key.isEmpty() ? null : dayNames.get(key);
            if (display == null) {
                if (strict) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_ITEM_NOT_FOUND",
                            "Bu yemek, ilgili günün menüsünde bulunamadı.");
                }
                skip(skipped, c, date, en.name(), key.isEmpty() ? "NAME_INVALID" : "ITEM_NOT_FOUND");
                continue;
            }
            MenuItemCalorie row = existing.get(key);
            if (en.kcal() == null) {
                if (row == null) {
                    c.unchanged++;
                } else {
                    cal.delete(row);
                    existing.remove(key);
                    c.cleared++;
                }
            } else if (row != null && row.getKcal() == en.kcal()) {
                c.unchanged++;
            } else {
                if (row == null) {
                    row = new MenuItemCalorie();
                    row.setMenuDate(date);
                    row.setItemKey(key);
                    existing.put(key, row);
                }
                row.setItemName(display.length() > 300 ? display.substring(0, 300) : display);
                row.setKcal(en.kcal());
                row.setUpdatedAt(Instant.now());
                row.setUpdatedBy(actor);
                cal.save(row);
                c.updated++;
            }
        }
        cal.flush();
    }

    private static void skip(List<Skipped> skipped, Counters c, LocalDate date, String name, String reason) {
        c.skipped++;
        if (skipped.size() < MAX_SKIPPED_REPORTED) {
            String n = name == null ? null : (name.length() > 120 ? name.substring(0, 120) : name);
            skipped.add(new Skipped(date.toString(), n, reason));
        }
    }

    private static String actor() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null) {
            return null;
        }
        return a.getPrincipal() instanceof Long id ? "admin:" + id : "basic-admin";
    }

    private static final class Counters {
        int updated;
        int cleared;
        int unchanged;
        int skipped;

        String summary() {
            return "güncel " + updated + ", silinen " + cleared + ", değişmeyen " + unchanged
                    + (skipped > 0 ? ", atlanan " + skipped : "");
        }
    }
}
