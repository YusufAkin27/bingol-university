package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.StudentView;
import edu.bingol.backend.search.TrFold;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Ogrenci rehberi (yalniz onayli akademisyen ve kendi servisleri kullanir). Gizlilik kurali TEK yerde: yalniz id, gorunen
 * ad, ogrenci numarasi, fakulte, bolum, sinif cikar; e-posta/avatar/biyografi/cevrimici durum ASLA. Uygun ogrenci =
 * ACTIVE, e-postasi dogrulanmis (ertelenmis degil), silinmemis, profili tamam, rolu USER ve akademisyen DEGIL.
 */
@Component
public class StudentDirectory {

    static final String ELIGIBLE = "u.status = 'ACTIVE' AND u.email_verified = TRUE AND u.verification_deferred = FALSE "
            + "AND u.deleted_at IS NULL AND u.profile_completed_at IS NOT NULL AND u.role = 'USER' "
            + "AND NOT EXISTS (SELECT 1 FROM academician a WHERE a.user_id = u.id)";
    private static final String COLS = "u.id, u.display_name, u.email, u.faculty, u.department, u.grade";
    private static final int IN_CHUNK = 500;

    /** Ic temsil: e-posta yalniz ogrenci numarasini turetmek icindir, disari verilmez. */
    record Person(Long id, String displayName, String studentNo, String faculty, String department, String grade) {
        StudentView view() {
            return new StudentView(id, displayName, studentNo, faculty, department, grade);
        }
    }

    private final JdbcTemplate jdbc;

    public StudentDirectory(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Ada gore (Turkce harf duyarsiz, kismi) ve/veya fakulte-bolum-sinifa gore; kimlige gore artan imec. */
    public List<Person> search(String q, String faculty, String department, String grade, long after, int limit) {
        StringBuilder sql = new StringBuilder("SELECT " + COLS + " FROM app_user u WHERE " + ELIGIBLE + " AND u.id > ?");
        List<Object> args = new ArrayList<>();
        args.add(after);
        if (faculty != null && !faculty.isBlank()) {
            sql.append(" AND u.faculty = ?");
            args.add(faculty.trim());
        }
        if (department != null && !department.isBlank()) {
            sql.append(" AND u.department = ?");
            args.add(department.trim());
        }
        if (grade != null && !grade.isBlank()) {
            sql.append(" AND u.grade = ?");
            args.add(grade.trim());
        }
        String folded = TrFold.fold(q);
        if (!folded.isBlank()) {
            // en cok 3 sozcuk parcasi, hepsi adin herhangi bir yerinde gecmeli (ProfileService aramasiyla ayni katlama)
            for (String t : folded.split(" ", 3)) {
                sql.append(" AND ").append(UserRepository.NAME_FOLD).append(" LIKE ? ESCAPE '\\'");
                args.add("%" + TrFold.escapeLike(t) + "%");
            }
        }
        sql.append(" ORDER BY u.id LIMIT ?");
        args.add(limit);
        return jdbc.query(sql.toString(), (rs, i) -> person(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4),
                rs.getString(5), rs.getString(6)), args.toArray());
    }

    /** Verilen kimliklerden uygun olanlar (uygun olmayanlar sessizce elenir). */
    public Map<Long, Person> eligibleByIds(Collection<Long> ids) {
        return byIds(ids, true);
    }

    /** Gorunen ad/numara cozumleme (uygunluk aranmaz: kayitli ogrenci sonradan askiya alinsa da listede kalir). */
    public Map<Long, Person> labels(Collection<Long> ids) {
        return byIds(ids, false);
    }

    /** Bolum (+ istege bagli sinif) ogrencileri; en cok {@code limit} satir (cagiran limit+1 ister). */
    public List<Person> byDepartment(String department, String grade, int limit) {
        StringBuilder sql = new StringBuilder("SELECT " + COLS + " FROM app_user u WHERE " + ELIGIBLE + " AND u.department = ?");
        List<Object> args = new ArrayList<>();
        args.add(department);
        if (grade != null && !grade.isBlank()) {
            sql.append(" AND u.grade = ?");
            args.add(grade.trim());
        }
        sql.append(" ORDER BY u.id LIMIT ?");
        args.add(limit);
        return jdbc.query(sql.toString(), (rs, i) -> person(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4),
                rs.getString(5), rs.getString(6)), args.toArray());
    }

    private Map<Long, Person> byIds(Collection<Long> ids, boolean eligibleOnly) {
        Set<Long> distinct = new LinkedHashSet<>(ids);
        Map<Long, Person> out = new HashMap<>();
        List<Long> all = new ArrayList<>(distinct);
        for (int i = 0; i < all.size(); i += IN_CHUNK) {
            List<Long> part = all.subList(i, Math.min(all.size(), i + IN_CHUNK));
            String marks = String.join(",", java.util.Collections.nCopies(part.size(), "?"));
            String sql = "SELECT " + COLS + " FROM app_user u WHERE u.id IN (" + marks + ")" + (eligibleOnly ? " AND " + ELIGIBLE : "");
            jdbc.query(sql, rs -> {
                Person p = person(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getString(5),
                        rs.getString(6));
                out.put(p.id(), p);
            }, part.toArray());
        }
        return out;
    }

    private static Person person(Long id, String name, String email, String faculty, String department, String grade) {
        return new Person(id, name, AcademicianApprovalPolicy.studentNo(email), faculty, department, grade);
    }
}
