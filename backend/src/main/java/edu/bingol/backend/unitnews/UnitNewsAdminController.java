package edu.bingol.backend.unitnews;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.unitnews.UnitNewsDtos.AdminPage;
import edu.bingol.backend.unitnews.UnitNewsDtos.DepartmentView;
import edu.bingol.backend.unitnews.UnitNewsDtos.HiddenRequest;
import edu.bingol.backend.unitnews.UnitNewsDtos.SourceUpdate;
import edu.bingol.backend.unitnews.UnitNewsDtos.SourceView;
import edu.bingol.backend.unitnews.UnitNewsDtos.SyncResult;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Birim haberleri yonetimi; /api/admin/** yalniz ADMIN (RBAC: content.read / content.write). */
@RestController
@RequestMapping("/api/admin/unit-news")
public class UnitNewsAdminController {

    private final UnitNewsAdminService service;
    private final RateLimiter limiter;

    public UnitNewsAdminController(UnitNewsAdminService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/sources")
    public List<SourceView> sources() {
        return service.sources();
    }

    @PutMapping("/sources/{code}")
    public SourceView update(@PathVariable String code, @Valid @RequestBody SourceUpdate body) {
        limiter.check("unitnews-admin:write", 120, Duration.ofHours(1));
        return service.update(code, body);
    }

    @GetMapping("/sources/{code}/departments")
    public List<DepartmentView> departments(@PathVariable String code) {
        return service.departments(code);
    }

    @PostMapping("/sources/{code}/sync")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public SyncResult sync(@PathVariable String code) {
        limiter.check("unitnews-admin:sync", 20, Duration.ofHours(1));
        return service.startSync(code);
    }

    @PostMapping("/sync")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public SyncResult syncAll() {
        limiter.check("unitnews-admin:sync", 20, Duration.ofHours(1));
        return service.startSync(null);
    }

    @GetMapping("/announcements")
    public AdminPage announcements(@RequestParam(required = false) String source,
                                   @RequestParam(required = false) String q,
                                   @RequestParam(required = false) Boolean hidden,
                                   @RequestParam(defaultValue = "0") int page,
                                   @RequestParam(defaultValue = "20") int size) {
        return service.announcements(source, q, hidden, page, size);
    }

    @PutMapping("/announcements/{id}/hidden")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void hidden(@PathVariable long id, @Valid @RequestBody HiddenRequest body) {
        limiter.check("unitnews-admin:write", 120, Duration.ofHours(1));
        service.setHidden(id, body.hidden());
    }
}
