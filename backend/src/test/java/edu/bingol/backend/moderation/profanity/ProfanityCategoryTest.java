package edu.bingol.backend.moderation.profanity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.FieldApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * T-059: nefret / teror / kendine zarar kategorileri ve Kurtce baslangic listesi. Kategori basina ornek testler;
 * kategori hit gunlugune yazilir; masum kullanimlar (tarih dersi, haber, birinci tekil duygu ifadesi) engellenmez.
 */
class ProfanityCategoryTest {

    private final ProfanityFilter filter = ProfanityFilter.builtInOnly();

    private ProfanityCategory categoryOf(String text) {
        ProfanityMatcher.Result r = filter.check(text);
        assertTrue(r.blocked(), "engellenmeliydi: " + text);
        return filter.categoryOf(r);
    }

    @Test
    void hateExamplesAreBlockedAsHate() {
        for (String t : List.of("kürtler ölsün", "yahudi pisliği", "Heil Hitler", "kill all jews", "go back to africa",
                "alevi pisliği", "SIEG HEIL!")) {
            assertEquals(ProfanityCategory.HATE, categoryOf(t), t);
        }
    }

    @Test
    void terrorExamplesAreBlockedAsTerror() {
        for (String t : List.of("pkk zindabad", "bomba koyacağım", "okulu bombalayacağım", "long live isis",
                "DEAŞ zindabad")) {
            assertEquals(ProfanityCategory.TERROR, categoryOf(t), t);
        }
    }

    @Test
    void selfHarmIncitementIsBlockedAsSelfHarm() {
        for (String t : List.of("kendini öldür", "git öl", "kill yourself", "kys", "intihar et", "slit your wrists")) {
            assertEquals(ProfanityCategory.SELF_HARM, categoryOf(t), t);
        }
    }

    @Test
    void kurdishStarterListIsBlockedAsProfanity() {
        assertEquals(ProfanityCategory.PROFANITY, categoryOf("qehbe"));
        assertEquals(ProfanityCategory.PROFANITY, categoryOf("tu kurê kûçikê yî"));
        assertEquals(ProfanityCategory.PROFANITY, categoryOf("Qehpik"));
    }

    @Test
    void innocentUsesAreNotBlocked() {
        for (String t : List.of("Hitler dönemi tarih dersi", "Kürt mutfağı etkinliği", "Kürtçe kursu açılıyor",
                "Bingöl'de yemek bomba gibiydi", "kendimi kötü hissediyorum", "kendini tanı", "gavurdağı gezisi",
                "intihar önleme semineri", "Zenciro", "PKK hakkında akademik makale", "yahudi mahallesi gezisi")) {
            assertFalse(filter.check(t).blocked(), "engellenmemeliydi: " + t);
        }
    }

    @Test
    void mostSevereCategoryWinsWhenSeveralMatch() {
        ProfanityMatcher.Result r = new ProfanityMatcher.Result(true, List.of("kürtler ölsün", "kendini öldür", "pkk zindabad"));
        assertEquals(ProfanityCategory.SELF_HARM, filter.categoryOf(r));
        assertEquals(ProfanityCategory.PROFANITY, filter.categoryOf(ProfanityMatcher.Result.CLEAN));
        assertEquals(ProfanityCategory.PROFANITY, filter.categoryOf(null));
    }

    @Test
    void builtInCategoryListsAreLoaded() {
        var counts = filter.builtInCategoryCounts();
        for (ProfanityCategory c : ProfanityCategory.values()) {
            assertTrue(counts.get(c) > 0, "bos kategori: " + c);
        }
    }

    @Test
    void adminTermCarriesItsCategory() {
        ProfanityTermRepository repo = mock(ProfanityTermRepository.class);
        ProfanityTerm t = new ProfanityTerm();
        t.setTerm("zzxqv kelimesi");
        t.setTermNormalized("zzxqv kelimesi");
        t.setKind(ProfanityTerm.Kind.BLOCK);
        t.setCategory(ProfanityCategory.TERROR);
        t.setLang("KU");
        when(repo.findAllByOrderByIdAsc()).thenReturn(List.of(t));
        ProfanityFilter f = new ProfanityFilter(repo, new ProfanityProperties(true, ProfanityProperties.Mode.BLOCK, 30));

        ProfanityMatcher.Result r = f.check("bu zzxqv kelimesi burada");

        assertTrue(r.blocked());
        assertEquals(ProfanityCategory.TERROR, f.categoryOf(r));
    }

    @Test
    void contentGuardLogsCategoryAndNeverTheWord() {
        ProfanityHitLogger hits = mock(ProfanityHitLogger.class);
        ContentGuard guard = new ContentGuard(filter, new ProfanityProperties(true, ProfanityProperties.Mode.BLOCK, 30), hits);

        FieldApiException e = assertThrows(FieldApiException.class,
                () -> guard.assertClean(ContentGuard.Entity.PROFILE, "bio", 7L, "kürtler ölsün"));

        assertEquals("CONTENT_PROFANITY", e.code());
        verify(hits).record("PROFILE", "bio", 7L, "BLOCK", ProfanityCategory.HATE);
        verify(hits, never()).record(anyString(), anyString(), org.mockito.ArgumentMatchers.any(), anyString());
    }

    @Test
    void plainProfanityKeepsLegacyLogCall() {
        ProfanityHitLogger hits = mock(ProfanityHitLogger.class);
        ContentGuard guard = new ContentGuard(filter, new ProfanityProperties(true, ProfanityProperties.Mode.BLOCK, 30), hits);

        assertThrows(FieldApiException.class,
                () -> guard.assertClean(ContentGuard.Entity.CLUB, "name", 3L, "qehbe"));

        verify(hits).record("CLUB", "name", 3L, "BLOCK");
    }
}
