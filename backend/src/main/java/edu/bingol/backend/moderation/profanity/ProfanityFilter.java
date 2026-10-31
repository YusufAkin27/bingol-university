package edu.bingol.backend.moderation.profanity;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Uygunsuz ifade denetimi. Yerlesik liste kaynak dosyalardan (moderation/profanity-tr|en|ar.txt + allow),
 * ozel kelimeler DB'den (profanity_term) gelir; derlenmis esleyici onbelleklenir ve yonetici degisikliginde
 * hemen (bu ornekte) / TTL icinde (diger orneklerde) tazelenir. Kelimeler log'a yazilmaz.
 */
@Service
public class ProfanityFilter {

    private static final Logger log = LoggerFactory.getLogger(ProfanityFilter.class);
    public static final String SOURCE = "LDNOOBW (CC-BY-4.0)";

    /** Yerlesik liste ozeti (kelime sayilari). */
    public record BuiltIn(int tr, int en, int ar, int allow, String source) {}

    private record Snapshot(ProfanityMatcher matcher, long loadedAt, Map<String, ProfanityCategory> categories) {}

    /** Kategori listeleri (V992): kategori -> yerlesik satirlar (nefret/teror/kendine zarar tr+en; Kurtce PROFANITY'ye eklenir). */
    private record Defaults(List<String> tr, List<String> en, List<String> ar, List<String> allow,
                            Map<ProfanityCategory, List<String>> extra) {}

    private static volatile Defaults defaults;

    private final ProfanityTermRepository repo;
    private final long ttlMs;
    private volatile Snapshot snap;

    public ProfanityFilter(ProfanityTermRepository repo, ProfanityProperties props) {
        this.repo = repo;
        this.ttlMs = Math.max(1, props.cacheTtlSeconds()) * 1000L;
    }

    /** Testler icin: yalnizca yerlesik liste. */
    public static ProfanityFilter builtInOnly() {
        return new ProfanityFilter(null, new ProfanityProperties(true, ProfanityProperties.Mode.BLOCK, 30));
    }

    public ProfanityMatcher.Result check(String text) {
        if (text == null || text.isBlank()) {
            return ProfanityMatcher.Result.CLEAN;
        }
        return matcher().check(text);
    }

    public String normalized(String text) {
        return matcher().normalized(text);
    }

    public BuiltIn builtIn() {
        Defaults d = defaults();
        return new BuiltIn(count(d.tr), count(d.en), count(d.ar), count(d.allow), SOURCE);
    }

    /** Yerlesik kategori basina kelime sayisi (kategori listeleri; PROFANITY'de Kurtce dosya dahil, ana listeler haric). */
    public Map<ProfanityCategory, Integer> builtInCategoryCounts() {
        Map<ProfanityCategory, Integer> m = new EnumMap<>(ProfanityCategory.class);
        for (ProfanityCategory c : ProfanityCategory.values()) {
            m.put(c, count(defaults().extra.getOrDefault(c, List.of())));
        }
        return m;
    }

    /** Eslesmenin en siddetli kategorisi (eslesme yoksa/bilinmiyorsa PROFANITY). */
    public ProfanityCategory categoryOf(ProfanityMatcher.Result res) {
        if (res == null || res.matches().isEmpty()) {
            return ProfanityCategory.PROFANITY;
        }
        Map<String, ProfanityCategory> cats = current().categories;
        ProfanityCategory best = ProfanityCategory.PROFANITY;
        for (String name : res.matches()) {
            ProfanityCategory c = cats.get(name);
            if (c != null && c.severity() > best.severity()) {
                best = c;
            }
        }
        return best;
    }

    /** Matcher'in satirdan dondurdugu ad: baştaki =*! isaretleri atilmis kelime. */
    static String wordOf(String line) {
        String l = line.strip();
        int i = 0;
        while (i < l.length() && "=*!".indexOf(l.charAt(i)) >= 0) {
            i++;
        }
        return l.substring(i).strip();
    }

    /** Yonetici degisikliginden sonra hemen tazele. */
    public void refresh() {
        snap = build();
    }

    private ProfanityMatcher matcher() {
        return current().matcher;
    }

    private Snapshot current() {
        Snapshot s = snap;
        if (s == null || System.currentTimeMillis() - s.loadedAt > ttlMs) {
            synchronized (this) {
                s = snap;
                if (s == null || System.currentTimeMillis() - s.loadedAt > ttlMs) {
                    s = build();
                    snap = s;
                }
            }
        }
        return s;
    }

