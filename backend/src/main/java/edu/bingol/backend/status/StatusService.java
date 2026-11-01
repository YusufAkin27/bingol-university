package edu.bingol.backend.status;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Kaynak sitede yapi degisir veya site ulasilamaz olursa hata firlatmak yerine kaynagi
 * "bakimda" isaretler; eski veriler sunulmaya devam eder.
 */
@Service
public class StatusService {

    public static final String NEWS = "NEWS";
    public static final String MENU = "MENU";
    private static final int MAX_MESSAGE = 500;

    private final SyncStatusRepository repo;

    public StatusService(SyncStatusRepository repo) {
        this.repo = repo;
    }

    public void markOk(String source, String message) {
        SyncStatus s = load(source);
        Instant now = Instant.now();
        s.setLastAttemptAt(now);
        s.setLastSuccessAt(now);
        s.setState(SyncStatus.State.OK);
        s.setMessage(clip(message));
        repo.save(s);
    }

    public void markMaintenance(String source, String message) {
        SyncStatus s = load(source);
        s.setLastAttemptAt(Instant.now());
        s.setState(SyncStatus.State.MAINTENANCE);
        s.setMessage(clip(message));
        repo.save(s);
    }

    /**
     * Basarisiz deneme kaydi, ama kullanicinin baktigi veri (ornegin icinde bulunulan ayin menusu) yerinde:
     * bakim bandi acilmaz; son deneme zamani yakalama islerinin aralik kontrolu icin yazilir.
     */
    public void markAttempt(String source, String message) {
        SyncStatus s = load(source);
        s.setLastAttemptAt(Instant.now());
        s.setState(SyncStatus.State.OK);
        s.setMessage(clip(message));
        repo.save(s);
    }

    public Optional<SyncStatus> find(String source) {
        return repo.findById(source);
    }

    public List<SyncStatus> all() {
        return repo.findAll();
    }

    /** sync_status.message sutunu 500 karakter; birlesik hata metni kirpilmazsa durum yazimi DB hatasiyla kaybolur. */
    static String clip(String message) {
        return message == null || message.length() <= MAX_MESSAGE ? message : message.substring(0, MAX_MESSAGE);
    }

    private SyncStatus load(String source) {
        return repo.findById(source).orElseGet(() -> {
            SyncStatus s = new SyncStatus();
            s.setSource(source);
            return s;
        });
    }
}
