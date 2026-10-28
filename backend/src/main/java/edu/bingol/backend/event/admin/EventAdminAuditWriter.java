package edu.bingol.backend.event.admin;

import edu.bingol.backend.admin.AuditRepository;
import edu.bingol.backend.admin.AuditRepository.Details;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkAction;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkItem;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/**
 * Toplu islemde her etkinlik icin AYRI denetim satiri yazar (sanal yol /api/admin/events/{id}/hide|unhide|cancel);
 * boylece etkinligin kendi "Denetim" sekmesinde (targetType=EVENT, targetId) toplu islem de gorunur. Istegin kendi
 * satiri AuditInterceptor tarafindan yazilir. Hata asla istegi bozmaz.
 */
@Component
public class EventAdminAuditWriter {

    private static final Logger log = LoggerFactory.getLogger(EventAdminAuditWriter.class);

    private final AuditRepository repo;
    private final ClientIp clientIp;

    public EventAdminAuditWriter(AuditRepository repo, ClientIp clientIp) {
        this.repo = repo;
        this.clientIp = clientIp;
    }

    public void bulkItems(HttpServletRequest req, Authentication auth, BulkAction action, String reason, List<BulkItem> items) {
        Long adminId = auth != null && auth.getPrincipal() instanceof Long l ? l : null;
        String fallback = adminId == null && auth != null ? "basic-admin" : null;
        String ip = clientIp.of(req);
        String rid = MDC.get("requestId");
        String verb = action.name().toLowerCase(Locale.ROOT);
        for (BulkItem it : items) {
            try {
                String summary = "toplu " + action + (it.ok() ? ": basarili" : ": basarisiz " + it.error());
                repo.insert(adminId, fallback, "POST", "/api/admin/events/" + it.id() + "/" + verb, it.status(), ip,
                        new Details("EVENT", String.valueOf(it.id()), reason, summary, rid));
            } catch (RuntimeException e) {
                log.warn("Toplu islem denetim satiri yazilamadi: event={} {}", it.id(), e.toString());
            }
        }
    }
}
