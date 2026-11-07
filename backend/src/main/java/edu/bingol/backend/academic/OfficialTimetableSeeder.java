package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.insert;
import static edu.bingol.backend.academic.AcademicSupport.placeholders;

import edu.bingol.backend.academic.AcademicDtos.TimetableView;
import edu.bingol.backend.academic.OfficialTimetableDtos.ApplyRequest;
import edu.bingol.backend.academic.OfficialTimetableDtos.EntryView;
import edu.bingol.backend.academic.OfficialTimetableDtos.OfficialStatus;
import edu.bingol.backend.academic.OfficialTimetableService.OfficialMatch;
import edu.bingol.backend.academic.TimetableLogic.Entry;
import edu.bingol.backend.common.ApiException;
import java.sql.Time;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Resmi ders programini ogrencinin KISISEL programina (tt_course + tt_session) kopyalar: otomatik tohumlama
 * (GET /api/timetable) ve elle uygulama (POST /api/timetable/official/apply). Duz SQL (H2 + PostgreSQL uyumlu).
 *
 * <p>Kopyalama kurali: ayni dersin farkli gun/saatleri TEK derse oturum olarak toplanir (anahtar: kod varsa kod + ad +
 * hoca, yoksa ad + hoca). Renk otomatik; ders kodu, derslik ve not KOPYALANMAZ. I./II. ogretim ya da sube gibi gruplar
 * icin ogrencinin grubu bilinmez; ayni dersin tum gruplari gelir (ayni gun/saat birlesir), cakisma ogrenciye aittir.
 */
@Service
public class OfficialTimetableSeeder {

    private static final String NOT_FOUND_MSG = "Profilinize uygun resmi ders programı bulunamadı.";

    private final JdbcTemplate jdbc;
    private final OfficialTimetableService official;
    private final TimetableService timetable;

    public OfficialTimetableSeeder(JdbcTemplate jdbc, OfficialTimetableService official, TimetableService timetable) {
        this.jdbc = jdbc;
        this.official = official;
        this.timetable = timetable;
    }

    // ---- durum ----

    public OfficialStatus status(Long uid) {
        OfficialMatch m = official.matchFor(uid);
        List<String> units = m.units();
        return new OfficialStatus(!units.isEmpty(), m.term() != null && seeded(uid, m.term()), m.term(), units);
    }

    // ---- otomatik tohumlama ----

    /**
     * Kisisel dersi hic olmayan, bu donem icin isareti olmayan ve resmi programi TEK birimden gelen ogrenciye programi
     * kopyalar. Birden cok birim eslesirse yapmaz (istemci birim sectirir). Cakisma denetlenmez (force). Yapildiysa true.
     */
    @Transactional
    public boolean autoSeed(Long uid) {
        if (countCourses(uid) > 0) {
            return false;
        }
        OfficialMatch m = official.matchFor(uid);
        List<String> units = m.units();
        if (m.term() == null || units.size() != 1 || seeded(uid, m.term())) {
            return false;
        }
        // isaret once yazilir: es zamanli ikinci istek birincil anahtarda reddedilir (DuplicateKeyException), cift kopya olmaz
        jdbc.update("INSERT INTO tt_official_seed (user_id, term, unit) VALUES (?, ?, ?)", uid, m.term(), units.get(0));
        write(uid, group(m.items()), currentSemesterId(uid), TimetableService.MAX_COURSES);
        return true;
    }

    // ---- elle uygulama ----

