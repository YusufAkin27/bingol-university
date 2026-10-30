package edu.bingol.backend.legal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.i18n.Lang;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Sozlesme okuma uclari: dil + tur basina onbellekli, yeni surum yayininda (ad alani) yenilenir, bulunamayan 404 onbelleklenmez. */
class LegalServiceCacheTest {

    private final DocumentRepository docs = mock(DocumentRepository.class);
    private final CacheService cache = TestCaches.create();
    private final LegalService service = new LegalService(docs, mock(AcceptanceRepository.class),
            mock(AppSettingRepository.class));

    private static LegalDocument doc(LegalType t, String lang, int version, String title) {
        LegalDocument d = new LegalDocument();
        d.setType(t);
        d.setLang(lang);
        d.setVersion(version);
        d.setTitle(title);
        d.setContent("{{controller.name}} metni");
        d.setActive(true);
        return d;
    }

    @BeforeEach
    void wire() {
        service.setCache(cache);
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.TERMS, "tr"))
                .thenReturn(Optional.of(doc(LegalType.TERMS, "tr", 3, "Kosullar")));
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.TERMS, "en"))
                .thenReturn(Optional.of(doc(LegalType.TERMS, "en", 3, "Terms")));
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.PRIVACY, "tr")).thenReturn(Optional.empty());
    }

    @Test
    void contentIsCachedPerTypeAndLanguageAndPlaceholdersStayRaw() {
        assertEquals("Kosullar", service.content(LegalType.TERMS, Lang.TR).title());
        assertEquals("Terms", service.content(LegalType.TERMS, Lang.EN).title());
        assertEquals("Kosullar", service.content(LegalType.TERMS, Lang.TR).title());
        assertEquals("{{controller.name}} metni", service.content(LegalType.TERMS, Lang.TR).content(),
                "yer tutucular sunum aninda doldurulur, onbellekte ham kalir");
        verify(docs, times(1)).findByTypeAndLangAndActiveTrue(LegalType.TERMS, "tr");
        verify(docs, times(1)).findByTypeAndLangAndActiveTrue(LegalType.TERMS, "en");
    }

    @Test
    void summariesCachedAndRefreshedAfterPublish() {
        service.summaries(Lang.TR);
        service.summaries(Lang.TR);
        verify(docs, times(1)).findByTypeAndLangAndActiveTrue(LegalType.TERMS, "tr");
        cache.invalidate("legal");
        service.summaries(Lang.TR);
        verify(docs, times(2)).findByTypeAndLangAndActiveTrue(LegalType.TERMS, "tr");
    }

    @Test
    void missingDocumentIsNotCachedAndKeeps404() {
        for (int i = 0; i < 2; i++) {
            ApiException e = assertThrows(ApiException.class, () -> service.content(LegalType.PRIVACY, Lang.TR));
            assertEquals("LEGAL_NOT_FOUND", e.code());
        }
        // her denemede birincil + tr yedegi = 2 sorgu; iki deneme = 4 (yok sonucu onbelleklenmedi)
        verify(docs, times(4)).findByTypeAndLangAndActiveTrue(LegalType.PRIVACY, "tr");
    }

    @Test
    void summariesSurviveJsonRoundTripThroughRedis() {
        CacheService[] p = TestCaches.pair();
        LegalService a = new LegalService(docs, mock(AcceptanceRepository.class), mock(AppSettingRepository.class));
        a.setCache(p[0]);
        LegalService b = new LegalService(docs, mock(AcceptanceRepository.class), mock(AppSettingRepository.class));
        b.setCache(p[1]);
        assertEquals(a.summaries(Lang.TR), b.summaries(Lang.TR));
        assertEquals(a.content(LegalType.TERMS, Lang.TR), b.content(LegalType.TERMS, Lang.TR));
        // a.summaries + a.content = 2 sorgu; b iki okumayi da Redis'ten (JSON) aldi
        verify(docs, times(2)).findByTypeAndLangAndActiveTrue(LegalType.TERMS, "tr");
    }
}
