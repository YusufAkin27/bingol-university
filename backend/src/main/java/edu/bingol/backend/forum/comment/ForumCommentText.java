package edu.bingol.backend.forum.comment;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import org.springframework.http.HttpStatus;

/**
 * Yorum metni temizligi: {@link ForumTextSanitizer#multiLine} cephesi (QA5-10, tek temizleyici). Cikti JSON duz metindir,
 * istemci metin olarak cizer; etiket benzeri parcalar, kontrol ve yon-ters (bidi) karakterleri atilir. "a < b" gibi
 * duz metin bozulmaz.
 */
final class ForumCommentText {

    private ForumCommentText() {}

    /** Temizler; bos (yalniz bosluk) ise null. */
    static String clean(String raw) {
        if (raw == null) {
            return null;
        }
        String t = ForumTextSanitizer.multiLine(raw);
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
