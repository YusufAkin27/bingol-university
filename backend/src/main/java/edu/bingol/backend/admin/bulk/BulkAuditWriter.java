package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.AuditRepository;
import edu.bingol.backend.admin.AuditRepository.Details;
import edu.bingol.backend.admin.bulk.BulkDtos.Result;
import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * Toplu islemde basarili her kayit icin AYRI denetim satiri yazar (sanal yol: /api/admin/{alan}/{id}/{fiil}); boylece
 * kaydin kendi denetim izinde toplu islem de gorunur. Istegin kendi satirini AuditInterceptor yazar. Hata istegi bozmaz.
 * Bekleyen kayitlarda kimlik ZATEN maskelidir (tam e-posta denetim satirina yazilmaz).
 */
@Component
public class BulkAuditWriter {

    private static final Logger log = LoggerFactory.getLogger(BulkAuditWriter.class);

    private final AuditRepository repo;
    private final ClientIp clientIp;

    public BulkAuditWriter(AuditRepository repo, ClientIp clientIp) {
        this.repo = repo;
        this.clientIp = clientIp;
    }

    /** `pathPrefix` ornek "/api/admin/news"; satir yolu prefix + "/" + id + "/" + verb. */
    public void items(HttpServletRequest req, String targetType, String pathPrefix, String verb, String reason,
                      List<Result> results) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        Long adminId = auth != null && auth.getPrincipal() instanceof Long l ? l : null;
        String fallback = adminId == null && auth != null ? "basic-admin" : null;
        String ip = clientIp.of(req);
        String rid = MDC.get("requestId");
        for (Result r : results) {
            if (!BulkSupport.DONE.equals(r.status())) {
                continue;
            }
            try {
                repo.insert(adminId, fallback, "POST", pathPrefix + "/" + r.id() + "/" + verb, 200, ip,
                        new Details(targetType, r.id(), reason, "toplu " + verb + ": basarili", rid));
            } catch (RuntimeException e) {
                log.warn("Toplu islem denetim satiri yazilamadi: {} {} {}", targetType, r.id(), e.toString());
            }
        }
    }
}
