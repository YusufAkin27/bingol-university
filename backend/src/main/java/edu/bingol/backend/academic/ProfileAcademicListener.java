package edu.bingol.backend.academic;

import edu.bingol.backend.profile.ProfileAcademicChangedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Profilde bolum/sinif degisince resmi programdan kopyalanmis kisisel ders programini yeni profile gore yeniler.
 * Commit sonrasi, ayri islemde calisir ve istek ayni thread'de bittiginden istemcinin sonraki GET /api/timetable
 * cagrisi yeni dersleri gorur. Hata profil guncellemesini etkilemez.
 */
@Component
public class ProfileAcademicListener {

    private static final Logger log = LoggerFactory.getLogger(ProfileAcademicListener.class);

    private final OfficialTimetableSeeder seeder;

    public ProfileAcademicListener(OfficialTimetableSeeder seeder) {
        this.seeder = seeder;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onChanged(ProfileAcademicChangedEvent e) {
        try {
            seeder.reseedAfterProfileChange(e.userId());
        } catch (RuntimeException ex) {
            log.warn("bolum degisimi sonrasi ders programi yenilenemedi (kullanici {}): {}", e.userId(), ex.toString());
        }
    }
}
