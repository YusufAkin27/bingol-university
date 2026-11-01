package edu.bingol.backend.unitnews;

import edu.bingol.backend.academic.AudienceKey;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.unitnews.UnitNewsDtos.AdminItem;
import edu.bingol.backend.unitnews.UnitNewsDtos.AdminPage;
import edu.bingol.backend.unitnews.UnitNewsDtos.DepartmentView;
import edu.bingol.backend.unitnews.UnitNewsDtos.SourceView;
import edu.bingol.backend.unitnews.UnitNewsDtos.SyncResult;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Birim haberleri yonetimi: kaynak durumu/ayari, elle cekim, duyuru listesi ve gizleme. */
@Service
public class UnitNewsAdminService {

    static final int MAX_PAGE_SIZE = 100;
    private static final int MAX_KEYS = 40;
    private static final int KEYS_COLUMN = 600;

    private final UnitSourceRepository sources;
    private final UnitDepartmentRepository depts;
    private final UnitNewsSyncService sync;
    private final NamedParameterJdbcTemplate jdbc;

    public UnitNewsAdminService(UnitSourceRepository sources, UnitDepartmentRepository depts, UnitNewsSyncService sync,
                                NamedParameterJdbcTemplate jdbc) {
        this.sources = sources;
        this.depts = depts;
        this.sync = sync;
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public List<SourceView> sources() {
        Map<String, Long> deptCounts = counts("SELECT source_code, COUNT(*) AS n FROM unit_department GROUP BY source_code");
        Map<String, Long> annCounts = counts("SELECT source_code, COUNT(*) AS n FROM unit_announcement GROUP BY source_code");
        List<SourceView> out = new ArrayList<>();
        for (UnitSource s : sources.findAllByOrderByNameAsc()) {
            out.add(view(s, deptCounts.getOrDefault(s.getCode(), 0L), annCounts.getOrDefault(s.getCode(), 0L)));
        }
        return out;
    }

    @Transactional
    public SourceView update(String code, UnitNewsDtos.SourceUpdate req) {
        UnitSource s = source(code);
        s.setEnabled(req.enabled());
        if (req.facultyKeys() != null) {
            s.setFacultyKeys(String.join(",", keys(req.facultyKeys())));
        }
        sources.save(s);
        AuditContext.target("UNIT_SOURCE", code)
                .summary("birim haberleri kaynagi: " + (s.isEnabled() ? "acik" : "kapali") + ", fakulteler: " + s.getFacultyKeys());
        return view(s, depts.countBySourceCode(code), count("SELECT COUNT(*) FROM unit_announcement WHERE source_code = :c", code));
    }

    @Transactional(readOnly = true)
    public List<DepartmentView> departments(String code) {
        source(code);
        return depts.findBySourceCodeOrderByNameAsc(code).stream()
                .map(d -> new DepartmentView(d.getSlug(), d.getName(), d.getNameKey(), d.getFeedPath() != null)).toList();
    }

    /** Arka planda cekim baslatir; zaten calisiyorsa started=false. {@code code == null}: hepsi. */
    public SyncResult startSync(String code) {
        if (code != null) {
            source(code);
        }
        if (sync.isRunning()) {
            return new SyncResult(0, false);
        }
        CompletableFuture.runAsync(() -> {
            if (code == null) {
                sync.syncAll();
            } else {
                sync.sync(code);
            }
        });
        AuditContext.target("UNIT_SOURCE", code == null ? "all" : code).summary("birim haberleri elle cekim");
        return new SyncResult(0, true);
    }

    @Transactional(readOnly = true)
    public AdminPage announcements(String source, String q, Boolean hidden, int page, int size) {
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        List<String> c = new ArrayList<>();
        MapSqlParameterSource params = new MapSqlParameterSource();
        if (source != null && !source.isBlank()) {
            c.add("a.source_code = :source");
            params.addValue("source", source.trim());
        }
        if (q != null && !q.isBlank()) {
            c.add("LOWER(a.title) LIKE LOWER(:q) ESCAPE '\\'");
            params.addValue("q", "%" + UserFilter.escapeLike(q.trim()) + "%");
        }
        if (hidden != null) {
            c.add("a.hidden = :hidden");
            params.addValue("hidden", hidden);
        }
        String where = c.isEmpty() ? "TRUE" : String.join(" AND ", c);
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM unit_announcement a WHERE " + where, params, Long.class);
        params.addValue("lim", s).addValue("off", (long) p * s);
        List<AdminItem> rows = jdbc.query("SELECT a.id, a.source_code, so.name AS source_name, a.title, a.url, "
                + "a.published_date, a.attachments, a.hidden, d.name AS unit_name FROM unit_announcement a "
                + "JOIN unit_source so ON so.code = a.source_code "
                + "LEFT JOIN unit_department d ON d.source_code = a.source_code AND d.slug = a.dept_slug "
                + "WHERE " + where + " ORDER BY a.published_date DESC, a.id DESC LIMIT :lim OFFSET :off", params,
                (rs, i) -> new AdminItem(rs.getLong("id"), rs.getString("source_code"), rs.getString("source_name"),
                        rs.getString("unit_name"), rs.getString("title"), rs.getString("url"),
                        rs.getDate("published_date").toLocalDate().toString(),
                        attachmentCount(rs.getString("attachments")), rs.getBoolean("hidden")));
        long t = total == null ? 0 : total;
        return new AdminPage(rows, t, (int) Math.ceil(t / (double) s), p, s);
    }

    @Transactional
    public void setHidden(long id, boolean hidden) {
        int n = jdbc.update("UPDATE unit_announcement SET hidden = :h WHERE id = :id",
                new MapSqlParameterSource().addValue("h", hidden).addValue("id", id));
        if (n == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "UNIT_NEWS_NOT_FOUND", "Duyuru bulunamadı.");
        }
        AuditContext.target("UNIT_NEWS", id).summary(hidden ? "birim duyurusu gizlendi" : "birim duyurusu gosterildi");
    }

