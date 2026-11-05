package edu.bingol.backend.forum.comment;

import edu.bingol.backend.common.ApiException;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;

/**
 * Yorum metni temizligi (XSS/HTML enjeksiyonu): cikti JSON duz metindir, istemci metin olarak cizer; yine de sunucu
 * etiket benzeri parcalari, kontrol ve yon-ters (bidi) karakterlerini atar. Kasitli SINIRLI: "a < b" gibi duz metin
 * bozulmaz, yalnizca `<tag ...>` / `</tag>` / yorum bloklari silinir.
 */
final class ForumCommentText {

    private ForumCommentText() {}

    private static final Pattern HTML_COMMENT = Pattern.compile("<!--.*?-->", Pattern.DOTALL);
    private static final Pattern TAG = Pattern.compile("</?[A-Za-z][^<>]{0,300}>");
    private static final Pattern CONTROL = Pattern.compile("[\\p{Cc}&&[^\\n]]");
    /** Yon degistirme (RLO/LRO/isolate), sifir genislik bosluk, BOM, word joiner: gorunmez yanilticilik. ZWNJ/ZWJ kalir. */
    private static final Pattern INVISIBLE = Pattern.compile("[\u202A-\u202E\u2066-\u2069\u200B\uFEFF\u2060]");
    private static final Pattern EDGE_WS = Pattern.compile("^[\\s\\p{Z}]+|[\\s\\p{Z}]+$");
    private static final Pattern MANY_NL = Pattern.compile("\\n{3,}");
    private static final Pattern LINE_TRAIL = Pattern.compile("[ \\t\\p{Z}]+\\n");

    /** Temizler; bos (yalniz bosluk) ise null. */
    static String clean(String raw) {
        if (raw == null) {
            return null;
        }
        String t = raw.replace("\r\n", "\n").replace('\r', '\n').replace('\t', ' ');
        t = INVISIBLE.matcher(t).replaceAll("");
        t = CONTROL.matcher(t).replaceAll("");
        // Etiketleri tekrar tekrar sil: "<scr<script>ipt>" gibi ic ice kurgular tek turda geri olusabilir
        for (int i = 0; i < 4; i++) {
            String before = t;
            t = HTML_COMMENT.matcher(t).replaceAll("");
            t = TAG.matcher(t).replaceAll("");
            if (before.equals(t)) {
                break;
            }
        }
        t = LINE_TRAIL.matcher(t).replaceAll("\n");
        t = EDGE_WS.matcher(t).replaceAll("");
        t = MANY_NL.matcher(t).replaceAll("\n\n");
        return t.isEmpty() ? null : t;
    }

    /** Temizlenmis metni dogrular (bos / uzun). */
    static String require(String raw) {
        String t = clean(raw);
        if (t == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_COMMENT_EMPTY", "Yorum boş olamaz.");
        }
        if (t.codePointCount(0, t.length()) > ForumCommentDtos.MAX_CHARS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "FORUM_COMMENT_TOO_LONG",
                    "Yorum en çok " + ForumCommentDtos.MAX_CHARS + " karakter olabilir.", String.valueOf(ForumCommentDtos.MAX_CHARS));
        }
        return t;
    }
}
