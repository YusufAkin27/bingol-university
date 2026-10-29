package edu.bingol.backend.menu;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.menu.dto.MenuCalorieDtos;
import edu.bingol.backend.menu.dto.MenuImageResponse;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.Duration;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Yonetici menu fotografi uclari; /api/admin/** SecurityConfig'te yalniz ADMIN. */
@RestController
@RequestMapping("/api/admin/menu")
public class MenuAdminController {

    private final MenuAdminService service;
    private final MenuCalorieService calories;
    private final RateLimiter limiter;

    public MenuAdminController(MenuAdminService service, MenuCalorieService calories, RateLimiter limiter) {
        this.service = service;
        this.calories = calories;
        this.limiter = limiter;
    }

    @GetMapping
    public List<MenuResponse> list(@RequestParam(required = false) String from,
                                   @RequestParam(required = false) String to) {
        return service.list(from, to);
    }

    /** multipart alani "file"; jpg/png/webp. */
    @PutMapping("/{date}/image")
    public MenuImageResponse setImage(@PathVariable String date, @RequestParam("file") MultipartFile file) {
        limiter.check("menu-image:admin", 60, Duration.ofHours(1));
        return service.setImage(MenuAdminService.parseDate(date), file);
    }

    @DeleteMapping("/{date}/image")
    public ResponseEntity<Void> deleteImage(@PathVariable String date) {
        limiter.check("menu-image:admin", 60, Duration.ofHours(1));
        service.deleteImage(MenuAdminService.parseDate(date));
        return ResponseEntity.noContent().build();
    }

    /** Tek gun kalorileri: {items:[{name, kcal|null}]}; kcal null = kaloriyi sil. Gunun guncel menusunu doner. */
    @PutMapping("/{date}/calories")
    public MenuResponse setCalories(@PathVariable String date, @RequestBody MenuCalorieDtos.DayRequest body) {
        limiter.check("menu-kcal:admin", 300, Duration.ofHours(1));
        return calories.applyDay(MenuAdminService.parseDate(date), body == null ? null : body.items());
    }

    /** Toplu kalori: {days:[{date, items:[{name, kcal|null}]}]}; uygulanamayan satirlar atlanir ve raporlanir. */
    @PutMapping("/calories")
    public MenuCalorieDtos.BulkResult setCaloriesBulk(@RequestBody MenuCalorieDtos.BulkRequest body) {
        limiter.check("menu-kcal:admin", 300, Duration.ofHours(1));
        return calories.applyBulk(body == null ? null : body.days());
    }
}
