package edu.bingol.backend.academic;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Kullanicinin profilindeki fakulte/bolum/sinif (kapsam suzgeci icin). Duz SQL: user paketine bagimlilik olusmaz. */
@Component
public class AcademicAudience {

    public record Who(String department, String faculty, String grade) {
        public boolean complete() {
            return department != null && !department.isBlank();
        }
    }

    private final JdbcTemplate jdbc;

    public AcademicAudience(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Who of(Long userId) {
        List<Who> r = jdbc.query("SELECT department, faculty, grade FROM app_user WHERE id = ?",
                (rs, i) -> new Who(rs.getString(1), rs.getString(2), rs.getString(3)), userId);
        return r.isEmpty() ? new Who(null, null, null) : r.get(0);
    }
}
