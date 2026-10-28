package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.academic.AcademicCalendarService;
import edu.bingol.backend.academic.AcademicDtos.AdminAcademicEventView;
import edu.bingol.backend.academic.AcademicDtos.AdminAnnouncementView;
import edu.bingol.backend.academic.AcademicDtos.AdminExamScheduleView;
import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.academic.DepartmentAnnouncementService;
import edu.bingol.backend.academic.ExamService;
import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.admin.bulk.BulkDtos.AcademicEntity;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Entry;
import edu.bingol.backend.auth.token.PendingRegistrationStore.EntryPage;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.news.ContentType;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * P15 CSV disa aktarimlari (UTF-8 BOM, CRLF, formul kacirma: {@link Csv}). Her metot satir sayisini dondurur ve en cok
 * {@link BulkDtos#MAX_EXPORT_ROWS} satir yazar. Bekleyen kayitlarda e-posta/ad MASKELIDIR. Haber icerigi (TEXT) yazilmaz.
 */
@Service
public class BulkCsvService {

    private static final int BATCH = 1000;
    private static final int ACD_PAGE = 100;

    private final NamedParameterJdbcTemplate jdbc;
    private final MenuRepository menu;
    private final AcademicCalendarService calendar;
    private final ExamService exams;
    private final DepartmentAnnouncementService announcements;
    private final PendingRegistrationStore pending;

    public BulkCsvService(NamedParameterJdbcTemplate jdbc, MenuRepository menu, AcademicCalendarService calendar,
                          ExamService exams, DepartmentAnnouncementService announcements,
                          PendingRegistrationStore pending) {
        this.jdbc = jdbc;
        this.menu = menu;
        this.calendar = calendar;
        this.exams = exams;
        this.announcements = announcements;
        this.pending = pending;
    }

    private static void line(Writer w, List<?> cells) {
        try {
            w.write(Csv.row(cells));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static void bom(Writer w) {
        try {
            w.write(Csv.BOM);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    // ---- haber ----

    /** Liste ucuyla ayni suzgecler (q baslikta, type, hidden); en yeni (id) once, anahtar kumeli sayfalama. */
    public int news(String q, ContentType type, Boolean hidden, Writer w) {
        bom(w);
        line(w, List.of("id", "type", "title", "url", "publishedDate", "eventDate", "fetchedAt", "hidden"));
        List<String> c = new ArrayList<>();
        MapSqlParameterSource p = new MapSqlParameterSource();
        if (q != null && !q.isBlank()) {
            c.add("title ILIKE :q ESCAPE '\\'");
            p.addValue("q", "%" + UserFilter.escapeLike(q.trim()) + "%");
        }
        if (type != null) {
            c.add("type = :type");
            p.addValue("type", type.name());
        }
        if (hidden != null) {
            c.add("hidden = :hidden");
            p.addValue("hidden", hidden);
        }
        String where = c.isEmpty() ? "" : String.join(" AND ", c) + " AND ";
        long last = Long.MAX_VALUE;
        int n = 0;
        while (n < BulkDtos.MAX_EXPORT_ROWS) {
            p.addValue("last", last).addValue("lim", Math.min(BATCH, BulkDtos.MAX_EXPORT_ROWS - n));
            List<Object[]> rows = jdbc.query("SELECT id, type, title, url, published_date, event_date, fetched_at, hidden "
                    + "FROM news_item WHERE " + where + "id < :last ORDER BY id DESC LIMIT :lim", p,
                    (rs, i) -> new Object[] {rs.getLong("id"), rs.getString("type"), rs.getString("title"),
                            rs.getString("url"), rs.getString("published_date"), rs.getString("event_date"),
                            iso(rs.getTimestamp("fetched_at")), rs.getBoolean("hidden")});
            if (rows.isEmpty()) {
                break;
            }
            for (Object[] r : rows) {
                line(w, java.util.Arrays.asList(r));
            }
            n += rows.size();
            last = (Long) rows.get(rows.size() - 1)[0];
            if (rows.size() < BATCH) {
                break;
            }
        }
        return n;
    }

    private static String iso(Timestamp t) {
        return t == null ? "" : t.toInstant().toString();
    }

    // ---- menu ----

    /** from/to (yyyy-MM-dd) bos ise tum gunler. */
    public int menu(LocalDate from, LocalDate to, Writer w) {
        bom(w);
        line(w, List.of("date", "items", "imageUrl"));
        LocalDate f = from == null ? LocalDate.of(2000, 1, 1) : from;
        LocalDate t = to == null ? LocalDate.of(2100, 1, 1) : to;
        int n = 0;
        for (MenuDay d : menu.findByMenuDateBetweenOrderByMenuDate(f, t)) {
            if (n >= BulkDtos.MAX_EXPORT_ROWS) {
                break;
            }
            line(w, List.of(d.getMenuDate().toString(), d.getItems().replace("\n", " | "),
                    d.getImageUrl() == null ? "" : d.getImageUrl()));
            n++;
        }
        return n;
    }

    // ---- akademik ----

    /** kind yalniz CALENDAR; status yalniz ANNOUNCEMENT (all|draft|scheduled|active|expired); published CALENDAR. */
    public int academic(AcademicEntity entity, String q, String kind, Boolean published, String status, Writer w) {
        bom(w);
        int n = 0;
        switch (entity) {
            case CALENDAR -> {
                line(w, List.of("id", "kind", "title", "startsAt", "endsAt", "allDay", "scopeDepartment", "note", "published"));
                for (int page = 0; n < BulkDtos.MAX_EXPORT_ROWS; page++) {
                    Page<AdminAcademicEventView> r = calendar.adminList(page, ACD_PAGE, kind, q, published);
                    if (r.items().isEmpty()) {
                        break;
                    }
                    for (AdminAcademicEventView v : r.items()) {
                        if (n >= BulkDtos.MAX_EXPORT_ROWS) {
                            break;
                        }
                        line(w, java.util.Arrays.asList(v.id(), v.kind(), v.title(), v.startsAt(), v.endsAt(), v.allDay(),
                                v.scopeDepartment(), v.note(), v.published()));
                        n++;
                    }
                    if ((long) (page + 1) * ACD_PAGE >= r.total()) {
                        break;
                    }
                }
            }
            case EXAM -> {
                line(w, List.of("id", "title", "type", "term", "courseCode", "faculty", "department", "grade", "startsAt",
                        "endsAt", "room", "note", "published"));
                for (int page = 0; n < BulkDtos.MAX_EXPORT_ROWS; page++) {
                    Page<AdminExamScheduleView> r = exams.adminList(page, ACD_PAGE, q);
                    if (r.items().isEmpty()) {
                        break;
                    }
                    for (AdminExamScheduleView v : r.items()) {
                        if (n >= BulkDtos.MAX_EXPORT_ROWS) {
                            break;
                        }
                        line(w, java.util.Arrays.asList(v.id(), v.title(), v.type(), v.term(), v.courseCode(), v.faculty(),
                                v.department(), v.grade(), v.startsAt(), v.endsAt(), v.room(), v.note(), v.published()));
                        n++;
                    }
                    if ((long) (page + 1) * ACD_PAGE >= r.total()) {
                        break;
                    }
                }
            }
            case ANNOUNCEMENT -> {
                // Duyuru metni (body) yazilmaz: yalniz kunye ve durum
                line(w, List.of("id", "title", "department", "faculty", "grade", "pinned", "publishAt", "expiresAt",
                        "published", "notify", "notifiedAt", "readCount", "createdAt"));
                for (int page = 0; n < BulkDtos.MAX_EXPORT_ROWS; page++) {
                    Page<AdminAnnouncementView> r = announcements.adminList(page, ACD_PAGE, status, q);
                    if (r.items().isEmpty()) {
                        break;
                    }
                    for (AdminAnnouncementView v : r.items()) {
                        if (n >= BulkDtos.MAX_EXPORT_ROWS) {
                            break;
                        }
                        line(w, java.util.Arrays.asList(v.id(), v.title(), v.department(), v.faculty(), v.grade(),
                                v.pinned(), v.publishAt(), v.expiresAt(), v.published(), v.notifyUsers(), v.notifiedAt(),
                                v.readCount(), v.createdAt()));
                        n++;
                    }
                    if ((long) (page + 1) * ACD_PAGE >= r.total()) {
                        break;
                    }
                }
            }
        }
        return n;
    }

    // ---- bekleyen kayit ----

    /** Kisisel veri: e-posta ve ad maskeli; kalan sure / yeniden gonderim sayaci tam. */
    public int pending(String q, Writer w) {
        bom(w);
        line(w, List.of("emailMasked", "nameMasked", "faculty", "department", "grade", "createdAt", "remainingSeconds",
                "resendCount"));
        int n = 0;
        String cursor = null;
        while (n < BulkDtos.MAX_EXPORT_ROWS) {
            EntryPage page = pending.list(cursor, 500, q);
            for (Entry e : page.items()) {
                if (n >= BulkDtos.MAX_EXPORT_ROWS) {
                    break;
                }
                line(w, java.util.Arrays.asList(BulkSupport.maskEmail(e.email()), BulkSupport.maskName(e.displayName()),
                        e.faculty(), e.department(), e.grade(),
                        e.createdAtEpochSec() > 0 ? Instant.ofEpochSecond(e.createdAtEpochSec()).toString() : "",
                        e.remainingSeconds(), e.resendCount()));
                n++;
            }
            if (page.nextCursor() == null) {
                break;
            }
            cursor = page.nextCursor();
        }
        return n;
    }
}
