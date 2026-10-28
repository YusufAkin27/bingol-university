package edu.bingol.backend.analytics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.analytics.AnalyticsDtos.EventIn;
import edu.bingol.backend.analytics.AnalyticsService.ValidEvent;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Analitik: kullanici basina gunluk olay ust siniri ve istek basina olay sayisi siniri. */
class AnalyticsDailyCapTest {

    private final ActivityRepository repo = mock(ActivityRepository.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-28T10:00:00Z"), ZoneOffset.UTC);
    private final AnalyticsService svc = new AnalyticsService(repo, clock);

    private static List<EventIn> events(int n) {
        List<EventIn> l = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            l.add(new EventIn("e" + i, null, null, null));
        }
        return l;
    }

    @SuppressWarnings("unchecked")
    private int insertedInLastCall() {
        ArgumentCaptor<List<ValidEvent>> cap = ArgumentCaptor.forClass(List.class);
        verify(repo, org.mockito.Mockito.atLeastOnce()).insertEvents(anyLong(), cap.capture());
        return cap.getValue().size();
    }

    @Test
    void eventsBeyondTheDailyCapAreDroppedAndPartialBatchIsTruncated() {
        svc.setMaxEventsPerDay(120);

        svc.record(5L, events(50)); // 50
        svc.record(5L, events(50)); // 100
        svc.record(5L, events(50)); // 20 kalan: kesilir
        assertEquals(20, insertedInLastCall());
        verify(repo, times(3)).insertEvents(anyLong(), anyList());

        svc.record(5L, events(50)); // sinir doldu: hic yazilmaz
        verify(repo, times(3)).insertEvents(anyLong(), anyList());
    }

    @Test
    void capIsPerUser() {
        svc.setMaxEventsPerDay(50);
        svc.record(1L, events(50));
        svc.record(1L, events(50)); // atilir
        svc.record(2L, events(50)); // baska kullanici etkilenmez
        verify(repo, times(2)).insertEvents(anyLong(), anyList());
    }

    @Test
    void defaultDailyCapIs2000() {
        for (int i = 0; i < 40; i++) {
            svc.record(3L, events(50));
        }
        verify(repo, times(40)).insertEvents(anyLong(), anyList()); // 40 x 50 = 2000: tam sinir
        svc.record(3L, events(1));
        verify(repo, times(40)).insertEvents(anyLong(), anyList());
    }

    @Test
    void zeroDisablesTheCap() {
        svc.setMaxEventsPerDay(0);
        for (int i = 0; i < 45; i++) {
            svc.record(3L, events(50));
        }
        verify(repo, times(45)).insertEvents(anyLong(), anyList());
    }

    @Test
    void moreThanFiftyEventsInOneRequestStillRejected() {
        assertThrows(ApiException.class, () -> svc.record(4L, events(51)));
        verify(repo, never()).insertEvents(anyLong(), anyList());
    }
}
