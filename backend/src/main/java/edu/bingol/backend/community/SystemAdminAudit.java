package edu.bingol.backend.community;

import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Sistem yoneticisi KULLANICI API'sinde (kulup/etkinlik/anket/gonderi) uyelik-sahiplik olmadan yetkisini kullandiginda
 * admin_audit'e satir yazar (T-040). Yonetici API'si (/api/admin/**) kendi denetimini AuditInterceptor ile yazar; bu
 * yardimci yalniz {@link Actor#viaUserApi()} olan actor icin calisir. Hata asla istegi bozmaz; ayri islemde yazilir
 * (cagiranin islemi geri alinsa da, PostgreSQL'de yazim hatasi cagiran islemi zehirlemesin diye).
 */
@Component
public class SystemAdminAudit {

    private static final Logger log = LoggerFactory.getLogger(SystemAdminAudit.class);

    private static final int MAX = 500;

    private final JdbcTemplate jdbc;
    private final ClientIp clientIp;

    public SystemAdminAudit(JdbcTemplate jdbc, ClientIp clientIp) {
        this.jdbc = jdbc;
        this.clientIp = clientIp;
    }

    /** Null-guvenli statik kisayol (servislerde denetim bean'i istege baglidir: birim testleri). */
    public static void used(SystemAdminAudit audit, Actor a, String targetType, Object targetId, String summary) {
        if (audit != null && a != null && a.viaUserApi()) {
            audit.record(a, targetType, targetId, summary);
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(Actor a, String targetType, Object targetId, String summary) {
        try {
            HttpServletRequest req = request();
            String method = req == null ? "SYSTEM" : req.getMethod();
            String path = req == null ? "-" : req.getRequestURI();
            String ip = req == null ? null : clientIp.of(req);
            // admin_audit'e dogrudan ekleme (AuditRepository yonetici panelinin; burada yalniz ekleme yeterli)
            jdbc.update("INSERT INTO admin_audit (admin_id, admin_email, method, path, status, ip, target_type, target_id, "
                    + "summary, request_id) VALUES (?, (SELECT email FROM app_user WHERE id = ?), ?, ?, ?, ?, ?, ?, ?, ?)",
                    a.id(), a.id(), clip(method, 8), clip(path, 300), 200, clip(ip, 64), clip(targetType, 32),
                    targetId == null ? null : clip(String.valueOf(targetId), 64),
                    clip("sistem-yonetici-mudahalesi: " + summary, MAX), clip(MDC.get("requestId"), 64));
        } catch (RuntimeException e) {
            log.warn("Sistem yoneticisi denetim kaydi yazilamadi: {}", e.toString());
        }
    }

    private static String clip(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }

    private static HttpServletRequest request() {
        RequestAttributes ra = RequestContextHolder.getRequestAttributes();
        return ra instanceof ServletRequestAttributes sra ? sra.getRequest() : null;
    }
}
