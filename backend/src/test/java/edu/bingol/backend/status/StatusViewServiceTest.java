package edu.bingol.backend.status;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** GET /api/status gorunumu: dil basina onbellekli, SyncStatus yazmasinda (ad alani) yenilenir. */
class StatusViewServiceTest {

    private final StatusService status = mock(StatusService.class);
    private final I18n i18n = mock(I18n.class);
    private final CacheService cache = TestCaches.create();
    private final StatusViewService view = new StatusViewService(status, i18n, cache);

    private static SyncStatus st(String source, SyncStatus.State state) {
        SyncStatus s = new SyncStatus();
        s.setSource(source);
        s.setState(state);
        s.setLastAttemptAt(Instant.parse("2026-10-30T00:00:00Z"));
        return s;
    }

    @BeforeEach
    void wire() {
        when(status.all()).thenReturn(List.of(st("NEWS", SyncStatus.State.OK), st("MENU", SyncStatus.State.MAINTENANCE)));
        when(i18n.msg("status.maintenance.MENU", Lang.TR)).thenReturn("Yemek listesi bakimda");
        when(i18n.msg("status.maintenance.MENU", Lang.EN)).thenReturn("Menu under maintenance");
        when(i18n.msg("status.maintenance.NEWS", Lang.TR)).thenReturn("status.maintenance.NEWS");
    }

    @Test
    void viewIsCachedPerLanguageWithLocalizedMaintenanceText() {
        var tr = view.view(Lang.TR);
        var tr2 = view.view(Lang.TR);
        var en = view.view(Lang.EN);
        verify(status, times(2)).all();
        assertEquals(tr, tr2);
        assertTrue(tr.get("MENU").maintenance());
        assertEquals("Yemek listesi bakimda", tr.get("MENU").maintenanceMessage());
        assertEquals("Menu under maintenance", en.get("MENU").maintenanceMessage());
        assertFalse(tr.get("NEWS").maintenance());
    }

    @Test
    void syncStatusChangeShowsAfterInvalidation() {
        view.view(Lang.TR);
        when(status.all()).thenReturn(List.of(st("NEWS", SyncStatus.State.OK), st("MENU", SyncStatus.State.OK)));
        assertTrue(view.view(Lang.TR).get("MENU").maintenance());
        cache.invalidate("status");
        assertFalse(view.view(Lang.TR).get("MENU").maintenance());
    }

    @Test
    void viewSurvivesJsonRoundTripThroughRedis() {
        CacheService[] p = TestCaches.pair();
        var a = new StatusViewService(status, i18n, p[0]);
        var b = new StatusViewService(status, i18n, p[1]);
        assertEquals(a.view(Lang.TR), b.view(Lang.TR));
        verify(status, times(1)).all();
    }
}
