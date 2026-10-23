package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AuditRow;
import edu.bingol.backend.admin.AdminDtos.PageResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici islemleri denetim kaydi (en yeni once). */
@RestController
@RequestMapping("/api/admin")
public class AuditController {

    private final AuditRepository repo;

    public AuditController(AuditRepository repo) {
        this.repo = repo;
    }

    /** GET /api/admin/audit?page=&size=&adminId=&method=&q= */
    @GetMapping("/audit")
    public PageResponse<AuditRow> list(@RequestParam(required = false) Long adminId,
                                       @RequestParam(required = false) String method,
                                       @RequestParam(required = false) String q,
                                       @RequestParam(defaultValue = "0") int page,
                                       @RequestParam(defaultValue = "20") int size) {
        int s = Math.min(Math.max(size, 1), AdminUserService.MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        AuditRepository.Filter f = new AuditRepository.Filter(adminId, method, q);
        return PageResponse.of(repo.page(f, p, s), p, s, repo.count(f));
    }
}