    // ---- ic ----

    private UnitSource source(String code) {
        return sources.findById(code == null ? "" : code)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "UNIT_SOURCE_NOT_FOUND", "Kaynak bulunamadı."));
    }

    private static SourceView view(UnitSource s, long deptCount, long annCount) {
        List<String> keys = s.getFacultyKeys().isBlank() ? List.of()
                : Arrays.stream(s.getFacultyKeys().split(",")).map(String::strip).filter(x -> !x.isEmpty()).toList();
        return new SourceView(s.getCode(), s.getName(), s.getKind().name(), s.getBaseUrl(), s.isEnabled(), s.isGraduate(),
                keys, deptCount, annCount, s.getLastSuccessAt(), s.getLastAttemptAt(), s.getLastMessage(), s.isMaintenance());
    }

    /** Girdi fakulte adlari {@link AudienceKey} ile normalize edilir, tekrarlar atilir, sutun sinirina sigdirilir. */
    static List<String> keys(List<String> raw) {
        Set<String> out = new LinkedHashSet<>();
        for (String r : raw) {
            String k = AudienceKey.of(r);
            if (k != null && !k.contains(",")) {
                out.add(k);
            }
        }
        List<String> list = new ArrayList<>(out);
        if (list.size() > MAX_KEYS || String.join(",", list).length() > KEYS_COLUMN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "UNIT_FACULTY_KEYS_INVALID",
                    "Fakülte listesi çok uzun (en çok {0} ad).", String.valueOf(MAX_KEYS));
        }
        return list;
    }

    private Map<String, Long> counts(String sql) {
        Map<String, Long> m = new HashMap<>();
        jdbc.query(sql, new MapSqlParameterSource(), rs -> {
            m.put(rs.getString(1), rs.getLong(2));
        });
        return m;
    }

    private long count(String sql, String code) {
        Long n = jdbc.queryForObject(sql, new MapSqlParameterSource("c", code), Long.class);
        return n == null ? 0 : n;
    }

    private static int attachmentCount(String raw) {
        return raw == null || raw.isBlank() ? 0 : new UnitAttachmentsJson().read(raw).size();
    }
}
