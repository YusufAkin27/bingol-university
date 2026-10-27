package edu.bingol.backend.academic;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Hesap silmede (KVKK) kisisel ders programi, sinav, donem ve duyuru okundu kayitlarini siler. AccountDataPurger cagirir. */
@Component
public class AcademicAccountPurger {

    static final List<String> DELETES = List.of(
            "DELETE FROM tt_exam WHERE user_id = ?",
            "DELETE FROM tt_session WHERE course_id IN (SELECT id FROM tt_course WHERE user_id = ?)",
            "DELETE FROM tt_course WHERE user_id = ?",
            "DELETE FROM tt_semester WHERE user_id = ?",
            "DELETE FROM announcement_read WHERE user_id = ?");

    private final JdbcTemplate jdbc;

    public AcademicAccountPurger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void purge(Long userId) {
        DELETES.forEach(sql -> jdbc.update(sql, userId));
    }
}