    @Transactional
    public TimetableView apply(Long uid, ApplyRequest req) {
        ApplyRequest r = req == null ? new ApplyRequest(null, null, null) : req;
        OfficialMatch m = official.matchFor(uid);
        List<String> units = m.units();
        if (m.term() == null || units.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "OFFICIAL_TIMETABLE_NOT_FOUND", NOT_FOUND_MSG);
        }
        String unit;
        if (r.unit() == null || r.unit().isBlank()) {
            if (units.size() > 1) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "OFFICIAL_UNIT_REQUIRED",
                        "Birden fazla birim eşleşti; birim seçin.");
            }
            unit = units.get(0);
        } else {
            unit = units.stream().filter(u -> AudienceKey.same(u, r.unit())).findFirst().orElseThrow(
                    () -> new ApiException(HttpStatus.NOT_FOUND, "OFFICIAL_TIMETABLE_NOT_FOUND", NOT_FOUND_MSG));
        }
        List<EntryView> rows = m.items().stream().filter(e -> e.unit().equals(unit)).toList();
        Long semId = currentSemesterId(uid);
        if (Boolean.TRUE.equals(r.replace())) {
            deleteVisibleCourses(uid, semId);
        }
        List<Group> groups = group(rows);
        int remaining = visibleCourseCount(uid, semId);
        if (remaining > 0 && remaining + groups.size() > TimetableService.MAX_COURSES) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_LIMIT", "En çok {0} ders eklenebilir.",
                    String.valueOf(TimetableService.MAX_COURSES));
        }
        if (remaining > 0 && !Boolean.TRUE.equals(r.force())) {
            checkAgainstExisting(uid, semId, groups);
        }
        write(uid, groups, semId, TimetableService.MAX_COURSES - remaining);
        markSeeded(uid, m.term(), unit);
        return timetable.timetable(uid, null);
    }

    // ---- kopyalama ----

    private record Sess(int day, LocalTime start, LocalTime end) {}

    private static final class Group {
        final String name;
        final String instructor;
        final Set<Sess> sessions = new LinkedHashSet<>();

        Group(String name, String instructor) {
            this.name = name;
            this.instructor = instructor;
        }
    }

    /** Satirlari ders anahtarina gore toplar; ayni gun/saat tekrar eden oturumlar (farkli gruplar) birlesir. */
    private static List<Group> group(List<EntryView> rows) {
        Map<String, Group> by = new LinkedHashMap<>();
        for (EntryView e : rows) {
            String name = clip(e.name(), 120);
            String instr = clip(e.instructor(), 120);
            if (name == null) {
                continue;
            }
            String key = String.join("|", nz(AudienceKey.of(e.code())), nz(AudienceKey.of(name)), nz(AudienceKey.of(instr)));
            by.computeIfAbsent(key, k -> new Group(name, instr))
                    .sessions.add(new Sess(e.day(), LocalTime.parse(e.start()), LocalTime.parse(e.end())));
        }
        return new ArrayList<>(by.values());
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private static String clip(String s, int max) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String t = s.strip();
        return t.length() > max ? t.substring(0, max).strip() : t;
    }

    /** En cok `capacity` ders yazar (fazlasi atlanir); ders basina en cok 12 oturum. */
    private void write(Long uid, List<Group> groups, Long semId, int capacity) {
        int n = 0;
        for (Group g : groups) {
            if (n >= capacity) {
                break;
            }
            long id = insert(jdbc, "INSERT INTO tt_course (user_id, semester_id, name, code, instructor, color, note) "
                    + "VALUES (?, ?, ?, NULL, ?, ?, NULL)", uid, semId, g.name, g.instructor,
                    TimetableLogic.resolveColor(null, g.name));
            g.sessions.stream()
                    .sorted(Comparator.comparingInt(Sess::day).thenComparing(Sess::start).thenComparing(Sess::end))
                    .limit(TimetableService.MAX_SESSIONS_PER_COURSE)
                    .forEach(s -> jdbc.update("INSERT INTO tt_session (course_id, day_of_week, start_time, end_time, room) "
                            + "VALUES (?, ?, ?, ?, NULL)", id, s.day(), Time.valueOf(s.start()), Time.valueOf(s.end())));
            n++;
        }
    }

    /** Yeni oturumlari yalniz mevcut derslerle karsilastirir (resmi programin kendi gruplari birbiriyle uyarilmaz). */
    private void checkAgainstExisting(Long uid, Long semId, List<Group> groups) {
        List<Entry> existing = jdbc.query("SELECT c.id, c.name, s.day_of_week, s.start_time, s.end_time FROM tt_course c "
                + "JOIN tt_session s ON s.course_id = c.id WHERE " + visibleWhere("c.", semId),
                (rs, i) -> new Entry(rs.getLong("id"), rs.getString("name"), rs.getInt("day_of_week"),
                        rs.getTime("start_time").toLocalTime(), rs.getTime("end_time").toLocalTime()),
                visibleArgs(uid, semId));
        for (Group g : groups) {
            for (Sess s : g.sessions) {
                Entry in = new Entry(null, g.name, s.day(), s.start(), s.end());
                for (Entry ex : existing) {
                    if (TimetableLogic.overlaps(in, ex)) {
                        throw new ApiException(HttpStatus.CONFLICT, "COURSE_CONFLICT", "Ders saati çakışıyor: {0}",
                                TimetableLogic.describe(ex));
                    }
                }
            }
        }
    }

    // ---- gorunur kapsam (GET /api/timetable ile ayni) ----

    private Long currentSemesterId(Long uid) {
        List<Long> r = jdbc.queryForList("SELECT id FROM tt_semester WHERE user_id = ? AND is_current = TRUE ORDER BY id DESC",
                Long.class, uid);
        return r.isEmpty() ? null : r.get(0);
    }

    /** Guncel donem yoksa tum dersler; varsa o donem + donemsiz dersler (TimetableService.timetable ile birebir). */
    private static String visibleWhere(String p, Long semId) {
        return semId == null ? p + "user_id = ?"
                : p + "user_id = ? AND (" + p + "semester_id = ? OR " + p + "semester_id IS NULL)";
    }

    private static Object[] visibleArgs(Long uid, Long semId) {
        return semId == null ? new Object[] {uid} : new Object[] {uid, semId};
    }

    private int visibleCourseCount(Long uid, Long semId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_course WHERE " + visibleWhere("", semId), Integer.class,
                visibleArgs(uid, semId));
        return n == null ? 0 : n;
    }

    private void deleteVisibleCourses(Long uid, Long semId) {
        List<Long> ids = jdbc.queryForList("SELECT id FROM tt_course WHERE " + visibleWhere("", semId), Long.class,
                visibleArgs(uid, semId));
        if (ids.isEmpty()) {
            return;
        }
        String in = placeholders(ids);
        jdbc.update("UPDATE tt_exam SET course_id = NULL WHERE user_id = ? AND course_id IN (" + in + ")", withFirst(uid, ids));
        jdbc.update("DELETE FROM tt_session WHERE course_id IN (" + in + ")", ids.toArray());
        jdbc.update("DELETE FROM tt_course WHERE user_id = ? AND id IN (" + in + ")", withFirst(uid, ids));
    }

    private static Object[] withFirst(Long first, List<Long> rest) {
        List<Object> l = new ArrayList<>();
        l.add(first);
        l.addAll(rest);
        return l.toArray();
    }

    private int countCourses(Long uid) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_course WHERE user_id = ?", Integer.class, uid);
        return n == null ? 0 : n;
    }

    // ---- isaret ----

    private boolean seeded(Long uid, String term) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_official_seed WHERE user_id = ? AND term = ?", Integer.class,
                uid, term);
        return n != null && n > 0;
    }

    /** Isareti yazar ya da gunceller. Es zamanli iki elle uygulama birincil anahtarda catisabilir (nadir; istek hata verir). */
    private void markSeeded(Long uid, String term, String unit) {
        if (jdbc.update("UPDATE tt_official_seed SET unit = ?, seeded_at = CURRENT_TIMESTAMP WHERE user_id = ? AND term = ?",
                unit, uid, term) == 0) {
            jdbc.update("INSERT INTO tt_official_seed (user_id, term, unit) VALUES (?, ?, ?)", uid, term, unit);
        }
    }
}
