package edu.bingol.backend.status;

import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;

/**
 * Kaynak sitede yapi degisir veya site ulasilamaz olursa hata firlatmak yerine kaynagi
 * "bakimda" isaretler; eski veriler sunulmaya devam eder.
 */
@Service
public class StatusService {

    public static final String NEWS = "NEWS";
    public static final String MENU = "MENU";

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
        s.setMessage(message);
        repo.save(s);
    }

    public void markMaintenance(String source, String message) {
        SyncStatus s = load(source);
        s.setLastAttemptAt(Instant.now());
        s.setState(SyncStatus.State.MAINTENANCE);
        s.setMessage(message);
        repo.save(s);
    }

    public List<SyncStatus> all() {
        return repo.findAll();
    }

    private SyncStatus load(String source) {
        return repo.findById(source).orElseGet(() -> {
            SyncStatus s = new SyncStatus();
            s.setSource(source);
            return s;
        });
    }
}
