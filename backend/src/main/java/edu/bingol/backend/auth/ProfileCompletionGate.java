package edu.bingol.backend.auth;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Profil tamamlama kapisi sorgusu (HTTP suzgeci ve STOMP SEND icin ortak). {@code profile_completed_at IS NULL} =
 * tamamlanmamis. TAMAMLANDI sonucu bellekte tutulur (tamamlanma geri alinmaz; her yazmada DB sorgusu olmasin),
 * tamamlanmamis sonuc ONBELLEKLENMEZ (onboarding biter bitmez kapi acilir; her yazmada tek PK sorgusu).
 */
@Component
public class ProfileCompletionGate {

    static final long CLEAR_TTL_MS = 3_600_000L;
    private static final int MAX_CACHE = 100_000;

    private final JdbcTemplate jdbc;
    private final ConcurrentHashMap<Long, Long> clearUntil = new ConcurrentHashMap<>();

    public ProfileCompletionGate(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** true = profil tamamlanmamis (yazma kapali). Sorgu basarisizsa false (kullaniciyi kilitleme; uclar kendi kontrolunu yapar). */
    public boolean isIncomplete(Long uid) {
        if (uid == null) {
            return false;
        }
        Long until = clearUntil.get(uid);
        if (until != null && until > System.currentTimeMillis()) {
            return false;
        }
        boolean incomplete;
        try {
            List<Boolean> rows = jdbc.query("SELECT (profile_completed_at IS NULL) FROM app_user WHERE id = ?",
                    (rs, n) -> rs.getBoolean(1), uid);
            incomplete = !rows.isEmpty() && Boolean.TRUE.equals(rows.get(0));
        } catch (RuntimeException e) {
            return false;
        }
        if (!incomplete) {
            if (clearUntil.size() > MAX_CACHE) {
                clearUntil.clear();
            }
            clearUntil.put(uid, System.currentTimeMillis() + CLEAR_TTL_MS);
        }
        return incomplete;
    }
}
