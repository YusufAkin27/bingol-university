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
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yemek kalorileri: okuma (menu cevabina eklemek icin) ve yonetici yazimi. Senkron (MenuSyncService) bu sinifi
 * KULLANMAZ ve kalori tablosuna yazmaz; yonetici degeri her zaman onceliklidir.
 *
 * <p>Kalori yemek adina da baglanir ({@link MenuDishCalorie}): yonetici bir gunun yemegine kalori girince deger "son
 * bilinen" olarak saklanir ve tarihe ozel satiri olmayan, ayni isimli yemekte (orn. gelecek ay menusu) otomatik
 * gorunur. Tarihe ozel satir her zaman onceliklidir; kalori silmek hem o gunun satirini hem son bilinen degeri siler.
 */
@Service
public class MenuCalorieService {

    public static final int MAX_KCAL = 5000;
    public static final int MAX_ITEMS_PER_DAY = 60;
    public static final int MAX_DAYS = 62;
    private static final int MAX_SKIPPED_REPORTED = 100;

    /** IN listesi parca boyu (yonetici araligi 366 gune kadar cikabilir). */
    private static final int KEY_CHUNK = 500;

    private final MenuItemCalorieRepository cal;
    private final MenuDishCalorieRepository dishes;
    private final MenuRepository days;
    private final MenuContentImages images;

    public MenuCalorieService(MenuItemCalorieRepository cal, MenuDishCalorieRepository dishes, MenuRepository days,
                              MenuContentImages images) {
        this.cal = cal;
        this.dishes = dishes;
        this.days = days;
        this.images = images;
    }

    /** Tarih -> (yemek anahtari -> kcal), yemek adi yedegi dahil. Aralik cagiran tarafindan sinirlidir. */
    @Transactional(readOnly = true)
    public Map<LocalDate, Map<String, Integer>> range(LocalDate from, LocalDate to) {
        Map<LocalDate, Map<String, Integer>> out = new HashMap<>();
        for (MenuItemCalorie c : cal.findByMenuDateBetween(from, to)) {
            out.computeIfAbsent(c.getMenuDate(), d -> new HashMap<>()).put(c.getItemKey(), c.getKcal());
        }
        List<MenuDay> list = days.findByMenuDateBetweenOrderByMenuDate(from, to);
        Map<String, Integer> fallback = fallbackFor(list);
        if (!fallback.isEmpty()) {
            for (MenuDay d : list) {
                fillMissing(out.computeIfAbsent(d.getMenuDate(), x -> new HashMap<>()), d, fallback);
            }
        }
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, Integer> forDate(LocalDate date) {
        Map<String, Integer> out = new HashMap<>();
        for (MenuItemCalorie c : cal.findByMenuDate(date)) {
            out.put(c.getItemKey(), c.getKcal());
        }
        days.findByMenuDate(date).ifPresent(d -> fillMissing(out, d, fallbackFor(List.of(d))));
        return out;
    }

    private static Set<String> keysOf(MenuDay day) {
        Set<String> keys = new LinkedHashSet<>();
        for (String it : day.getItems().split("\n")) {
            String k = MenuItemKey.of(it);
            if (!k.isEmpty()) {
                keys.add(k);
            }
        }
        return keys;
    }

    /** Verilen gunlerdeki yemeklerin yemek adina bagli son bilinen kalorileri. */
    private Map<String, Integer> fallbackFor(List<MenuDay> list) {
        Set<String> all = new LinkedHashSet<>();
        for (MenuDay d : list) {
            all.addAll(keysOf(d));
        }
        Map<String, Integer> out = new HashMap<>();
        List<String> keys = new ArrayList<>(all);
        for (int i = 0; i < keys.size(); i += KEY_CHUNK) {
            for (MenuDishCalorie d : dishes.findByItemKeyIn(keys.subList(i, Math.min(keys.size(), i + KEY_CHUNK)))) {
                out.put(d.getItemKey(), d.getKcal());
            }
        }
        return out;
    }

    private static void fillMissing(Map<String, Integer> target, MenuDay day, Map<String, Integer> fallback) {
        for (String k : keysOf(day)) {
            Integer v = fallback.get(k);
            if (v != null) {
                target.putIfAbsent(k, v);
            }
        }
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
        return MenuResponse.of(day, forDate(date), images.forDay(day));
    }

    /** Toplu, GEVSEK: uygulanamayan satirlar atlanir ve raporlanir; gecersiz kalori tum istegi reddeder. */
    @Transactional
    public BulkResult applyBulk(List<BulkDay> request) {
        if (request == null || request.isEmpty() || request.size() > MAX_DAYS) {
            throw limit();
        }
        // tarih sirasi: ayni yemek birden cok gunde gelirse en son tarihin degeri "son bilinen" olur
        Map<LocalDate, List<Entry>> byDate = new TreeMap<>();
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
        Map<String, MenuDishCalorie> dish = new HashMap<>();
        for (MenuDishCalorie d : dishes.findByItemKeyIn(dayNames.keySet())) {
            dish.put(d.getItemKey(), d);
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
            String shown = display.length() > 300 ? display.substring(0, 300) : display;
            if (en.kcal() == null) {
                // silme: son bilinen deger de gider, yoksa yemek sonraki aylarda yeniden dolardi
                MenuDishCalorie gone = dish.remove(key);
                if (gone != null) {
                    dishes.delete(gone);
                }
                if (row != null) {
                    cal.delete(row);
                    existing.remove(key);
                }
                if (row == null && gone == null) {
                    c.unchanged++;
                } else {
                    c.cleared++;
                }
                continue;
            }
            if (row != null && row.getKcal() == en.kcal()) {
                c.unchanged++;
            } else {
                if (row == null) {
                    row = new MenuItemCalorie();
                    row.setMenuDate(date);
                    row.setItemKey(key);
                    existing.put(key, row);
                }
                row.setItemName(shown);
                row.setKcal(en.kcal());
                row.setUpdatedAt(Instant.now());
                row.setUpdatedBy(actor);
                cal.save(row);
                c.updated++;
            }
            // yemek adina bagli son bilinen deger: son yazilan kazanir
            MenuDishCalorie known = dish.get(key);
            if (known == null) {
                known = new MenuDishCalorie();
                known.setItemKey(key);
                dish.put(key, known);
            } else if (known.getKcal() == en.kcal()) {
                continue;
            }
            known.setItemName(shown);
            known.setKcal(en.kcal());
            known.setUpdatedAt(Instant.now());
            known.setUpdatedBy(actor);
            dishes.save(known);
        }
        cal.flush();
        dishes.flush();
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