    private Snapshot build() {
        Defaults d = defaults();
        List<String> block = new ArrayList<>(d.tr.size() + d.en.size() + d.ar.size() + 64);
        block.addAll(d.tr);
        block.addAll(d.en);
        block.addAll(d.ar);
        Map<String, ProfanityCategory> cats = new HashMap<>();
        // Kategori listeleri (V992): kelime -> kategori; en siddetli kategori kalir
        d.extra.forEach((cat, lines) -> {
            block.addAll(lines);
            for (String l : lines) {
                String w = wordOf(l);
                if (!w.isEmpty() && !w.startsWith("#")) {
                    cats.merge(w, cat, (a, b) -> a.severity() >= b.severity() ? a : b);
                }
            }
        });
        List<String> allow = new ArrayList<>(d.allow);
        if (repo != null) {
            try {
                for (ProfanityTerm t : repo.findAllByOrderByIdAsc()) {
                    (t.getKind() == ProfanityTerm.Kind.BLOCK ? block : allow).add(t.getTerm());
                    if (t.getKind() == ProfanityTerm.Kind.BLOCK && t.getCategory() != null) {
                        cats.merge(wordOf(t.getTerm()), t.getCategory(), (a, b) -> a.severity() >= b.severity() ? a : b);
                    }
                }
            } catch (RuntimeException e) {
                // DB okunamazsa yerlesik liste ile devam; kelime/ayrinti log'a yazilmaz
                log.warn("Ozel kelimeler okunamadi, yerlesik liste kullaniliyor: {}", e.getClass().getSimpleName());
            }
        }
        return new Snapshot(ProfanityMatcher.build(block, allow), System.currentTimeMillis(), cats);
    }

    private static int count(List<String> lines) {
        int n = 0;
        for (String l : lines) {
            String t = l.strip();
            if (!t.isEmpty() && !t.startsWith("#")) {
                n++;
            }
        }
        return n;
    }

    /** Yerlesik dosya satirlari (testler dosyadan okur; kaynak koda kelime yazilmaz). lang: tr | en | ar | allow. */
    public static List<String> builtInLines(String lang) {
        Defaults d = defaults();
        return switch (lang) {
            case "tr" -> d.tr;
            case "en" -> d.en;
            case "ar" -> d.ar;
            case "ku" -> d.extra.get(ProfanityCategory.PROFANITY);
            case "hate" -> d.extra.get(ProfanityCategory.HATE);
            case "terror" -> d.extra.get(ProfanityCategory.TERROR);
            case "selfharm" -> d.extra.get(ProfanityCategory.SELF_HARM);
            default -> d.allow;
        };
    }

    private static Defaults defaults() {
        Defaults d = defaults;
        if (d == null) {
            Map<ProfanityCategory, List<String>> extra = new EnumMap<>(ProfanityCategory.class);
            extra.put(ProfanityCategory.PROFANITY, read("profanity-ku.txt"));
            extra.put(ProfanityCategory.HATE, concat(read("profanity-hate-tr.txt"), read("profanity-hate-en.txt")));
            extra.put(ProfanityCategory.TERROR, concat(read("profanity-terror-tr.txt"), read("profanity-terror-en.txt")));
            extra.put(ProfanityCategory.SELF_HARM, concat(read("profanity-selfharm-tr.txt"), read("profanity-selfharm-en.txt")));
            d = new Defaults(read("profanity-tr.txt"), read("profanity-en.txt"), read("profanity-ar.txt"),
                    read("profanity-allow-tr.txt"), extra);
            defaults = d;
        }
        return d;
    }

    private static List<String> concat(List<String> a, List<String> b) {
        List<String> out = new ArrayList<>(a);
        out.addAll(b);
        return out;
    }

    private static List<String> read(String name) {
        List<String> out = new ArrayList<>();
        try (InputStream in = ProfanityFilter.class.getResourceAsStream("/moderation/" + name)) {
            if (in == null) {
                log.error("Uygunsuz ifade listesi bulunamadi: {}", name);
                return out;
            }
            try (BufferedReader r = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    if (!line.isEmpty() && line.charAt(0) == 0xFEFF) {
                        line = line.substring(1);
                    }
                    out.add(line);
                }
            }
        } catch (IOException e) {
            log.error("Uygunsuz ifade listesi okunamadi: {}", name);
        }
        return out;
    }
}
