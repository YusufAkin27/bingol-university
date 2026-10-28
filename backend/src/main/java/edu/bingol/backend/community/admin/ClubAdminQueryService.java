package edu.bingol.backend.community.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.community.admin.ClubAdminDtos.AuditRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.Capabilities;
import edu.bingol.backend.community.admin.ClubAdminDtos.ClubDetail;
import edu.bingol.backend.community.admin.ClubAdminDtos.ClubRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.MemberRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.PageResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.ReportRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.StaffRow;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici kulup okumalari (liste, ayrinti, uyeler, CSV satirlari). Duz parametreli SQL (NamedParameterJdbcTemplate;
 * H2 ve PostgreSQL'de ayni calisir: ILIKE yok, LIKE ... ESCAPE '!' + lower()). Yonetici icin gorunurluk kisiti yoktur.
 */
@Service
public class ClubAdminQueryService {

    public static final int MAX_PAGE = 100;
    /** CSV disa aktarimi tavani. */
    public static final int EXPORT_MAX = 50_000;
    /** Kulup durum gecmisi icin sayilan denetim eylemleri. */
    static final List<String> STATUS_ACTIONS = List.of(ClubAdminService.A_CLOSED, ClubAdminService.A_REOPENED,
            ClubAdminService.A_TRANSFER, "COMMUNITY_DELETED", ClubAdminService.A_DELETED);

    private static final Map<String, String> SORTS = Map.of(
            "createdAt", "c.created_at",
            "name", "lower(c.name)",
            "memberCount", "member_count",
            "openReports", "open_reports",
            "id", "c.id");

    private static final String OPEN_REPORTS = "(SELECT COUNT(*) FROM report r WHERE r.target_type = 'COMMUNITY' "
            + "AND r.target_id = c.id AND r.status = 'OPEN')";

    private static final String SELECT = "SELECT c.id, c.name, c.slug, c.category, c.status, c.visibility, c.join_policy, "
            + "c.owner_id, ou.display_name AS owner_name, ou.email AS owner_email, c.cover_url, c.logo_url, "
            + "c.created_at, c.updated_at, c.description, c.review_note, "
            + "(SELECT COUNT(*) FROM community_member m WHERE m.community_id = c.id AND m.status = 'ACTIVE') AS member_count, "
            + "(SELECT COUNT(*) FROM community_member m WHERE m.community_id = c.id AND m.status = 'PENDING') AS pending_count, "
            + OPEN_REPORTS + " AS open_reports, "
            + "(SELECT COUNT(*) FROM user_event e WHERE e.community_id = c.id) AS event_count "
            + "FROM community c LEFT JOIN app_user ou ON ou.id = c.owner_id";

    private final NamedParameterJdbcTemplate jdbc;

    public ClubAdminQueryService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Liste suzgeci; hepsi opsiyonel. status bos = silinmisler haric tum durumlar ("ALL" = silinmisler dahil). */
    public record ClubFilter(String status, String category, String q, String visibility, String joinPolicy,
                             Long ownerId, Integer minReports, String sort, String dir) {
    }

    // ---- liste / disa aktarim ----

    @Transactional(readOnly = true)
    public PageResult<ClubRow> list(ClubFilter f, int page, int size) {
        int n = Math.min(Math.max(size, 1), MAX_PAGE);
        int p = Math.max(page, 0);
        MapSqlParameterSource params = new MapSqlParameterSource();
        String where = where(f, params);
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM community c LEFT JOIN app_user ou ON ou.id = c.owner_id"
                + where, params, Long.class);
        params.addValue("lim", n).addValue("off", (long) p * n);
        List<ClubRow> rows = jdbc.query(SELECT + where + orderBy(f) + " LIMIT :lim OFFSET :off", params,
                (rs, i) -> row(rs));
        return PageResult.of(rows, p, n, total == null ? 0 : total);
    }

    /** CSV icin en cok EXPORT_MAX satir (en yeni once). */
    @Transactional(readOnly = true)
    public List<ClubRow> export(ClubFilter f) {
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("lim", EXPORT_MAX);
        String where = where(f, params);
        return jdbc.query(SELECT + where + " ORDER BY c.id DESC LIMIT :lim", params, (rs, i) -> row(rs));
    }

    // ---- ayrinti ----

    @Transactional(readOnly = true)
    public ClubDetail detail(Long id) {
        MapSqlParameterSource p = new MapSqlParameterSource("id", id);
        List<Object[]> base = jdbc.query(SELECT + " WHERE c.id = :id", p,
                (rs, i) -> new Object[] {row(rs), rs.getString("description"), rs.getString("review_note")});
        if (base.isEmpty()) {
            throw notFound();
        }
        ClubRow club = (ClubRow) base.get(0)[0];
        List<StaffRow> staff = jdbc.query("SELECT m.user_id, u.display_name, u.email, m.role FROM community_member m "
                + "JOIN app_user u ON u.id = m.user_id WHERE m.community_id = :id AND m.status = 'ACTIVE' "
                + "AND m.role IN ('OWNER','ADMIN','MODERATOR') ORDER BY m.id", p,
                (rs, i) -> new StaffRow(rs.getLong("user_id"), rs.getString("display_name"), rs.getString("email"),
                        CommunityMember.Role.valueOf(rs.getString("role"))));
        // OWNER, ADMIN, MODERATOR sirasi: id sirasi yerine rol onceligi
        List<StaffRow> sorted = new ArrayList<>(staff);
        sorted.sort(java.util.Comparator.comparing((StaffRow s) -> -s.role().ordinal()));
        Long banned = jdbc.queryForObject("SELECT COUNT(*) FROM community_member WHERE community_id = :id AND status = 'BANNED'",
                p, Long.class);
        List<AuditRow> history = audit(id, STATUS_ACTIONS, 20);
        List<AuditRow> recent = audit(id, null, 15);
        List<ReportRow> reports = jdbc.query("SELECT id, reason, note, status, created_at FROM report "
                + "WHERE target_type = 'COMMUNITY' AND target_id = :id AND status = 'OPEN' ORDER BY id DESC LIMIT 20", p,
                (rs, i) -> new ReportRow(rs.getLong("id"), rs.getString("reason"), rs.getString("note"),
                        rs.getString("status"), instant(rs.getTimestamp("created_at"))));
        return new ClubDetail(club, (String) base.get(0)[1], (String) base.get(0)[2], sorted,
                banned == null ? 0 : banned, history, reports, recent, capabilities(club.status()));
    }

    /** Sunucu durum kurallarinin aynasi (ClubAdminService ile ayni kosullar). */
    static Capabilities capabilities(String status) {
        boolean deleted = Community.Status.DELETED.name().equals(status);
        boolean active = Community.Status.ACTIVE.name().equals(status);
        boolean hidden = Community.Status.HIDDEN.name().equals(status);
        return new Capabilities(!deleted, active, hidden, !deleted, active || hidden,
                Community.Status.PENDING_REVIEW.name().equals(status));
    }

    // ---- uyeler ----

    /** Uye/bekleyen/yasakli listesi. status: ACTIVE | PENDING | BANNED (bos = hepsi). */
    @Transactional(readOnly = true)
    public PageResult<MemberRow> members(Long communityId, String status, String role, String q, int page, int size) {
        int n = Math.min(Math.max(size, 1), MAX_PAGE);
        int p = Math.max(page, 0);
        MapSqlParameterSource params = new MapSqlParameterSource("cid", communityId);
        StringBuilder where = new StringBuilder(" WHERE m.community_id = :cid");
        String st = enumOrNull(status, CommunityMember.Status.class, "durum");
        if (st != null) {
            where.append(" AND m.status = :st");
            params.addValue("st", st);
        }
        String rl = enumOrNull(role, CommunityMember.Role.class, "rol");
        if (rl != null) {
            where.append(" AND m.role = :rl");
            params.addValue("rl", rl);
        }
        String like = Texts.likePattern(q);
        if (!like.isEmpty()) {
            where.append(" AND (lower(u.display_name) LIKE :like ESCAPE '!' OR lower(u.email) LIKE :like ESCAPE '!')");
            params.addValue("like", like);
        }
        String from = " FROM community_member m JOIN app_user u ON u.id = m.user_id" + where;
        Long total = jdbc.queryForObject("SELECT COUNT(*)" + from, params, Long.class);
        params.addValue("lim", n).addValue("off", (long) p * n);
        List<MemberRow> rows = jdbc.query("SELECT m.user_id, u.display_name, u.email, u.avatar_url, u.status AS account_status, "
                + "m.role, m.status, m.joined_at, "
                + "(SELECT COUNT(*) FROM club_member_grant g WHERE g.community_id = m.community_id AND g.user_id = m.user_id) AS grants"
                + from + " ORDER BY CASE m.role WHEN 'OWNER' THEN 0 WHEN 'ADMIN' THEN 1 WHEN 'MODERATOR' THEN 2 ELSE 3 END, m.id"
                + " LIMIT :lim OFFSET :off", params,
                (rs, i) -> new MemberRow(rs.getLong("user_id"), rs.getString("display_name"), rs.getString("email"),
                        rs.getString("avatar_url"), CommunityMember.Role.valueOf(rs.getString("role")),
                        rs.getString("status"), rs.getString("account_status"), instant(rs.getTimestamp("joined_at")),
                        rs.getLong("grants") > 0));
        return PageResult.of(rows, p, n, total == null ? 0 : total);
    }

    // ---- ic yardimcilar ----

    private String where(ClubFilter f, MapSqlParameterSource p) {
        StringBuilder w = new StringBuilder(" WHERE 1 = 1");
        String st = f.status() == null ? "" : f.status().trim().toUpperCase(Locale.ROOT);
        if (st.isEmpty()) {
            w.append(" AND c.status <> 'DELETED'");
        } else if (!st.equals("ALL")) {
            w.append(" AND c.status = :status");
            p.addValue("status", enumOrNull(st, Community.Status.class, "durum"));
        }
        if (f.category() != null && !f.category().isBlank()) {
            w.append(" AND c.category = :category");
            p.addValue("category", f.category().trim());
        }
        String vis = enumOrNull(f.visibility(), Community.Visibility.class, "görünürlük");
        if (vis != null) {
            w.append(" AND c.visibility = :vis");
            p.addValue("vis", vis);
        }
        String jp = enumOrNull(f.joinPolicy(), Community.JoinPolicy.class, "katılım politikası");
        if (jp != null) {
            w.append(" AND c.join_policy = :jp");
            p.addValue("jp", jp);
        }
        if (f.ownerId() != null) {
            w.append(" AND c.owner_id = :owner");
            p.addValue("owner", f.ownerId());
        }
        if (f.minReports() != null && f.minReports() > 0) {
            w.append(" AND ").append(OPEN_REPORTS).append(" >= :minReports");
            p.addValue("minReports", f.minReports());
        }
        String like = Texts.likePattern(f.q());
        if (!like.isEmpty()) {
            w.append(" AND (lower(c.name) LIKE :like ESCAPE '!' OR lower(c.slug) LIKE :like ESCAPE '!'"
                    + " OR lower(ou.display_name) LIKE :like ESCAPE '!' OR lower(ou.email) LIKE :like ESCAPE '!')");
            p.addValue("like", like);
        }
        return w.toString();
    }

    /** Beyaz listeli siralama; bilinmeyen alan 400. */
    private static String orderBy(ClubFilter f) {
        String key = f.sort() == null || f.sort().isBlank() ? "createdAt" : f.sort().trim();
        String col = SORTS.get(key);
        if (col == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sıralama alanı.");
        }
        boolean asc = "asc".equalsIgnoreCase(f.dir());
        return " ORDER BY " + col + (asc ? " ASC" : " DESC") + ", c.id DESC";
    }

    private List<AuditRow> audit(Long communityId, List<String> actions, int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource("cid", communityId).addValue("lim", limit);
        String filter = "";
        if (actions != null) {
            filter = " AND a.action IN (:actions)";
            p.addValue("actions", actions);
        }
        List<Object[]> raw = jdbc.query("SELECT a.id, a.action, a.actor_id, a.target_user_id, a.detail, a.created_at "
                + "FROM club_audit a WHERE a.community_id = :cid" + filter + " ORDER BY a.id DESC LIMIT :lim", p,
                (rs, i) -> new Object[] {rs.getLong("id"), rs.getString("action"), (Long) rs.getObject("actor_id"),
                        (Long) rs.getObject("target_user_id"), rs.getString("detail"),
                        instant(rs.getTimestamp("created_at"))});
        Set<Long> ids = new HashSet<>();
        for (Object[] r : raw) {
            if (r[2] != null) {
                ids.add((Long) r[2]);
            }
            if (r[3] != null) {
                ids.add((Long) r[3]);
            }
        }
        Map<Long, String> names = new HashMap<>();
        if (!ids.isEmpty()) {
            jdbc.query("SELECT id, display_name FROM app_user WHERE id IN (:ids)", new MapSqlParameterSource("ids", ids),
                    rs -> {
                        names.put(rs.getLong("id"), rs.getString("display_name"));
                    });
        }
        List<AuditRow> out = new ArrayList<>();
        for (Object[] r : raw) {
            out.add(new AuditRow((Long) r[0], (String) r[1], (Long) r[2], r[2] == null ? null : names.get((Long) r[2]),
                    (Long) r[3], r[3] == null ? null : names.get((Long) r[3]), (String) r[4], (Instant) r[5]));
        }
        return out;
    }

    private static ClubRow row(ResultSet rs) throws SQLException {
        return new ClubRow(rs.getLong("id"), rs.getString("name"), rs.getString("slug"), rs.getString("category"),
                rs.getString("status"), rs.getString("visibility"), rs.getString("join_policy"), rs.getLong("owner_id"),
                rs.getString("owner_name"), rs.getString("owner_email"), rs.getString("cover_url"),
                rs.getString("logo_url"), rs.getLong("member_count"), rs.getLong("pending_count"),
                rs.getInt("open_reports"), rs.getLong("event_count"), instant(rs.getTimestamp("created_at")),
                instant(rs.getTimestamp("updated_at")));
    }

    static Instant instant(Timestamp t) {
        return t == null ? null : t.toInstant();
    }

    /** Bos = null; gecersiz deger 400 (enum adi beyaz liste). */
    static <E extends Enum<E>> String enumOrNull(String raw, Class<E> type, String label) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return Enum.valueOf(type, raw.trim().toUpperCase(Locale.ROOT)).name();
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz " + label + " süzgeci.");
        }
    }

    static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
    }
}
