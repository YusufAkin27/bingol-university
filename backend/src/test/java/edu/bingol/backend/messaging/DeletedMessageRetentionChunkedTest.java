package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.dbmaint.ChunkedDeleter;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * FIX-P03 (A02#9, A09#6): silinen mesaj saklama temizligi 8 sn statement_timeout altinda tek DELETE ile
 * tamamlanamiyordu; artik parca parca (ChunkedDeleter). Saklama suresi ayni (90 gun): YENI sure eklenmedi.
 */
class DeletedMessageRetentionChunkedTest {

    private static final Instant NOW = Instant.parse("2026-10-31T00:00:00Z");
    private final MessageRepository messages = mock(MessageRepository.class);
    private final ChunkedDeleter deleter = mock(ChunkedDeleter.class);
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);

    @Test
    @SuppressWarnings("unchecked")
    void usesChunkedDeleterWithLimitedStatementInsteadOfSingleDelete() {
        new DeletedMessageRetention(messages, clock, 90, deleter).purge();

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Map<String, ?>> params = ArgumentCaptor.forClass(Map.class);
        verify(deleter).delete(eq("message_deleted"), sql.capture(), params.capture());
        assertTrue(sql.getValue().contains("LIMIT :lim"), "parcali silme :lim sinirini kullanmali");
        assertTrue(sql.getValue().contains("deleted_at IS NOT NULL"));
        assertEquals(OffsetDateTime.ofInstant(NOW.minusSeconds(90L * 86400), ZoneOffset.UTC), params.getValue().get("cutoff"));
        verify(messages, never()).purgeDeletedBefore(any());
    }

    @Test
    void zeroDaysStillDisabledWithDeleter() {
        new DeletedMessageRetention(messages, clock, 0, deleter).purge();
        verify(deleter, never()).delete(anyString(), anyString(), anyMap());
    }
}
