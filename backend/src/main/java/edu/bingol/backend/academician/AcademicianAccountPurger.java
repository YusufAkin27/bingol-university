package edu.bingol.backend.academician;

import edu.bingol.backend.media.PrivateMediaStore;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) akademisyen alani kayitlari: akademisyen satiri ve dersleri silinir (ders silinince oturum, yoklama,
 * kayit, saat ve duyurular da), baskasinin dersindeki ogrenci kayitlari/yoklamalari silinir, "kim yapti" izleri
 * (reviewed_by, marked_by, created_by) bosaltilir. AccountDataPurger cagirir; karar matrisi docs/DATABASE.md.
 * Cocuk satirlar acikca silinir (FK CASCADE'e guvenilmez: H2 testlerinde dis anahtar yoktur).
 */
@Component
public class AcademicianAccountPurger {

    /** Bir derse bagli cocuk tablolar (sira onemli: yoklama -> oturum -> kayit/saat/duyuru). {?} = ders kimligi. */
    static final List<String> COURSE_CHILD_DELETES = List.of(
            "DELETE FROM ac_attendance WHERE session_id IN (SELECT id FROM ac_session WHERE course_id = ?)",
            "DELETE FROM ac_scan_request WHERE session_id IN (SELECT id FROM ac_session WHERE course_id = ?)",
            "DELETE FROM ac_session WHERE course_id = ?",
            "DELETE FROM ac_notice_file WHERE course_id = ?",
            "DELETE FROM ac_enrollment WHERE course_id = ?",
            "DELETE FROM ac_course_slot WHERE course_id = ?",
            "DELETE FROM ac_notice WHERE course_id = ?");

    /** Kullanici kimligiyle: once "kim yapti" izleri, sonra sahibi oldugu dersler, sonra ogrenci/akademisyen satirlari. */
    static final List<String> USER_SQL = List.of(
            "UPDATE academician SET reviewed_by = NULL WHERE reviewed_by = ?",
            "UPDATE ac_attendance SET marked_by = NULL WHERE marked_by = ?",
            "UPDATE ac_attendance SET revoked_by = NULL WHERE revoked_by = ?",
            "UPDATE ac_notice SET created_by = NULL WHERE created_by = ?",
            "UPDATE ac_notice_file SET uploaded_by = NULL WHERE uploaded_by = ?",
            "UPDATE ac_scan_request SET decided_by = NULL WHERE decided_by = ?",
            "DELETE FROM ac_scan_request WHERE student_id = ?",
            "DELETE FROM ac_attendance WHERE student_id = ?",
            "DELETE FROM ac_enrollment WHERE student_id = ?");

    private static final List<String> OWNED_COURSE_CHILDREN = List.of(
            "DELETE FROM ac_attendance WHERE session_id IN (SELECT id FROM ac_session WHERE course_id IN "
                    + "(SELECT id FROM ac_course WHERE owner_id = ?))",
            "DELETE FROM ac_scan_request WHERE session_id IN (SELECT id FROM ac_session WHERE course_id IN "
                    + "(SELECT id FROM ac_course WHERE owner_id = ?))",
            "DELETE FROM ac_session WHERE course_id IN (SELECT id FROM ac_course WHERE owner_id = ?)",
            "DELETE FROM ac_notice_file WHERE course_id IN (SELECT id FROM ac_course WHERE owner_id = ?)",
            "DELETE FROM ac_enrollment WHERE course_id IN (SELECT id FROM ac_course WHERE owner_id = ?)",
            "DELETE FROM ac_course_slot WHERE course_id IN (SELECT id FROM ac_course WHERE owner_id = ?)",
            "DELETE FROM ac_notice WHERE course_id IN (SELECT id FROM ac_course WHERE owner_id = ?)",
            "DELETE FROM ac_course WHERE owner_id = ?");

    private final JdbcTemplate jdbc;
    private final PrivateMediaStore store;

    public AcademicianAccountPurger(JdbcTemplate jdbc, PrivateMediaStore store) {
        this.jdbc = jdbc;
        this.store = store;
    }

    /** Ogretim elemaninin dersleri silinirken duyuru dosyalarinin depodaki nesneleri de silinir (yetim birakilmaz). */
    public void purge(Long userId) {
        List<String> keys = jdbc.queryForList("SELECT storage_key FROM ac_notice_file WHERE course_id IN "
                + "(SELECT id FROM ac_course WHERE owner_id = ?)", String.class, userId);
        USER_SQL.forEach(sql -> jdbc.update(sql, userId));
        OWNED_COURSE_CHILDREN.forEach(sql -> jdbc.update(sql, userId));
        jdbc.update("DELETE FROM academician WHERE user_id = ?", userId);
        deleteObjects(keys);
    }

    /** Tek dersi cocuklariyla (ve depodaki dosya nesneleriyle) siler (ders silme ucu). */
    public void deleteCourse(Long courseId) {
        List<String> keys = jdbc.queryForList("SELECT storage_key FROM ac_notice_file WHERE course_id = ?", String.class, courseId);
        COURSE_CHILD_DELETES.forEach(sql -> jdbc.update(sql, courseId));
        jdbc.update("DELETE FROM ac_course WHERE id = ?", courseId);
        deleteObjects(keys);
    }

    private void deleteObjects(List<String> keys) {
        keys.forEach(k -> store.delete(NoticeFileService.BUCKET, k));
    }
}
