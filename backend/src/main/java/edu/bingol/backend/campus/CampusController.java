package edu.bingol.backend.campus;

import edu.bingol.backend.campus.CampusDtos.MapConfig;
import edu.bingol.backend.campus.CampusDtos.PlaceList;
import edu.bingol.backend.campus.CampusDtos.PlaceView;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.Lang;
import java.time.Duration;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Kampus haritasi (giris gerekli). Yalniz kampus yerleri doner; kampus disi arama yoktur. Sozlesme: docs/CAMPUS_MAP.md.
 * Cache-Control (private) ve ETag ortak yapilandirmadan gelir (PublicCacheInterceptor, WebConfig).
 */
@RestController
@RequestMapping("/api/campus")
public class CampusController {

    private final CampusService service;
    private final RateLimiter limiter;

    public CampusController(CampusService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/map")
    public MapConfig map() {
        limit();
        return service.map(Lang.of(LocaleContextHolder.getLocale()));
    }

    /** GET /api/campus/places?category=faculty&q=mü&limit=50 */
    @GetMapping("/places")
    public PlaceList places(@RequestParam(required = false) String category,
                            @RequestParam(required = false) String q,
                            @RequestParam(required = false) Integer limit) {
        limit();
        return service.places(category, q, limit);
    }

    @GetMapping("/places/{id}")
    public PlaceView place(@PathVariable Long id) {
        limit();
        return service.place(id);
    }

    private void limit() {
        limiter.check("campus:read:" + CurrentUser.id(), 120, Duration.ofMinutes(1));
    }
}
