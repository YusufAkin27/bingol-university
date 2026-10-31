package edu.bingol.backend.moderation.profanity;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * T-022/T-023: baglanti/e-posta bicimli parca filtreyi atlatma yolu degildir; izin listesi gevsek (ı->i) bicimi
 * gercek kufuru acmaz; ek es goruntulu harfler; "iki sozcuk + ek" kalibi. Kaynak koda gercek kufur duz yazilmaz:
 * sozcukler parcalardan birlestirilir (ProfanityFilterTest ile ayni gelenek).
 *
 * <p>Karar notlari (yanlis pozitifler): "Sikkim" (Hindistan eyaleti) izin listesine eklendi (kalkti); "Pornografi
 * Semineri" akademik olsa da kok listede oldugundan ENGELLI KALIR (yonetici panelinden izin kaydi ya da Destek yolu);
 * "sikici" ASCII yazimi "sıkıcı" (can sikici) ile ayirt edilemez: engellenmez (belgeli taviz).
 */
class ProfanityMatcherLinkAndLooseTest {

    private final ProfanityFilter filter = ProfanityFilter.builtInOnly();

    private static final String OROSPU = "oro" + "spu";
    private static final String SIKTIR = "sik" + "tir";
    private static final String SIKIS = "si" + "kis";
    private static final String SIKI = "si" + "ki";
    private static final String AMINA = "am" + "ina";

    private boolean blocked(String s) {
        return filter.check(s).blocked();
    }

    @Test
    void emailShapedChunksAreScanned() {
        assertTrue(blocked(OROSPU + "@x.y"));
        assertTrue(blocked(OROSPU + "@x.y gelin"));
        assertTrue(blocked(SIKTIR + "@a.b gidin"));
        assertTrue(blocked("selam " + OROSPU.toUpperCase() + "@Example.COM"));
    }

    @Test
    void urlShapedChunksAreScanned() {
        assertTrue(blocked("www." + OROSPU));
        assertTrue(blocked(OROSPU + "://x"));
        assertTrue(blocked("https://example.com/" + OROSPU));
        assertTrue(blocked("https://example.com/yol?ad=" + SIKTIR + "&x=1"));
    }

    @Test
    void realUrlsAndEmailsStayClean() {
        assertFalse(blocked("https://www.bingol.edu.tr/haber/detay.aspx?id=12345&dil=tr"));
        assertFalse(blocked("ahmet.yilmaz@bingol.edu.tr"));
        assertFalse(blocked("test@gmail.com ve https://instagram.com/bingolunv"));
        assertFalse(blocked("https://sks.bingol.edu.tr/yemek-listesi"));
    }

    @Test
    void falsePositivesDoNotGrow() {
        for (String ok : new String[] {"Bingöl", "Sikke", "Sikkim", "Sikkim eyaleti", "Scunthorpe", "Cumartesi", "Amasya",
                "Malatya", "Kasım", "Sosyoloji Mühendislik", "Phuket", "Dickens Essex", "sıkıntı", "sikinti", "SIKIŞIK",
                "ama koydum", "bana koydum", "aşkale"}) {
            assertFalse(blocked(ok), ok);
        }
    }

    @Test
    void looseAllowFormNoLongerShadowsRealWords() {
        assertTrue(blocked(SIKIS));
        assertTrue(blocked(SIKI));
        assertTrue(blocked("bu " + SIKIS + " ne"));
        // meşru uzun sözcükler Türkçe ve ASCII yazımla muaf kalır
        assertFalse(blocked("sıkıntı"));
        assertFalse(blocked("sikinti"));
        assertFalse(blocked("sıkıştırma"));
        assertFalse(blocked("sikistirma"));
    }

    @Test
    void documentedTradeoffs() {
        assertTrue(blocked("Pornografi Semineri"), "kok listede: yonetici izin kaydi gerekir (belgeli karar)");
        assertFalse(blocked("sikici"), "sıkıcı ile cakisir: engellenmez (belgeli taviz)");
    }

    @Test
    void twoWordPhraseWithSuffixIsCaught() {
        assertTrue(blocked(AMINA + " koydum"));
        assertTrue(blocked(AMINA + " koyayim"));
        assertTrue(blocked("am" + "ına koyayım"));
        assertTrue(blocked("am" + "ına koydum"));
    }

    @Test
    void extraConfusablesAreFolded() {
        // Kiril ѕ (U+0455) ve і (U+0456)
        assertTrue(blocked("\u0455\u0456" + "kt" + "\u0456" + "r"));
        assertTrue(blocked("\u0455" + "iktir"));
        // Kiril ф (U+0444) f yerine
        assertTrue(blocked("\u0444" + "uck"));
    }

    @Test
    void letterSwapVariantsAreCaught() {
        assertTrue(blocked("f" + "vck"));
        assertTrue(blocked("ph" + "uck"));
        assertTrue(blocked("ph" + "ucking"));
        assertFalse(blocked("Phuket"));
    }
}
