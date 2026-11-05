package edu.bingol.backend.forum.share;

/** Paylasim karti metin kisaltma (kod noktasi guvenli; bosluklar sadelesir; HTML kacisi gosterim katmanindadir). */
final class ShareTexts {

    private ShareTexts() {}

    static String clip(String s, int max) {
        if (s == null) {
            return "";
        }
        String t = s.replaceAll("\\s+", " ").strip();
        if (t.codePointCount(0, t.length()) <= max) {
            return t;
        }
        return t.substring(0, t.offsetByCodePoints(0, max - 1)).stripTrailing() + "…";
    }
}
