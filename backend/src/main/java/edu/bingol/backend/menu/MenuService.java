package edu.bingol.backend.menu;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class MenuService {

    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final int MIN_YEAR = 2000;
    private static final int MAX_YEAR = 2100;

    private final MenuRepository repo;

    public MenuService(MenuRepository repo) {
        this.repo = repo;
    }

    public List<MenuResponse> month(YearMonth month) {
        return repo.findByMenuDateBetweenOrderByMenuDate(month.atDay(1), month.atEndOfMonth())
                .stream().map(MenuResponse::of).toList();
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

    public Optional<MenuResponse> today() {
        return repo.findByMenuDate(LocalDate.now(ZONE)).map(MenuResponse::of);
    }
}
