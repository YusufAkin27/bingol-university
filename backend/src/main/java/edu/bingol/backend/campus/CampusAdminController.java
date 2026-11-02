package edu.bingol.backend.campus;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.campus.CampusDtos.AdminPlace;
import edu.bingol.backend.campus.CampusDtos.AdminPlacePage;
import edu.bingol.backend.campus.CampusDtos.ConfigRequest;
import edu.bingol.backend.campus.CampusDtos.DeleteResult;
import edu.bingol.backend.campus.CampusDtos.MapConfig;
import edu.bingol.backend.campus.CampusDtos.PlaceRequest;
import edu.bingol.backend.common.RateLimiter;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Yonetici: kampus haritasi yerleri ve ayari (izin: campus.read / campus.write; AdminPermissionPolicy).
 * Yazmalar AuditInterceptor ile denetlenir; silme GEREKCE ister. Sozlesme: docs/CAMPUS_MAP.md.
 */
@RestController
@RequestMapping("/api/admin/campus")
public class CampusAdminController {

    private final CampusAdminService service;
    private final RateLimiter limiter;

    public CampusAdminController(CampusAdminService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/places")
    public AdminPlacePage list(@RequestParam(required = false) String category,
                               @RequestParam(required = false) String q,
                               @RequestParam(defaultValue = "0") int page,
                               @RequestParam(defaultValue = "50") int size) {
        return service.list(category, q, page, size);
    }

    @GetMapping("/places/{id}")
    public AdminPlace get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping("/places")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminPlace create(@Valid @RequestBody PlaceRequest r) {
        write();
        return service.create(r);
    }

    @PutMapping("/places/{id}")
    public AdminPlace update(@PathVariable Long id, @Valid @RequestBody PlaceRequest r) {
        write();
        return service.update(id, r);
    }

    /** Yumusak silme; gerekce zorunlu (X-Admin-Reason basligi ya da govdede reason). */
    @AdminReasonRequired
    @DeleteMapping("/places/{id}")
    public DeleteResult delete(@PathVariable Long id) {
        write();
        return service.delete(id);
    }

    @PostMapping("/places/{id}/photo")
    public AdminPlace setPhoto(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        write();
        return service.setPhoto(id, file);
    }

    @DeleteMapping("/places/{id}/photo")
    public AdminPlace removePhoto(@PathVariable Long id) {
        write();
        return service.removePhoto(id);
    }

    @GetMapping("/config")
    public MapConfig config() {
        return service.config();
    }

    @PutMapping("/config")
    public MapConfig updateConfig(@Valid @RequestBody ConfigRequest r) {
        write();
        return service.updateConfig(r);
    }

    private void write() {
        limiter.check("admin:campus:w:" + actor(), 120, Duration.ofHours(1));
    }

    private static String actor() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
    }
}
