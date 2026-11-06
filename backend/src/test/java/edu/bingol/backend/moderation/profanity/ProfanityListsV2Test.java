package edu.bingol.backend.moderation.profanity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;

/**
 * v2 liste + eslestirme motoru testleri: yanlis pozitif derlemi (masum metinler ENGELLENMEZ), kufur derlemi
 * (cekim/obfuscation dahil ENGELLENIR), her liste girisinin kendi kendine tutarliligi, beyaz liste, normalizasyon, performans.
 * Derlemler test kaynak dosyalaridadir (src/test/resources/profanity); kaynak koda kufur yazilmaz.
 */
class ProfanityListsV2Test {

    private final ProfanityFilter filter = ProfanityFilter.builtInOnly();

    private static List<String> corpus(String name) {
        List<String> out = new ArrayList<>();
        try (InputStream in = ProfanityListsV2Test.class.getResourceAsStream("/profanity/" + name)) {
            if (in == null) throw new IllegalStateException("derlem yok: " + name);
            BufferedReader r = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8));
            String l;
            while ((l = r.readLine()) != null) {
                if (!l.isBlank()) out.add(l);
            }
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
        return out;
    }

    // ---- (a) yanlis pozitif derlemi ----

    @Test
    void cleanCorpusIsNeverBlocked() {
        List<String> all = new ArrayList<>();
        all.addAll(corpus("clean-tr.txt"));
        all.addAll(corpus("clean-en.txt"));
        all.addAll(corpus("clean-ar.txt"));
        assertTrue(all.size() >= 250, "derlem en az 250 madde olmali: " + all.size());
        List<String> bad = new ArrayList<>();
        for (String s : all) {
            ProfanityMatcher.Result r = filter.check(s);
            if (r.blocked()) bad.add(s + " -> " + r.matches());
        }
        assertTrue(bad.isEmpty(), "yanlis pozitifler: " + bad);
    }

    @Test
    void shortRootsAreNeverSubstringMatches() {
        // kok "sik": gercek bir sozcuge gomulu hicbir yerde tetiklenmemeli
        String[] innocent = {"klasik", "klasikleşmek", "basik", "mesela", "kasik", "musiki", "sistem", "tasik", "plastik",
            "elastik", "fantastik", "gimnastik", "Amasya", "ambulans", "Ankara", "tasarım", "kullanıcı", "analiz", "assess",
            "class", "classic", "Scunthorpe", "bass", "passage", "shiitake", "Shitennoji", "cockpit", "Dickens", "Essex"};
        for (String s : innocent) {
            assertFalse(filter.check(s).blocked(), s);
            assertFalse(filter.check("bu " + s + " guzel").blocked(), s);
            assertFalse(filter.check(s.toUpperCase(Locale.forLanguageTag("tr-TR"))).blocked(), s.toUpperCase(Locale.ROOT));
        }
        assertTrue(filter.check("sik").blocked());
        assertTrue(filter.check("Bu bir sik").blocked());
    }

    @Test
    void neutralIdentityWordsAreNeverBlocked() {
        String[] ok = {"Kürt", "Kürtler", "Türk", "Türkler", "Arap", "Araplar", "Yahudi", "Yahudiler", "gay", "eşcinsel",
            "engelli", "siyah", "Müslüman", "Hristiyan", "Alevi", "Ermeni", "Çingene", "Suriyeli", "mülteci",
            "Kurdish", "Turkish", "Arab", "Jewish", "Muslim", "gay", "lesbian", "transgender", "disabled", "black", "white",
            "كردي", "تركي", "يهودي", "مسلم", "مثلي", "أسود"};
        for (String s : ok) assertFalse(filter.check(s).blocked(), s);
    }

    // ---- (b) kufur derlemi ----

    @Test
    void blockedSamplesAreAllBlocked() {
        List<String> samples = corpus("blocked-samples.txt");
        assertTrue(samples.size() >= 150, "orneklem " + samples.size());
        List<String> missed = new ArrayList<>();
        for (String s : samples) {
            if (!filter.check(s).blocked()) missed.add(s);
        }
        assertTrue(missed.isEmpty(), "engellenmeyen: " + missed);
    }

    /** Her yerlesik giris (v2 dosyalari) kendi kendini engellemeli: kayitli ama calismayan giris olmaz. */
    @Test
    void everyV2EntryBlocksItself() {
        List<String> miss = new ArrayList<>();
        int total = 0;
        for (String lang : new String[] {"tr", "en", "ar", "hate"}) {
            for (String l : ProfanityFilter.builtInLines(lang)) {
                String t = l.strip();
                if (t.isEmpty() || t.startsWith("#")) continue;
                String w = ProfanityFilter.wordOf(t);
                if (w.isEmpty()) continue;
                total++;
                if (!filter.check(w).blocked()) miss.add(lang + ":" + t);
            }
        }
        assertTrue(total > 2000, "toplam giris " + total);
        // tek bir tutarsizlik yok sayilmaz; liste dosyasindaki istisnalar izin listesiyle cakisiyorsa raporlanir
        assertTrue(miss.isEmpty(), "kendini engellemeyen girisler (" + miss.size() + "): " + miss.subList(0, Math.min(40, miss.size())));
    }

    @Test
    void inflectionsAndObfuscationAreCaught() {
        // Turkce cekim: kok + ek zinciri
        assertTrue(filter.check("amcığına").blocked());
        assertTrue(filter.check("orospulara").blocked());
        assertTrue(filter.check("yarağımdan").blocked());
        assertTrue(filter.check("taşaklarımızı").blocked());
        // Ingilizce ek
        assertTrue(filter.check("fucked").blocked());
        assertTrue(filter.check("fucking").blocked());
        assertTrue(filter.check("shitheads").blocked());
        // obfuscation
        assertTrue(filter.check("f.u.c.k").blocked());
        assertTrue(filter.check("s h i t").blocked());
        assertTrue(filter.check("$h1t").blocked());
        assertTrue(filter.check("b1tch").blocked());
        assertTrue(filter.check("s1kt1r").blocked());
        assertTrue(filter.check("0r0spu").blocked());
        assertTrue(filter.check("AMCIK").blocked());
        assertTrue(filter.check("AMCİK").blocked());
        // masum benzerleri engellenmez
        assertFalse(filter.check("fuchsia").blocked());
        assertFalse(filter.check("shiitake").blocked());
        assertFalse(filter.check("bitcoin").blocked());
        assertFalse(filter.check("spicy").blocked());
    }

    // ---- (c) beyaz liste, normalizasyon, performans ----

    @Test
    void whitelistExemptsEvenWhenFilterWouldTrigger() {
        List<String> block = new ArrayList<>(ProfanityFilter.builtInLines("tr"));
        block.add("+zzquuxorospu");
        List<String> allow = new ArrayList<>(ProfanityFilter.builtInLines("allow"));
        ProfanityMatcher m = ProfanityMatcher.build(block, allow);
        assertTrue(m.check("zzquuxorospu").blocked());
        assertTrue(m.check("zzquuxorospular").blocked());
        allow.add("zzquuxorospu");
        ProfanityMatcher m2 = ProfanityMatcher.build(block, allow);
        assertFalse(m2.check("zzquuxorospu").blocked());
        assertFalse(m2.check("zzquuxorospular").blocked(), "izin kok + bilinen ek");
        // rastgele ek izinli sayilmaz: izin kokuna eklenen kufur engellenir
        assertTrue(m2.check("zzquuxorospu amk").blocked());
    }

    @Test
    void turkishCaseAndDottedI() {
        assertFalse(filter.check("SIKINTI").blocked());
        assertFalse(filter.check("sıkıntı").blocked());
        assertFalse(filter.check("SIKIŞIK").blocked());
        assertFalse(filter.check("KLASİK").blocked());
        assertFalse(filter.check("KLASIK").blocked());
        assertTrue(filter.check("SİKTİR").blocked());
        assertTrue(filter.check("SIKTIR").blocked());
        assertTrue(filter.check("siktir".toUpperCase(Locale.forLanguageTag("tr-TR"))).blocked());
        assertTrue(filter.check("ORSPU".toLowerCase(Locale.ROOT)).blocked());
    }

    @Test
    void arabicNormalization() {
        assertTrue(filter.check("كِسْ").blocked(), "harekeli");
        assertTrue(filter.check("كـــس").blocked(), "kasida");
        assertTrue(filter.check("الكس").blocked(), "ال");
        assertTrue(filter.check("شرموطه").blocked(), "ta marbuta -> ha");
        assertTrue(filter.check("شرموطة").blocked());
        assertTrue(filter.check("ابن   الكلب").blocked(), "tamlama bosluk");
        assertTrue(filter.check("ابـــن الكلب").blocked());
        assertFalse(filter.check("كأس").blocked());
        assertFalse(filter.check("كسر").blocked());
        assertFalse(filter.check("زبدة").blocked());
        assertFalse(filter.check("مرحبا بكم").blocked());
    }

    @Test
    void largeTextsAreFastAndLinear() {
        StringBuilder sb = new StringBuilder();
        String unit = "Bingöl Üniversitesi yazılım topluluğu hafta sonu klasik müzik etkinliği duyurusu, katılım ücretsizdir. "
                + "Mesela sıkıntı yoksa analiz sistemi tasarım kullanıcı class assess passage. ";
        while (sb.length() < 10_000) sb.append(unit);
        String text = sb.toString();
        for (int i = 0; i < 30; i++) filter.check(text); // isinma
        double best = Double.MAX_VALUE;
        for (int b = 0; b < 5; b++) {
            long t0 = System.nanoTime();
            for (int i = 0; i < 10; i++) assertFalse(filter.check(text).blocked());
            best = Math.min(best, (System.nanoTime() - t0) / 1e6 / 10);
        }
        assertTrue(best < 50.0, "10 000 karakter en iyi ortalama ms: " + best);

        // hostile girdiler: regex felaketi yok, dogrusal sure
        String[] hostile = {
            "a".repeat(10_000), ("s i ").repeat(2_500), ("s.").repeat(5_000), "-".repeat(10_000),
            ("ab ").repeat(3_300), ("كس ").repeat(100), "ş".repeat(10_000), ("x1 ").repeat(3_300)
        };
        for (String h : hostile) {
            long t0 = System.nanoTime();
            filter.check(h);
            double ms = (System.nanoTime() - t0) / 1e6;
            assertTrue(ms < 250.0, "hostile girdi ms: " + ms);
        }
        // iki kat uzun metin ~ iki kat sure (doğrusal): 10k vs 20k, genis tolerans
        String twice = text + text;
        for (int i = 0; i < 20; i++) filter.check(twice);
        long t0 = System.nanoTime();
        for (int i = 0; i < 10; i++) filter.check(twice);
        double ms2 = (System.nanoTime() - t0) / 1e6 / 10;
        assertTrue(ms2 < 100.0, "20 000 karakter ms: " + ms2);
    }

    @Test
    void v2ListSizesMeetTargets() {
        ProfanityFilter.BuiltIn b = filter.builtIn();
        assertTrue(b.tr() >= 650, "tr " + b.tr());
        assertTrue(b.en() >= 580, "en " + b.en());
        assertTrue(b.ar() >= 430, "ar " + b.ar());
        assertTrue(b.allow() >= 400, "allow " + b.allow());
        assertEquals(b.source(), ProfanityFilter.SOURCE);
    }
}
