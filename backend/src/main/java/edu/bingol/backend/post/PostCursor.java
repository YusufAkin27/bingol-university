package edu.bingol.backend.post;

import edu.bingol.backend.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import org.springframework.http.HttpStatus;

/** Akış imleci: opak Base64url. latest: (createdAt,id); popular: (score,id). */
public record PostCursor(Instant at, double score, long id) {

    public static String latest(Instant at, long id) {
        return enc("L|" + at + "|" + id);
    }

    public static String popular(double score, long id) {
        return enc("P|" + score + "|" + id);
    }

    /** kind: 'L' veya 'P'; boş imleç null döner (ilk sayfa). */
    public static PostCursor decode(String cursor, char kind) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            String[] p = raw.split("\\|");
            if (p.length != 3 || p[0].charAt(0) != kind) {
                throw new IllegalArgumentException();
            }
            long id = Long.parseLong(p[2]);
            return kind == 'L' ? new PostCursor(Instant.parse(p[1]), 0, id) : new PostCursor(null, Double.parseDouble(p[1]), id);
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    private static String enc(String s) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(s.getBytes(StandardCharsets.UTF_8));
    }
}
