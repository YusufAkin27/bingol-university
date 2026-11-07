package edu.bingol.backend.moderation;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.ChunkedDeleter;
import edu.bingol.backend.moderation.profanity.ProfanityHitLogRepository;
import edu.bingol.backend.moderation.profanity.ProfanityHitLogger;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * FIX-P05 (A05 #11): ihlal defteri ve uygunsuz ifade gunlugu saklama temizligi tek buyuk DELETE yerine
 * ChunkedDeleter ile parcali, SchedulerLock ile tek ornekte calisir.
 */
class ModerationRetentionChunkedTest {

    private final ChunkedDeleter deleter = mock(ChunkedDeleter.class);
    private final SchedulerLock lock = mock(SchedulerLock.class);

    private void lockRunsTask() {
        when(lock.tryRun(anyString(), any(), any())).thenAnswer(i -> {
            ((Runnable) i.getArgument(2)).run();
            return true;
        });
    }

    @Test
    void ledgerPurgeUsesChunkedDeleterUnderSchedulerLock() {
        lockRunsTask();
        ViolationLedgerRepository ledger = mock(ViolationLedgerRepository.class);
        AccountDeleteHoldRepository holdRepo = mock(AccountDeleteHoldRepository.class);
        ViolationLedgerService svc = new ViolationLedgerService(ledger, mock(ModerationStrikeRepository.class),
                mock(StrikeService.class), mock(AccountDeleteHolds.class), holdRepo, mock(JdbcTemplate.class), "k", "jwt");
        svc.setMaintenance(deleter, lock);

        svc.purgeExpired();

        verify(lock).tryRun(eq("violation-ledger-purge"), any(), any());
        verify(deleter).delete(eq("violation_ledger"), anyString(), anyMap());
        verify(deleter).delete(eq("account_delete_hold"), anyString(), anyMap());
        verify(ledger, never()).deleteExpired(any());
        verify(holdRepo, never()).deleteReleasedBefore(any());
    }

    @Test
    void profanityLogPurgeUsesChunkedDeleterUnderSchedulerLock() {
        lockRunsTask();
        ProfanityHitLogRepository repo = mock(ProfanityHitLogRepository.class);
        ProfanityHitLogger logger = new ProfanityHitLogger(repo);
        logger.setMaintenance(deleter, lock);

        logger.purgeOld();

        verify(lock).tryRun(eq("profanity-hit-purge"), any(), any());
        verify(deleter).delete(eq("profanity_hit_log"), anyString(), anyMap());
        verify(repo, never()).deleteOlderThan(any());
    }

    @Test
    void anotherInstanceHoldingTheLockSkipsThePurge() {
        when(lock.tryRun(anyString(), any(), any())).thenReturn(false);
        ProfanityHitLogger logger = new ProfanityHitLogger(mock(ProfanityHitLogRepository.class));
        logger.setMaintenance(deleter, lock);

        logger.purgeOld();

        verify(deleter, never()).delete(anyString(), anyString(), anyMap());
    }
}
