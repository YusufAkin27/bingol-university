package edu.bingol.backend.moderation;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReportQueue;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReportView;
import edu.bingol.backend.moderation.dto.ModerationDtos.ResolveRequest;
import edu.bingol.backend.moderation.dto.ModerationDtos.Stats;
import edu.bingol.backend.moderation.dto.ModerationDtos.SuspendRequest;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici uclari (/api/admin/** zaten SecurityConfig'te ROLE_ADMIN ister). */
@RestController
@RequestMapping("/api/admin")
public class AdminModerationController {

    private final ReportService reports;
    private final ReportRepository reportRepo;
    private final UserModerationService userModeration;
    private final UserRepository users;
    private final NewsRepository news;

    public AdminModerationController(ReportService reports, ReportRepository reportRepo,
                                     UserModerationService userModeration, UserRepository users, NewsRepository news) {
        this.reports = reports;
        this.reportRepo = reportRepo;
        this.userModeration = userModeration;
        this.users = users;
        this.news = news;
    }

    /** GET /api/admin/reports?status=OPEN&order=asc|desc&cursor=&size=20 (varsayilan eskiden yeniye) */
    @GetMapping("/reports")
    public ReportQueue queue(@RequestParam(defaultValue = "OPEN") Report.Status status,
                             @RequestParam(defaultValue = "asc") String order,
                             @RequestParam(required = false) Long cursor,
                             @RequestParam(defaultValue = "20") int size) {
        int s = CursorPage.clampSize(size);
        List<Report> rows = reports.queue(status, cursor, s, "desc".equalsIgnoreCase(order));
        CursorPage<ReportView> page = CursorPage.of(rows, s, Report::getId, ReportView::of);
        return new ReportQueue(page.items(), page.nextCursor());
    }

    @PostMapping("/reports/{id}/resolve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resolve(@PathVariable Long id, @Valid @RequestBody ResolveRequest r, Authentication auth) {
        // Basic auth ile giren yonetici icin principal Long degildir; karar veren id'si bos kalir.
        Long adminId = auth.getPrincipal() instanceof Long l ? l : null;
        reports.resolve(id, adminId, r.action(), r.message());
    }

    @PostMapping("/users/{id}/suspend")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void suspend(@PathVariable Long id, @Valid @RequestBody SuspendRequest r) {
        userModeration.suspend(id, r.reason());
    }

    @PostMapping("/users/{id}/unsuspend")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unsuspend(@PathVariable Long id) {
        userModeration.unsuspend(id);
    }

    @GetMapping("/stats")
    public Stats stats() {
        return new Stats(users.count(), users.countByStatus(UserStatus.ACTIVE), users.countByStatus(UserStatus.SUSPENDED),
                reportRepo.countByStatus(Report.Status.OPEN), news.count());
    }
}
