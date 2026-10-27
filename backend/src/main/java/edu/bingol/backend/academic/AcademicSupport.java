package edu.bingol.backend.academic;

import edu.bingol.backend.common.ApiException;
import java.sql.PreparedStatement;
import java.util.Collection;
import java.util.Collections;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;

/** Akademik servislerin ortak yardimcilari (duz SQL: H2 ve PostgreSQL uyumlu). */
final class AcademicSupport {

    private AcademicSupport() {}

    /** INSERT yapar, uretilen `id` degerini dondurur (RETURNING gerekmez). */
    static long insert(JdbcTemplate jdbc, String sql, Object... args) {
        KeyHolder kh = new GeneratedKeyHolder();
        jdbc.update(con -> {
            PreparedStatement ps = con.prepareStatement(sql, new String[] {"id"});
            for (int i = 0; i < args.length; i++) {
                ps.setObject(i + 1, args[i]);
            }
            return ps;
        }, kh);
        Number key = kh.getKey();
        if (key == null) {
            throw new IllegalStateException("id uretilemedi");
        }
        return key.longValue();
    }

    static String placeholders(Collection<?> c) {
        return String.join(",", Collections.nCopies(c.size(), "?"));
    }

    /** Opsiyonel metin: bos -> null; en cok max karakter (aksi 422 COURSE_FIELD_TOO_LONG). */
    static String optText(String v, int max, String field) {
        if (v == null || v.isBlank()) {
            return null;
        }
        String t = v.strip();
        if (t.length() > max) {
            throw tooLong(field, max);
        }
        return t;
    }

    static String reqText(String v, int max, String field) {
        if (v == null || v.isBlank()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_INVALID", "{0} zorunlu.", field);
        }
        return optText(v, max, field);
    }

    static ApiException tooLong(String field, int max) {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_FIELD_TOO_LONG",
                "{0} en fazla {1} karakter olabilir.", field, String.valueOf(max));
    }

    /** Yonetici icerigi icin ayni sinir kontrolu, farkli hata kodu. */
    static String adminText(String v, int max, String field, boolean required, String code) {
        if (v == null || v.isBlank()) {
            if (required) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, code, "{0} geçersiz.", field);
            }
            return null;
        }
        String t = v.strip();
        if (t.length() > max) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, code, "{0} geçersiz.", field);
        }
        return t;
    }

    static ApiException notFound(String code, String msg) {
        return new ApiException(HttpStatus.NOT_FOUND, code, msg);
    }
}
