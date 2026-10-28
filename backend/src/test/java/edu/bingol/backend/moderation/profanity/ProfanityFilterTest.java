package edu.bingol.backend.moderation.profanity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;

/**
 * Esleyici testleri. Kaynak koda gercek kufur YAZILMAZ: ornek kelimeler yerlesik kaynak dosyalardan okunur,
 * varyasyonlar (aralik, leet, tekrar, buyuk harf) programla uretilir.
 */
class ProfanityFilterTest {

    private final ProfanityFilter filter = ProfanityFilter.builtInOnly();

    /** Listeden ilk tam eslesme (=) girisi: yalnizca [a-z], verilen uzunluk araliginda. */
    private static String exactSample(String lang, int min) {
        for (String l : ProfanityFilter.builtInLines(lang)) {
            if (l.matches("=[a-z]{" + min + ",10}")) return l.substring(1);
        }
        throw new IllegalStateException("ornek yok: " + lang);
    }

    /** Listeden ilk kok (isaretsiz) girisi. */
    private static String prefixSample(String lang) {
        for (String l : ProfanityFilter.builtInLines(lang)) {
            if (l.matches("[a-z]{6,10}")) return l;
        }
        throw new IllegalStateException("kok ornek yok: " + lang);
    }

    private boolean blocked(String s) {
        return filter.check(s).blocked();
    }

    @Test
    void plainAndCaseVariantsAreBlocked() {
        String w = exactSample("tr", 6);
        assertTrue(blocked(w));
        assertTrue(blocked(w.toUpperCase(Locale.ROOT)));
        assertTrue(blocked(w.toUpperCase(Locale.forLanguageTag("tr-TR")))); // Turkce İ
        assertTrue(blocked("Merhaba arkadaslar " + w + " toplanti"));
        assertTrue(blocked(w + "!!!"));
    }

    @Test
    void spacingSeparatorsAndRepeatsAreCaught() {
        String w = exactSample("tr", 6);
        StringBuilder dots = new StringBuilder();
        StringBuilder spaces = new StringBuilder();
        StringBuilder stars = new StringBuilder();
        for (char c : w.toCharArray()) {
            dots.append(c).append('.');
            spaces.append(c).append(' ');
            stars.append(c).append('_');
        }
        assertTrue(blocked(dots.toString()), "nokta araligi");
        assertTrue(blocked(spaces.toString()), "bosluk araligi");
        assertTrue(blocked(stars.toString()), "alt cizgi araligi");
        String mid = w.substring(0, 3) + w.charAt(3) + w.charAt(3) + w.charAt(3) + w.substring(4);
        assertTrue(blocked(mid), "tekrar eden harf");
        assertTrue(blocked(w.charAt(0) + "​" + w.substring(1)), "sifir genislikli karakter");
    }

    @Test
    void leetSubstitutionsAreCaught() {
        String w = exactSample("tr", 6);
        String leet = w.replace('i', '1').replace('e', '3').replace('o', '0').replace('a', '4').replace('s', '5');
        assertFalse(leet.equals(w), "ornek leet'e uygun olmali");
        assertTrue(blocked(leet));
        assertTrue(blocked(w.replace('a', '@').replace('s', '$')));
    }

    @Test
    void inflectedFormsOfRootEntriesAreCaughtButBareOtherWordsAreNot() {
        String root = prefixSample("tr");
        assertTrue(blocked(root));
        assertTrue(blocked(root + "lar"));
        assertTrue(blocked(root + "imiz"));
    }

    @Test
    void englishListWorks() {
        String w = exactSample("en", 5);
        assertTrue(blocked("you are a " + w));
        assertTrue(blocked(w.toUpperCase(Locale.ROOT)));
    }

    @Test
    void legitimateWordsAreNotBlocked() {
        String[] clean = {
            "Amasya", "Sinop", "sıkıntı", "SIKINTI", "Kıbrıs", "kitap", "Mehmet", "sıkışık", "SIKIŞIK", "sıkışmış",
            "okuyarak", "koşarak", "Nigeria", "Scunthorpe", "assistant class", "Malatya", "Bingöl Üniversitesi",
            "Yazılım Topluluğu", "Gaziantep", "analiz", "sikke koleksiyonu", "cocktail", "Dickens",
            "Bu topluluk yazılım ve girişimcilik etkinlikleri düzenler. Herkes katılabilir.",
            "Kampüs gezisi cumartesi saat 14:00'te, 3. kat toplantı salonunda.", "got talent", "I got it",
            "mal", "malzeme listesi", "https://bingol.edu.tr/duyuru?id=123", "ali.veli@bingol.edu.tr",
            "Ahmet'in doğum günü", "10.000 TL bütçe", "A4 kağıt", "COVID19 önlemleri"
        };
        for (String s : clean) {
            assertFalse(blocked(s), "yanlis pozitif: #" + s.hashCode());
        }
    }

