package edu.bingol.backend.community.category;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.category.CommunityCategoryDtos.ActiveRequest;
import edu.bingol.backend.community.category.CommunityCategoryDtos.AdminCategory;
import edu.bingol.backend.community.category.CommunityCategoryDtos.AdminList;
import edu.bingol.backend.community.category.CommunityCategoryDtos.OrderRequest;
import edu.bingol.backend.community.category.CommunityCategoryDtos.SaveRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici kulup kategorisi uclari (/api/admin/** => ROLE_ADMIN; yazmalar AuditInterceptor ile denetlenir). */
@RestController
@RequestMapping("/api/admin/community-categories")
public class CommunityCategoryAdminController {

    private final CommunityCategoryService service;
    private final RateLimiter limiter;

    public CommunityCategoryAdminController(CommunityCategoryService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public AdminList list() {
        return service.adminList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminCategory create(@Valid @RequestBody SaveRequest r) {
        write();
        return service.create(r);
    }

    // "order" sabit yolu {id}'den once eslesir (Spring daha belirgin kalibi secer).
    @PutMapping("/order")
    public AdminList reorder(@Valid @RequestBody OrderRequest r) {
        write();
        return service.reorder(r.ids());
    }

    @PutMapping("/{id}")
    public AdminCategory update(@PathVariable Long id, @Valid @RequestBody SaveRequest r) {
        write();
        return service.update(id, r);
    }

    @PatchMapping("/{id}/active")
    public AdminCategory active(@PathVariable Long id, @Valid @RequestBody ActiveRequest r) {
        write();
        return service.setActive(id, r.active());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        write();
        service.delete(id);
    }

    private void write() {
        Long id;
        try {
            id = CurrentUser.id();
        } catch (RuntimeException e) {
            id = -1L; // Basic auth yoneticisi
        }
        limiter.check("community-category:admin:" + id, 120, Duration.ofMinutes(1));
    }
}
