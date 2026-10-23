package edu.bingol.backend.menu;

import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class MenuService {

    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private final MenuRepository repo;

    public MenuService(MenuRepository repo) {
        this.repo = repo;
    }

    public List<MenuResponse> month(YearMonth month) {
        return repo.findByMenuDateBetweenOrderByMenuDate(month.atDay(1), month.atEndOfMonth())
                .stream().map(MenuResponse::of).toList();
    }

    public YearMonth currentMonth() {
        return YearMonth.now(ZONE);
    }

    public Optional<MenuResponse> today() {
        return repo.findByMenuDate(LocalDate.now(ZONE)).map(MenuResponse::of);
    }
}
