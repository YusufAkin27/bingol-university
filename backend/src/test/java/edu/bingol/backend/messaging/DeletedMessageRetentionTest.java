package edu.bingol.backend.messaging;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

/** T-064 (K-14): silinen mesaj saklama isi; 0 = kapali, N gun = o kadar gunden eski silinmisler kalici silinir. */
class DeletedMessageRetentionTest {

    private static final Instant NOW = Instant.parse("2026-10-31T00:00:00Z");
    private final MessageRepository messages = mock(MessageRepository.class);
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);

    @Test
    void zeroDaysMeansDisabled() {
        new DeletedMessageRetention(messages, clock, 0).purge();
        verify(messages, never()).purgeDeletedBefore(any());
    }

    @Test
    void negativeIsTreatedAsDisabled() {
        new DeletedMessageRetention(messages, clock, -5).purge();
        verify(messages, never()).purgeDeletedBefore(any());
    }

    /** K-14 (b) uretim degeri: 90 gun. */
    @Test
    void ninetyDaysPurgesOlderThanCutoff() {
        when(messages.purgeDeletedBefore(any())).thenReturn(4);

        new DeletedMessageRetention(messages, clock, 90).purge();

        verify(messages).purgeDeletedBefore(NOW.minus(Duration.ofDays(90)));
    }

    @Test
    void repositoryFailureDoesNotEscape() {
        when(messages.purgeDeletedBefore(any())).thenThrow(new IllegalStateException("db down"));
        new DeletedMessageRetention(messages, clock, 90).purge(); // exception sizdirmamali
    }
}
