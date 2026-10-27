package edu.bingol.backend.moderation.profanity;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
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

    private record Snapshot(ProfanityMatcher matcher, long loadedAt) {}

    private record Defaults(List<String> tr, List<String> en, List<String> ar, List<String> allow) {}

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

    /** Yonetici degisikliginden sonra hemen tazele. */
    public void refresh() {
        snap = build();
    }

    private ProfanityMatcher matcher() {
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
        return s.matcher;
    }

    private Snapshot build() {
        Defaults d = defaults();
        List<String> block = new ArrayList<>(d.tr.size() + d.en.size() + d.ar.size() + 64);
        block.addAll(d.tr);
        block.addAll(d.en);
        block.addAll(d.ar);
        List<String> allow = new ArrayList<>(d.allow);
        if (repo != null) {
            try {
                for (ProfanityTerm t : repo.findAllByOrderByIdAsc()) {
                    (t.getKind() == ProfanityTerm.Kind.BLOCK ? block : allow).add(t.getTerm());
                }
            } catch (RuntimeException e) {
                // DB okunamazsa yerlesik liste ile devam; kelime/ayrinti log'a yazilmaz
                log.warn("Ozel kelimeler okunamadi, yerlesik liste kullaniliyor: {}", e.getClass().getSimpleName());
            }
        }
        return new Snapshot(ProfanityMatcher.build(block, allow), System.currentTimeMillis());
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
            default -> d.allow;
        };
    }

    private static Defaults defaults() {
        Defaults d = defaults;
        if (d == null) {
            d = new Defaults(read("profanity-tr.txt"), read("profanity-en.txt"), read("profanity-ar.txt"),
                    read("profanity-allow-tr.txt"));
            defaults = d;
        }
        return d;
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
