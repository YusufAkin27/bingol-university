package edu.bingol.backend.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

/**
 * Kullanici listesi filtreleri ve siralamasi. SQL yalnizca sabit parcalardan kurulur; degerler baglanir,
 * siralama alani beyaz listeden secilir, LIKE ozel karakterleri kacirilir.
 */
public record UserFilter(String q, UserStatus status, Role role, String faculty, String department,
                         Short classYear, String language, Boolean verified) {

    /** WHERE govdesi (basinda "WHERE" yok; bos filtre icin "TRUE") ve baglanacak degerler. */
    public record Where(String sql, MapSqlParameterSource params) {}

    /** Siralama alani beyaz listesi: istemci adi -> SQL ifadesi. */
    private static final Map<String, String> SORT_COLUMNS = Map.of(
            "createdAt", "created_at",
            "lastSeenAt", "last_seen_at",
            "displayName", "lower(display_name)");

    public Where where() {
        List<String> c = new ArrayList<>();
        MapSqlParameterSource p = new MapSqlParameterSource();
        if (q != null && !q.isBlank()) {
            c.add("(display_name ILIKE :q ESCAPE '\\' OR email ILIKE :q ESCAPE '\\')");
            p.addValue("q", "%" + escapeLike(q.trim()) + "%");
        }
        if (status != null) {
            c.add("status = :status");
            p.addValue("status", status.name());
        }
        if (role != null) {
            c.add("role = :role");
            p.addValue("role", role.name());
        }
        if (notBlank(faculty)) {
            c.add("faculty = :faculty");
            p.addValue("faculty", faculty.trim());
        }
        if (notBlank(department)) {
            c.add("department = :department");
            p.addValue("department", department.trim());
        }
        if (classYear != null) {
            c.add("class_year = :classYear");
            p.addValue("classYear", classYear);
        }
        if (notBlank(language)) {
            c.add("language = :language");
            p.addValue("language", language.trim());
        }
        if (verified != null) {
            c.add("email_verified = :verified");
            p.addValue("verified", verified);
        }
        return new Where(c.isEmpty() ? "TRUE" : String.join(" AND ", c), p);
    }

    /**
     * "alan,asc|desc" bicimini ORDER BY ifadesine cevirir; bilinmeyen alan/yon 400. Bos ise en yeni kayit once.
     * Esitlikte id ile kararli siralama; bos (NULL) degerler sona.
     */
    public static String orderBy(String sort) {
        String field = "createdAt";
        String dir = "DESC";
        if (sort != null && !sort.isBlank()) {
            String[] parts = sort.split(",", -1);
            field = parts[0].trim();
            if (parts.length > 2) {
                throw badSort();
            }
            if (parts.length == 2) {
                dir = switch (parts[1].trim().toLowerCase(java.util.Locale.ROOT)) {
                    case "asc" -> "ASC";
                    case "desc" -> "DESC";
                    default -> throw badSort();
                };
            }
        }
        String col = SORT_COLUMNS.get(field);
        if (col == null) {
            throw badSort();
        }
        return col + " " + dir + " NULLS LAST, id " + dir;
    }

    /** LIKE ozel karakterlerini (\, %, _) kacirir (ESCAPE '\'). */
    public static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }

    private static ApiException badSort() {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sıralama.");
    }
}
