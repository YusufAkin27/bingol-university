package edu.bingol.backend.auth.realemail;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Gercek e-posta kapisi sorgusu (HTTP suzgeci ve STOMP SEND icin ortak). {@code real_email_required AND email_relay}
 * = hesap Apple role adresiyle ACILDI ve gercek adres henuz dogrulanmadi. Yalniz YENI role hesaplarda true olur
 * (mevcut canli role hesaplar kilitlenmez: onlarda bayrak false, uygulama yumusak adim gosterir).
 *
 * <p>"Kapi kapali" (serbest) sonucu bellekte tutulur (dogrulama geri alinmaz; her yazmada DB sorgusu olmasin), kapali
 * sonuc ONBELLEKLENMEZ (dogrulama biter bitmez kapi acilir). {@code app.auth.real-email-gate.enabled=false} acil kapatma.
 */
@Component
public class RealEmailGate {

    static final long CLEAR_TTL_MS = 3_600_000L;
    private static final int MAX_CACHE = 100_000;

    private final JdbcTemplate jdbc;
    private final boolean enabled;
    private final ConcurrentHashMap<Long, Long> clearUntil = new ConcurrentHashMap<>();

    public RealEmailGate(JdbcTemplate jdbc, @Value("${app.auth.real-email-gate.enabled:true}") boolean enabled) {
        this.jdbc = jdbc;
        this.enabled = enabled;
    }

    public boolean enabled() {
        return enabled;
    }

    /** true = gercek e-posta gerekli (yazma kapali). Sorgu basarisizsa false (kullaniciyi kilitleme). */
    public boolean isRequired(Long uid) {
        if (!enabled || uid == null) {
            return false;
        }
        Long until = clearUntil.get(uid);
        if (until != null && until > System.currentTimeMillis()) {
            return false;
        }
        boolean required;
        try {
            List<Boolean> rows = jdbc.query(
                    "SELECT (real_email_required AND email_relay) FROM app_user WHERE id = ?",
                    (rs, n) -> rs.getBoolean(1), uid);
            required = !rows.isEmpty() && Boolean.TRUE.equals(rows.get(0));
        } catch (RuntimeException e) {
            return false;
        }
        if (!required) {
            if (clearUntil.size() > MAX_CACHE) {
                clearUntil.clear();
            }
            clearUntil.put(uid, System.currentTimeMillis() + CLEAR_TTL_MS);
        }
        return required;
    }
}
