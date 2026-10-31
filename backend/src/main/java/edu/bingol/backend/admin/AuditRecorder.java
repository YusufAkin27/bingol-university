package edu.bingol.backend.admin;

import edu.bingol.backend.admin.rbac.AdminPermissionPolicy;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/** Denetim kaydi yazar; hata asla istegi bozmaz (yalnizca log'lanir). Govde ve sorgu dizgesi kaydedilmez (yalniz sebep + ozet). */
@Component
public class AuditRecorder {

    private static final Logger log = LoggerFactory.getLogger(AuditRecorder.class);

    /**
     * users.pii izniyle korunmayan ama kisisel veri okuyan GET uclari (T-016): strike gecmisi, destek talepleri
     * (e-posta + mesaj), posta kuyrugu (alici adresi). users.pii ile eslenen uclar {@link #personalDataRead} ile gelir.
     */
    private static final Pattern PERSONAL_READS = Pattern.compile(
            "^/api/admin/(users/[^/]+/strikes|support/tickets(/[^/]+)?|mail/outbox(/[^/]+)?)$");

    private final AuditRepository repo;

    private final ClientIp clientIp;

    public AuditRecorder(AuditRepository repo, ClientIp clientIp) {
        this.clientIp = clientIp;
        this.repo = repo;
    }

    /**
     * Denetlenecek mi: GET/HEAD/OPTIONS disindaki tum yonetici istekleri + kisisel veri iceren CSV disa aktarimi +
     * kisisel veri okuyan GET'ler. `path` {@link AdminPaths#of} ile COZULMUS yol olmalidir.
     */
    public static boolean shouldAudit(String method, String path) {
        boolean write = !method.equals("GET") && !method.equals("HEAD") && !method.equals("OPTIONS");
        // T8: yonetici sohbet gorseli onizlemesi (GET) de kisisel icerik gosterir -> denetlenir
        // Erisim engeli listesi/istatistigi ve kullanici cihaz/IP gecmisi (kisisel veri) goruntulemesi de denetlenir
        boolean accessBan = path.startsWith("/api/admin/access-bans")
                || (path.startsWith("/api/admin/users/") && path.endsWith("/devices"));
        return write || accessBan || path.endsWith("/export.csv") || path.startsWith("/api/admin/media/attachments/")
                // Kesfet gonderisi medya onizlemesi (yonetici) de kisisel icerik gosterir
                || path.startsWith("/api/admin/posts/media/")
                || (!method.equals("OPTIONS") && personalDataRead(method, path));
    }

    /** users.pii ile eslenen (oturum, push cihazi, bekleyen kayit e-postalari...) ve PERSONAL_READS GET uclari. */
    static boolean personalDataRead(String method, String path) {
        if (!path.startsWith(AdminPaths.PREFIX + "/")) {
            return false;
        }
        String m = method.equals("HEAD") ? "GET" : method;
        if (!m.equals("GET")) {
            return false;
        }
        return PERSONAL_READS.matcher(path).matches()
                || AdminPermissionPolicy.explicit(m, path).filter(PermissionMatrix.USERS_PII::equals).isPresent();
    }

    public void record(HttpServletRequest req, Authentication auth, int status) {
        try {
            Long adminId = auth != null && auth.getPrincipal() instanceof Long l ? l : null;
            // Basic auth yoneticisinde kullanici kaydi yoktur: kullanici adi e-posta alanina yazilir
            // (statik tek hesap: aktor kisi degil "basic-admin" olarak ayirt edilir)
            String fallback = adminId == null && auth != null
                    ? (auth.getPrincipal() instanceof org.springframework.security.core.userdetails.UserDetails
                            ? "basic-admin" : auth.getName())
                    : null;
            repo.insert(adminId, fallback, req.getMethod(), req.getRequestURI(), status, clientIp.of(req),
                    details(req, status));
        } catch (RuntimeException e) {
            log.warn("Denetim kaydi yazilamadi: {}", e.toString());
        }
    }

    /**
     * Acik bildirilen hedef/sebep/ozet; hedef bildirilmediyse yoldan cikarilir. Istek kimligi MDC'den.
     * OZET YALNIZ BASARIDA yazilir (T-016): reddedilen/hatali istekte denetleyicinin onceden koydugu "hesap
     * anonimlestirildi" gibi basari ozeti, denemeyi gerceklesmis gibi gosterirdi; yerine sonuc kodu yazilir.
     */
    static AuditRepository.Details details(HttpServletRequest req, int status) {
        AuditContext.Data d = AuditContext.peek(req);
        String type = d == null ? null : d.targetType();
        String id = d == null ? null : d.targetId();
        if (type == null) {
            AuditTargets.Target t = AuditTargets.infer(AdminPaths.of(req));
            type = t.type();
            if (id == null) {
                id = t.id();
            }
        }
        String summary = d == null ? null : d.summary();
        if (status >= 400) {
            summary = "BASARISIZ: HTTP " + status;
        }
        return new AuditRepository.Details(type, id, d == null ? null : d.reason(), summary, MDC.get("requestId"));
    }
}
