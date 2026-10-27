package edu.bingol.backend.catalog;

import edu.bingol.backend.catalog.CatalogService.Catalog;
import edu.bingol.backend.catalog.CatalogService.DepartmentHit;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.util.List;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Herkese acik akademik katalog (kayit ekrani kimlik dogrulamadan once kullanir). */
@RestController
@RequestMapping("/api/catalog")
public class CatalogController {

    private final CatalogService catalog;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public CatalogController(CatalogService catalog, RateLimiter limiter, ClientIp clientIp) {
        this.catalog = catalog;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** Tum katalog (fakulteler, bolumler, siniflar); ETag + 1 gun onbellek. */
    @GetMapping("/academic")
    public ResponseEntity<Catalog> academic(HttpServletRequest http) {
        limiter.check("catalog:ip:" + clientIp.of(http), 120, Duration.ofMinutes(1));
        return ResponseEntity.ok().cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePublic())
                .body(catalog.catalog());
    }

    /** Bolum arama: en cok 30 sonuc. */
    @GetMapping("/departments")
    public List<DepartmentHit> departments(@RequestParam(defaultValue = "") String q,
                                           @RequestParam(defaultValue = "30") int limit, HttpServletRequest http) {
        limiter.check("catalog:ip:" + clientIp.of(http), 120, Duration.ofMinutes(1));
        return catalog.search(q.length() > 80 ? q.substring(0, 80) : q, limit);
    }
}
