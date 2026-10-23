package edu.bingol.backend.menu;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class MenuController {

    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    public record MenuResponse(String date, List<String> items) {
        static MenuResponse of(MenuDay d) {
            return new MenuResponse(d.getMenuDate().toString(), List.of(d.getItems().split("\n")));
        }
    }

    private final MenuRepository repo;
    private final MenuSyncService sync;

    public MenuController(MenuRepository repo, MenuSyncService sync) {
        this.repo = repo;
        this.sync = sync;
    }

    /** GET /api/menu?month=2026-10 (varsayilan: icinde bulunulan ay) */
    @GetMapping("/menu")
    public ResponseEntity<List<MenuResponse>> month(@RequestParam(required = false) String month) {
        YearMonth ym;
        try {
            ym = month == null ? YearMonth.now(ZONE) : YearMonth.parse(month);
        } catch (DateTimeParseException e) {
            return ResponseEntity.badRequest().build();
        }
        return ResponseEntity.ok(repo.findByMenuDateBetweenOrderByMenuDate(ym.atDay(1), ym.atEndOfMonth())
                .stream().map(MenuResponse::of).toList());
    }

    @GetMapping("/menu/today")
    public ResponseEntity<MenuResponse> today() {
        return repo.findByMenuDate(LocalDate.now(ZONE)).map(d -> ResponseEntity.ok(MenuResponse.of(d)))
                .orElse(ResponseEntity.notFound().build());
    }

    /** Manuel tetikleme (kimlik dogrulama gerekir). */
    @PostMapping("/admin/sync-menu")
    public Map<String, Integer> triggerSync() {
        return Map.of("changed", sync.sync());
    }
}
