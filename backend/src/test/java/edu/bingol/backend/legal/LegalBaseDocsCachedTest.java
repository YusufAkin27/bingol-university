package edu.bingol.backend.legal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.DocumentRepository.DocHead;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * P07-B3: bekleyen onay / yeniden onay filtresi / surum listesi 120-320 KB sozlesme METNINI okumaz;
 * baslik satirlari (projeksiyon) onbellekten gelir ve yeni surum yayininda (legal ad alani) yenilenir.
 */
class LegalBaseDocsCachedTest {

    private final DocumentRepository docs = mock(DocumentRepository.class);
    private final AcceptanceRepository acc = mock(AcceptanceRepository.class);
    private final CacheService cache = TestCaches.create();
    private final LegalService service = new LegalService(docs, acc, mock(AppSettingRepository.class));

    private static DocHead head(LegalType t, int version, String lang) {
        DocHead h = mock(DocHead.class);
        when(h.getType()).thenReturn(t);
        when(h.getLang()).thenReturn(lang);
        when(h.getVersion()).thenReturn(version);
        when(h.getTitle()).thenReturn("Baslik " + t + " v" + version);
        when(h.isRequireReaccept()).thenReturn(true);
        when(h.getPublishedAt()).thenReturn(Instant.parse("2026-10-01T00:00:00Z"));
        return h;
    }

    @BeforeEach
    void wire() {
        service.setCache(cache);
        List<DocHead> active = List.of(head(LegalType.TERMS, 4, "tr"), head(LegalType.PRIVACY, 4, "tr"));
        List<DocHead> versions = List.of(head(LegalType.TERMS, 4, "tr"), head(LegalType.TERMS, 3, "tr"));
        when(docs.activeHeads("tr")).thenReturn(active);
        when(docs.versionHeads(LegalType.TERMS, "tr")).thenReturn(versions);
    }

    @Test
    void pendingReadsBaseHeadsOnceAndNeverLoadsFullText() {
        for (int i = 0; i < 5; i++) {
            assertEquals(2, service.pending(7L + i, Lang.TR).size());
        }
        verify(docs, times(1)).activeHeads("tr");
        verify(docs, never()).findByTypeAndLangAndActiveTrue(any(), anyString());
    }

    @Test
    void newVersionInvalidatesBaseHeads() {
        service.pending(7L, Lang.TR);
        cache.invalidate("legal");
        service.pending(7L, Lang.TR);
        verify(docs, times(2)).activeHeads("tr");
    }

    @Test
    void versionsListUsesHeadsOnlyAndIsCached() {
        var a = service.versions(LegalType.TERMS, Lang.TR);
        var b = service.versions(LegalType.TERMS, Lang.TR);
        assertEquals(a, b);
        assertEquals(2, a.size());
        assertEquals(4, a.get(0).version());
        assertTrue(a.get(0).title().startsWith("Baslik"));
        verify(docs, times(1)).versionHeads(LegalType.TERMS, "tr");
        verify(docs, never()).findByTypeOrderByVersionDescLangAsc(any());
    }

    @Test
    void signupConsentUsesCachedHeads() {
        service.recordSignupConsent(9L);
        service.recordSignupConsent(10L);
        verify(docs, times(1)).activeHeads("tr");
    }
}
