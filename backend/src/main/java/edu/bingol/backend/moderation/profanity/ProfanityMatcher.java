package edu.bingol.backend.moderation.profanity;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Degismez, derlenmis uygunsuz ifade esleyicisi (Spring'siz; birim testlenebilir).
 *
 * <p>Giris satirlari: {@code [isaretler]kelime}; isaretler {@code =} tam eslesme, {@code *} metin icinde gecme,
 * {@code !} sert (cift harf sikistirmasi yok); isaretsiz = kok + en fazla 7 harf ek. Bosluklu giris tamlamadir.
 * Arapca girisler yalnizca tam kok eslesmesi yapar (on/son ek soyma ile). Izin satirlari (ALLOW) bir sozcugu
 * (ve en fazla 4 harf ekini) engellemeden muaf tutar.
 */
public final class ProfanityMatcher {

    /** blocked + eslesen kokler. Eslesmeler YALNIZCA yonetici/log icindir, kullaniciya yansitilmaz. */
    public record Result(boolean blocked, List<String> matches) {
        public static final Result CLEAN = new Result(false, List.of());
    }

    private static final int MAX_CHARS = 50_000;
    private static final int MAX_SUFFIX = 7;
    private static final int MAX_ALLOW_SUFFIX = 4;
    /** Izin satirinin gevsek (ı->i) bicimi icin en az uzunluk (T-023). */
    private static final int LOOSE_ALLOW_MIN = 7;
    private static final String[] AR_PREFIXES = {"وال", "فال", "بال", "كال", "لل", "ال", "و", "ف", "ب", "ل", "ك"};
    private static final String[] AR_SUFFIXES = {"ات", "ين", "ون", "ان", "ها", "هم", "كم", "نا", "ك", "ي", "ه"};

    private final Map<String, String> exact1 = new HashMap<>();
    private final Map<String, String> exact2 = new HashMap<>();
    private final Map<String, String> whole1 = new HashMap<>();   // tam eslesme + * kokleri (sozcuk cifti icin)
    private final Map<String, String> whole2 = new HashMap<>();
    private final Map<String, String> prefix1 = new HashMap<>();
    private final Map<String, String> prefix2 = new HashMap<>();
    private final List<String[]> sub1 = new ArrayList<>();
    private final List<String[]> sub2 = new ArrayList<>();
    private final Map<String, String> phrases = new HashMap<>();  // " a b " -> ad
    private final Map<String, String> arabic = new HashMap<>();   // kok (sondaki ه atilmis) -> ad
    private final Set<String> allow = new HashSet<>();       // tam eslesme (ı->i gevsek bicim dahil)
    private final Set<String> allowPrefix = new HashSet<>(); // yazildigi gibi: en fazla 4 harf ek kabul
    private int blockCount;

    private ProfanityMatcher() {}

    public static ProfanityMatcher build(List<String> blockLines, List<String> allowLines) {
        ProfanityMatcher m = new ProfanityMatcher();
        for (String l : blockLines) {
            m.addBlock(l);
        }
        for (String l : allowLines) {
            m.addAllow(l);
        }
        return m;
    }

    public int blockCount() {
        return blockCount;
    }

    /** Isaretleri ayirir; yoksa null. {flags, word} */
    private static String[] parse(String line) {
        if (line == null) return null;
        String l = line.strip();
        if (l.isEmpty() || l.startsWith("#")) return null;
        int i = 0;
        while (i < l.length() && "=*!".indexOf(l.charAt(i)) >= 0) i++;
        String word = l.substring(i).strip();
        return word.isEmpty() ? null : new String[] {l.substring(0, i), word};
    }

    /** Yonetici girdisinin tekil anahtari (isaret + sadelesmis kelime). Gecersizse null. */
    public static String canonical(String line) {
        String[] p = parse(line);
        if (p == null) return null;
        String w = lettersAndSpaces(ProfanityText.fold(p[1]));
        return w.isBlank() ? null : p[0] + w.strip().replaceAll("\\s+", " ");
    }

    private static String lettersAndSpaces(String f) {
        StringBuilder sb = new StringBuilder(f.length());
        for (int i = 0; i < f.length(); i++) {
            char c = f.charAt(i);
            sb.append(Character.isLetter(c) ? c : ' ');
        }
        return sb.toString();
    }

    private void addBlock(String line) {
        String[] p = parse(line);
        if (p == null) return;
        String flags = p[0];
        String name = p[1];
        String f = lettersAndSpaces(ProfanityText.fold(name)).strip().replaceAll("\\s+", " ");
        if (f.isEmpty()) return;
        blockCount++;
        if (ProfanityText.hasArabic(f)) {
            if (f.indexOf(' ') >= 0) {
                StringBuilder sb = new StringBuilder(" ");
                for (String w : f.split(" ")) sb.append(ProfanityText.v2(w)).append(' ');
                phrases.put(sb.toString(), name);
            } else {
                String r = ProfanityText.v2(f);
                if (r.endsWith("ه") && r.length() > 2) r = r.substring(0, r.length() - 1);
                arabic.put(r, name);
            }
            return;
        }
        if (f.indexOf(' ') >= 0) {
            StringBuilder sb = new StringBuilder(" ");
            for (String w : f.split(" ")) sb.append(ProfanityText.v2(w)).append(' ');
            phrases.put(sb.toString(), name);
            return;
        }
        boolean strictFlag = flags.indexOf('!') >= 0;
        boolean exact = flags.indexOf('=') >= 0;
        boolean sub = flags.indexOf('*') >= 0;
        Set<String> forms = new LinkedHashSet<>();
        forms.add(f);
        forms.add(f.replace('ı', 'i')); // dogru yazim ("amcık") ve ASCII ("amcik") ikisi de yakalansin
        for (String fm : forms) {
            String r1 = ProfanityText.v1(fm);
            String r2 = ProfanityText.v2(fm);
            boolean strict = strictFlag || !fm.equals(r2); // cift harfli kokun tekil hali masum sozcuk olabilir (piss/pis, nigger/niger)
            if (sub && fm.length() >= 5) {
                sub1.add(new String[] {r1, name});
                whole1.put(r1, name);
                if (!strict) {
                    sub2.add(new String[] {r2, name});
                    whole2.put(r2, name);
                }
            } else if (exact || fm.length() < 4) {
                exact1.put(r1, name);
                whole1.put(r1, name);
                if (!strict) {
                    exact2.put(r2, name);
                    whole2.put(r2, name);
                }
            } else {
                prefix1.put(r1, name);
                if (!strict) prefix2.put(r2, name);
            }
        }
    }

    private void addAllow(String line) {
        String[] p = parse(line);
        if (p == null) return;
        String f = lettersAndSpaces(ProfanityText.fold(p[1])).strip();
        if (f.isEmpty() || f.indexOf(' ') >= 0) return;
        String strict = ProfanityText.v1(f);
        allow.add(strict);
        // Gevsek (ı->i) bicim yalnizca tam eslesme VE yalnizca uzun sozcuklerde ("sıkıntı" -> "sikinti"). Kisa/orta
        // sozcukte ("sıkı", "sıkış", "sıkıcı") ASCII bicim gercek kufurle cakisir (siki, sikis): T-023, izin vermeyiz.
        if (strict.length() >= LOOSE_ALLOW_MIN) {
            allow.add(ProfanityText.v1(f.replace('ı', 'i')));
        }
        allowPrefix.add(strict);
    }

    // ---- esleme ----

    private boolean allowed(String t1) {
        if (allow.isEmpty()) return false;
        if (allow.contains(t1)) return true;
        for (int k = Math.max(3, t1.length() - MAX_ALLOW_SUFFIX); k < t1.length(); k++) {
            if (allowPrefix.contains(t1.substring(0, k))) return true;
        }
        return false;
    }

    private static String prefixHit(Map<String, String> map, String t) {
        if (map.isEmpty()) return null;
        for (int k = Math.max(4, t.length() - MAX_SUFFIX); k <= t.length(); k++) {
            String hit = map.get(t.substring(0, k));
            if (hit != null) return hit;
        }
        return null;
    }

    /** Yalnizca kok uzunlugu {@code minLen}'i asan eslesmeler (ilk sozcuk tek basina zaten kontrol edilir). */
    private static String prefixHitBeyond(Map<String, String> map, String t, int minLen) {
        if (map.isEmpty()) return null;
        for (int k = Math.max(Math.max(minLen + 1, 4), t.length() - MAX_SUFFIX); k <= t.length(); k++) {
            String hit = map.get(t.substring(0, k));
            if (hit != null) return hit;
        }
        return null;
    }

    private String latinHit(String t1, String t2) {
        boolean same = t1.equals(t2); // tekrar yoksa ikinci bicim ayni sonucu verir
        String h = exact1.get(t1);
        if (h == null && !same) h = exact2.get(t2);
        if (h == null) h = prefixHit(prefix1, t1);
        if (h == null && !same) h = prefixHit(prefix2, t2);
        if (h == null) {
            for (String[] s : sub1) {
                if (t1.contains(s[0])) return s[1];
            }
            if (!same) {
                for (String[] s : sub2) {
                    if (t2.contains(s[0])) return s[1];
                }
            }
        }
        return h;
    }

    private String arabicHit(String t) {
        if (arabic.isEmpty()) return null;
        List<String> stems = new ArrayList<>(4);
        stems.add(t);
        for (String p : AR_PREFIXES) {
            if (t.startsWith(p) && t.length() - p.length() >= (p.length() == 1 ? 3 : 2)) {
                stems.add(t.substring(p.length()));
                break;
            }
        }
        for (String stem : stems) {
            String h = arStem(stem);
            if (h != null) return h;
            for (String s : AR_SUFFIXES) {
                if (stem.endsWith(s) && stem.length() - s.length() >= 3) {
                    h = arStem(stem.substring(0, stem.length() - s.length()));
                    if (h != null) return h;
                }
            }
        }
        return null;
    }

    private String arStem(String s) {
        String h = arabic.get(s);
        if (h == null && s.endsWith("ه") && s.length() > 2) h = arabic.get(s.substring(0, s.length() - 1));
        return h;
    }

    private static final java.util.regex.Pattern LINK_SPLIT = java.util.regex.Pattern.compile("[@/\\:?&=#]+");

    /** Tek bosluksuz parcayi sozcuklere ayirir; ayirici ile bolunmus sozcuk birlestirilmis bicimiyle de eklenir. */
    private static void addChunk(String chunk, List<String> tokens, List<String> extra) {
        String f = ProfanityText.leet(ProfanityText.fold(chunk));
        int before = tokens.size();
        int p = 0;
        while (p < f.length()) {
            while (p < f.length() && !Character.isLetter(f.charAt(p))) p++;
            int s = p;
            while (p < f.length() && Character.isLetter(f.charAt(p))) p++;
            if (p > s) tokens.add(f.substring(s, p));
        }
        if (tokens.size() - before > 1) {
            StringBuilder c = new StringBuilder();
            for (int k = before; k < tokens.size(); k++) c.append(tokens.get(k));
            if (c.length() >= 3) extra.add(c.toString());
        }
    }

    /** Metni sozcuklere ayirir (baglanti/e-posta dahil; ayirici ile bolunmus sozcuk birlestirilir). */
    private static void tokenize(String text, List<String> tokens, List<String> extra) {
        int n = Math.min(text.length(), MAX_CHARS);
        int i = 0;
        while (i < n) {
            while (i < n && Character.isWhitespace(text.charAt(i))) i++;
            int start = i;
            while (i < n && !Character.isWhitespace(text.charAt(i))) i++;
            if (i == start) continue;
            String chunk = text.substring(start, i);
            if (isLinkLike(chunk)) {
                // T-022: baglanti/e-posta bicimi atlatma yolu degil; yapisal ayiricilardan (@ / : ? & = #) bolunur,
                // her parca (alan adi/yol/yerel kisim) ayni eslestirmeden gecer
                for (String piece : LINK_SPLIT.split(chunk)) {
                    if (!piece.isEmpty()) addChunk(piece, tokens, extra);
                }
            } else {
                addChunk(chunk, tokens, extra);
            }
        }
        // tek harflik seri ("s i k t i r"): 3+ ise birlestir
        int run = 0;
        for (int k = 0; k <= tokens.size(); k++) {
            if (k < tokens.size() && tokens.get(k).length() == 1) {
                run++;
            } else {
                if (run >= 3) {
                    StringBuilder c = new StringBuilder();
                    for (int j = k - run; j < k; j++) c.append(tokens.get(j));
                    extra.add(c.toString());
                }
                run = 0;
            }
        }
    }

    private static boolean isLinkLike(String chunk) {
        if (chunk.contains("://") || chunk.regionMatches(true, 0, "www.", 0, 4)) return true;
        int at = chunk.indexOf('@');
        return at > 0 && chunk.indexOf('.', at) > at;
    }

    /** Sadelesmis sozcuk listesi (yonetici "metni dene" kutusu icin). */
    public String normalized(String text) {
        if (text == null) return "";
        List<String> tokens = new ArrayList<>();
        tokenize(text, tokens, new ArrayList<>());
        StringBuilder sb = new StringBuilder();
        for (String t : tokens) {
            if (sb.length() > 0) sb.append(' ');
            sb.append(ProfanityText.v2(t));
        }
        return sb.toString();
    }

    public Result check(String text) {
        if (text == null || text.isBlank()) return Result.CLEAN;
        List<String> tokens = new ArrayList<>();
        List<String> extra = new ArrayList<>();
        tokenize(text, tokens, extra);
        Set<String> hits = new LinkedHashSet<>();
        for (int pass = 0; pass < 2; pass++) {
            for (String t : pass == 0 ? tokens : extra) {
                String t1 = ProfanityText.v1(t);
                if (allowed(t1)) continue;
                String t2 = ProfanityText.v2(t);
                String h = latinHit(t1, t2);
                if (h == null && ProfanityText.hasArabic(t)) h = arabicHit(t2);
                if (h != null) hits.add(h);
            }
        }
        // bitisik iki sozcugun birlesimi (tam eslesme): "gerizekali" <- "geri zekali"
        for (int k = 0; k + 1 < tokens.size(); k++) {
            String a = tokens.get(k);
            String b = tokens.get(k + 1);
            if (a.length() > 4 && b.length() > 4) continue;
            String p = a + b;
            if (p.length() < 5) continue;
            String h = whole1.get(ProfanityText.v1(p));
            if (h == null) h = whole2.get(ProfanityText.v2(p));
            if (h != null) hits.add(h);
        }
        // iki sozcuk birlesimi + ek ("amina koydum"): birlesimi, ILK sozcugu asan bir kok (prefix) yakalar
        for (int k = 0; k + 1 < tokens.size(); k++) {
            String a = ProfanityText.v1(tokens.get(k));
            String b = tokens.get(k + 1);
            if (a.length() < 3 || a.length() > 6 || b.length() > 12) continue;
            String h = prefixHitBeyond(prefix1, a + ProfanityText.v1(b), a.length());
            if (h != null) hits.add(h);
        }
        if (!phrases.isEmpty()) {
            StringBuilder sb = new StringBuilder(" ");
            for (String t : tokens) sb.append(ProfanityText.v2(t)).append(' ');
            String joined = sb.toString();
            for (Map.Entry<String, String> e : phrases.entrySet()) {
                if (joined.contains(e.getKey())) hits.add(e.getValue());
            }
        }
        if (hits.isEmpty()) return Result.CLEAN;
        List<String> out = new ArrayList<>(hits);
        return new Result(true, out.size() > 10 ? out.subList(0, 10) : out);
    }
}
