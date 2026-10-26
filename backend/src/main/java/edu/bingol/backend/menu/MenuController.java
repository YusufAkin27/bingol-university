package edu.bingol.backend.menu;

import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.YearMonth;
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

    private final MenuService menu;
    private final MenuSyncService sync;

    public MenuController(MenuService menu, MenuSyncService sync) {
        this.menu = menu;
        this.sync = sync;
    }

    /** GET /api/menu?month=2026-10 (varsayilan: icinde bulunulan ay). Gecersiz ay -> 400 MENU_MONTH_INVALID. */
    @GetMapping("/menu")
    public List<MenuResponse> month(@RequestParam(required = false) String month) {
        return menu.month(menu.resolveMonth(month));
    }

    @GetMapping("/menu/today")
    public ResponseEntity<MenuResponse> today() {
        return ResponseEntity.of(menu.today());
    }

    /** Manuel tetikleme (ADMIN). */
    @PostMapping("/admin/sync-menu")
    public Map<String, Integer> triggerSync() {
        return Map.of("changed", sync.sync());
    }
}
