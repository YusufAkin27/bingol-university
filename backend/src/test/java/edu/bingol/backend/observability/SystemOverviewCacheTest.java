package edu.bingol.backend.observability;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.spy;

import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

/**
 * FIX-P09 (A08#6): panel ucu {@code /api/admin/system/overview} her cagrida tum gostergeleri yeniden hesaplamaz; dil
 * basina 15 sn onbellek (mesajlar istek dilinde kalir).
 */
class SystemOverviewCacheTest {

    @Test
    void evaluationIsCachedPerLanguage() {
        SystemOverviewService real = new SystemOverviewService(null, null, null, null, null, null, null, null, null, null,
                null, null);
        SystemOverviewService s = spy(real);
        AtomicInteger calls = new AtomicInteger();
        doAnswer(i -> {
            calls.incrementAndGet();
            return new SystemOverviewService.Overview(Instant.now(), IndicatorStatus.OK, Map.of());
        }).when(s).evaluate(any(Locale.class));

        s.cached(Locale.forLanguageTag("tr-TR"));
        s.cached(Locale.forLanguageTag("tr"));
        assertThat(calls.get()).isEqualTo(1);

        s.cached(Locale.ENGLISH);
        s.cached(Locale.forLanguageTag("en-GB"));
        assertThat(calls.get()).isEqualTo(2);

        // bilinmeyen dil varsayilana (tr) duser: yeni hesap yok, anahtar sayisi sinirli
        s.cached(Locale.FRENCH);
        assertThat(calls.get()).isEqualTo(2);
    }
}
