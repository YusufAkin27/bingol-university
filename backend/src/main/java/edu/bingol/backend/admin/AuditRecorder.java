package edu.bingol.backend.admin;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/** Denetim kaydi yazar; hata asla istegi bozmaz (yalnizca log'lanir). Govde ve sorgu dizgesi kaydedilmez. */
@Component
public class AuditRecorder {

    private static final Logger log = LoggerFactory.getLogger(AuditRecorder.class);

    private final AuditRepository repo;

    public AuditRecorder(AuditRepository repo) {
        this.repo = repo;
    }

    /** Denetlenecek mi: GET/HEAD/OPTIONS disindaki tum yonetici istekleri + kisisel veri iceren CSV disa aktarimi. */
    static boolean shouldAudit(String method, String path) {
        boolean write = !method.equals("GET") && !method.equals("HEAD") && !method.equals("OPTIONS");
        return write || path.endsWith("/export.csv");
    }

    public void record(HttpServletRequest req, Authentication auth, int status) {
        try {
            Long adminId = auth != null && auth.getPrincipal() instanceof Long l ? l : null;
            // Basic auth yoneticisinde kullanici kaydi yoktur: kullanici adi e-posta alanina yazilir
            String fallback = adminId == null && auth != null ? auth.getName() : null;
            repo.insert(adminId, fallback, req.getMethod(), req.getRequestURI(), status, req.getRemoteAddr());
        } catch (RuntimeException e) {
            log.warn("Denetim kaydi yazilamadi: {}", e.toString());
        }
    }
}
