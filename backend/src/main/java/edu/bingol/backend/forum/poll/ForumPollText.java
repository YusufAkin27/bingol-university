package edu.bingol.backend.forum.poll;

import java.util.regex.Pattern;

/**
 * Anket metni temizligi (XSS/HTML enjeksiyonu): HTML etiketleri ve kontrol/yon karakterleri atilir, bosluklar tek
 * boslukta birlesir. Cikti JSON duz metindir; istemci HTML yorumlamaz, bu yalniz ikinci savunmadir.
 */
final class ForumPollText {

    private static final Pattern TAG = Pattern.compile("<[^>]*>");
    private static final Pattern CONTROL = Pattern.compile("[\\p{Cc}\\u200B\\u202A-\\u202E\\u2066-\\u2069]");
    private static final Pattern SPACES = Pattern.compile("\\s+");

    private ForumPollText() {}

    /** Temizlenmis metin; bos/yalniz bosluksa null. */
    static String clean(String raw) {
        if (raw == null) {
            return null;
        }
        String s = TAG.matcher(raw).replaceAll(" ");
        s = s.replace("<", " ").replace(">", " ");
        s = SPACES.matcher(s).replaceAll(" ");
        s = CONTROL.matcher(s).replaceAll("").strip();
        return s.isEmpty() ? null : s;
    }
}
