package edu.bingol.backend.menu;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;

@Service
@Transactional(readOnly = true)
public class MenuService {

    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final int MIN_YEAR = 2000;
    private static final int MAX_YEAR = 2100;

    private static final TypeReference<List<MenuResponse>> MONTH = new TypeReference<>() { };
    private static final TypeReference<MenuResponse> DAY = new TypeReference<>() { };

    private final MenuRepository repo;
    private final MenuCalorieService calories;
    private CacheService cache = CacheService.passthrough();

    public MenuService(MenuRepository repo, MenuCalorieService calories) {
        this.repo = repo;
        this.calories = calories;
    }

    /** Herkese ayni cevap: sunucu onbellegi `menu` ad alani (senkron ve kalori/gorsel yazmasinda gecersiz kilinir). */
    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
    }

    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public List<MenuResponse> month(YearMonth month) {
        // resolveMonth 2000-2100 araligini zorlar; yine de disaridan gelen aylar icin anahtar sinirli kalir
        if (month.getYear() < MIN_YEAR || month.getYear() > MAX_YEAR) {
            return load(month);
        }
        return cache.get("menu", "m:" + month, CacheTier.DAILY, MONTH, () -> load(month));
    }

    private List<MenuResponse> load(YearMonth month) {
        LocalDate from = month.atDay(1);
        LocalDate to = month.atEndOfMonth();
        Map<LocalDate, Map<String, Integer>> kcal = calories.range(from, to);
        return repo.findByMenuDateBetweenOrderByMenuDate(from, to).stream()
                .map(d -> MenuResponse.of(d, kcal.getOrDefault(d.getMenuDate(), Map.of()))).toList();
    }

    /** null/bos -> bu ay; yyyy-MM disi veya makul aralik (2000-2100) disi -> 400. */
    public YearMonth resolveMonth(String raw) {
        if (raw == null || raw.isBlank()) {
            return currentMonth();
        }
        try {
            YearMonth ym = YearMonth.parse(raw.trim());
            if (ym.getYear() < MIN_YEAR || ym.getYear() > MAX_YEAR) {
                throw new DateTimeParseException("out of range", raw, 0);
            }
            return ym;
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_MONTH_INVALID",
                    "Ay yyyy-MM biçiminde olmalıdır (örn. 2026-10).");
        }
    }

    public YearMonth currentMonth() {
        return YearMonth.now(ZONE);
    }

    /** Bugunun menusu; anahtar tarihi icerir (gun donumunde kendiliginden yenilenir). "Menu yok" kisa sure onbelleklenir. */
    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public Optional<MenuResponse> today() {
        LocalDate today = LocalDate.now(ZONE);
        return Optional.ofNullable(cache.get("menu", "d:" + today, CacheTier.DAILY, DAY,
                () -> repo.findByMenuDate(today).map(d -> MenuResponse.of(d, calories.forDate(today))).orElse(null)));
    }
}
