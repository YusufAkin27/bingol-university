package edu.bingol.backend.academician;

import java.time.Instant;
import java.util.Collection;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Oturum KESINLESTIRME yolu (acik kapatma ve suresi dolmus oturumun ilk gozlenisi ayni yoldan gecer): durum OPEN -> CLOSED
 * kosullu UPDATE ile yapilir (yalniz bir cagri "kazanir"), ardindan devamsizlik uyarisi yeniden hesaplanir. Zamanlayici yok:
 * sure dolumu, oturum ilk kez okundugunda/tarandiginda/raporlandiginda fark edilir.
 */
@Component
public class SessionFinalizer {

    private final AcSessionRepository sessions;
    private final AbsenceWarningService warnings;
    private final TransactionTemplate tx;

    public SessionFinalizer(AcSessionRepository sessions, AbsenceWarningService warnings, PlatformTransactionManager tm) {
        this.sessions = sessions;
        this.warnings = warnings;
        this.tx = new TransactionTemplate(tm);
    }

    /** Acik kapatma (hoca). true = bu cagri oturumu kapatti. */
    public boolean close(AcSession s, Instant at) {
        Integer n = tx.execute(st -> sessions.closeIfOpen(s.getId(), at));
        if (n != null && n > 0) {
            s.setStatus(AcSession.Status.CLOSED);
            s.setClosedAt(at);
            warnings.recompute(s.getCourseId());
            return true;
        }
        return false;
    }

    /** Suresi dolmus ama hala OPEN gorunen oturumlari kesinlestirir (kapanis zamani = expires_at). */
    public void observeExpired(Collection<AcSession> list, Instant now) {
        for (AcSession s : list) {
            if (s.getStatus() == AcSession.Status.OPEN && !now.isBefore(s.getExpiresAt())) {
                close(s, s.getExpiresAt());
            }
        }
    }
}