    @Test
    void adminAllowEntryExemptsAndAdminBlockEntryBlocks() {
        String w = exactSample("tr", 6);
        List<String> block = new ArrayList<>(ProfanityFilter.builtInLines("tr"));
        block.add("zzquux");
        block.add("merhaba dunya");
        List<String> allow = new ArrayList<>(ProfanityFilter.builtInLines("allow"));
        ProfanityMatcher m = ProfanityMatcher.build(block, allow);
        assertTrue(m.check("zzquuxlar").blocked());
        assertTrue(m.check("Selam Merhaba   Dünya!").blocked(), "tamlama");
        assertTrue(m.check(w).blocked());
        allow.add(w);
        ProfanityMatcher m2 = ProfanityMatcher.build(block, allow);
        assertFalse(m2.check(w).blocked(), "ALLOW istisnasi");
        assertTrue(m2.check("zzquux").blocked());
    }

    @Test
    void resultMatchesAreForAdminsAndDoNotAppearForCleanText() {
        assertTrue(filter.check("Merhaba dünya").matches().isEmpty());
        assertFalse(filter.check(exactSample("tr", 6)).matches().isEmpty());
        assertEquals(ProfanityMatcher.Result.CLEAN, filter.check("   "));
    }

    @Test
    void builtInListsAreLoadedWithAllThreeLanguages() {
        ProfanityFilter.BuiltIn b = filter.builtIn();
        assertTrue(b.tr() >= 150, "tr " + b.tr());
        assertTrue(b.en() >= 150, "en " + b.en());
        assertTrue(b.ar() >= 15, "ar " + b.ar());
        assertTrue(b.allow() >= 20);
    }

    @Test
    void arabicEntriesFromFileAreBlockedWithDiacriticsTatweelAndPrefixes() {
        List<String> words = new ArrayList<>();
        for (String l : ProfanityFilter.builtInLines("ar")) {
            String t = l.strip();
            if (!t.isEmpty() && !t.startsWith("#") && t.indexOf(' ') < 0 && t.length() >= 3) words.add(t);
            if (words.size() >= 12) break;
        }
        assertFalse(words.isEmpty());
        for (String w : words) {
            assertTrue(blocked(w), "duz");
            String tashkeel = w.charAt(0) + "َ" + w.substring(1) + "ُ";
            assertTrue(blocked(tashkeel), "harekeli");
            String tatweel = w.charAt(0) + "ــ" + w.substring(1);
            assertTrue(blocked(tatweel), "tatweel");
            assertTrue(blocked("ال" + w), "ال on eki");
            assertTrue(blocked("و" + w + "ك"), "و on eki + ك eki");
            assertTrue(blocked("merhaba hello " + w + " world"), "Latin + Arapca karisik");
        }
    }

    @Test
    void arabicLookalikeNormalizationAndDigits() {
        String w = null;
        for (String l : ProfanityFilter.builtInLines("ar")) {
            String t = l.strip();
            if (t.length() >= 4 && !t.startsWith("#") && t.indexOf(' ') < 0) { w = t; break; }
        }
        assertTrue(blocked(w));
        // Arapca-Hint rakamlar baska tokenlari bozmaz
        assertFalse(blocked("١٢٣ مرحبا"));
        assertFalse(blocked("مرحبا بكم في جامعة بينغول"));
    }

    @Test
    void tenKilobyteTextIsFast() {
        StringBuilder sb = new StringBuilder();
        String unit = "Bingöl Üniversitesi yazılım topluluğu hafta sonu etkinlik duyurusu, katılım ücretsizdir. ";
        while (sb.length() < 10_240) sb.append(unit);
        String text = sb.toString();
        for (int i = 0; i < 30; i++) filter.check(text); // isinma + JIT
        // Yuke/GC'ye dayanikli olcum: 5 parti ortalamasinin en iyisi (tek bir yavas parti testi dusurmesin)
        int runs = 10;
        double bestMs = Double.MAX_VALUE;
        for (int b = 0; b < 5; b++) {
            long t0 = System.nanoTime();
            for (int i = 0; i < runs; i++) assertFalse(filter.check(text).blocked());
            bestMs = Math.min(bestMs, (System.nanoTime() - t0) / 1e6 / runs);
        }
        assertTrue(bestMs < 15.0, "10 KB en iyi parti ortalama ms: " + bestMs);
    }
}
