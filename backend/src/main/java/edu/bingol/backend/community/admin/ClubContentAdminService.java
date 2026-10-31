package edu.bingol.backend.community.admin;

import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.CommunityPostMedia;
import edu.bingol.backend.community.CommunityPostRepository;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.community.admin.ClubAdminDtos.PageResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostAuthor;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostActionResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostDetail;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.ReportRow;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.moderation.ModerationNotifier;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kulup gonderisi + duyurusu moderasyonu (P10): tum kulupler icin birlesik liste, metin duzenleme, GIZLE / GERI AL
 * (hidden_at, V670; silinmez), silme (yumusak + gorsel dosyasi diskten silinir, acik raporlar sonuclanir). Kufur
 * suzgeci yonetici duzenlemesinde atlanir (yonetici ihlalli metni temizlemek icin duzenler; islem denetim kaydina yazilir).
 */
@Service
public class ClubContentAdminService {

    private static final Logger log = LoggerFactory.getLogger(ClubContentAdminService.class);

    public static final String A_POST_HIDDEN = "ADMIN_POST_HIDDEN";
    public static final String A_POST_UNHIDDEN = "ADMIN_POST_UNHIDDEN";
    public static final String A_POST_EDITED = "ADMIN_POST_EDITED";
    public static final String A_POST_DELETED = "ADMIN_POST_DELETED";

    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final String OPEN_REPORTS = "(SELECT COUNT(*) FROM report r WHERE r.target_type = 'POST' "
            + "AND r.target_id = p.id AND r.status = 'OPEN')";
    private static final String SELECT = "SELECT p.id, p.community_id, c.name AS community_name, p.announcement, p.deleted, "
            + "p.hidden_at, p.hidden_reason, p.hidden_by, p.edited_at, p.created_at, p.content, p.image_url, p.pinned, "
            + "p.author_id, u.display_name, u.email, u.avatar_url, " + OPEN_REPORTS + " AS open_reports "
            + "FROM community_post p JOIN community c ON c.id = p.community_id LEFT JOIN app_user u ON u.id = p.author_id";

    /** Liste suzgeci; hepsi opsiyonel. kind: POST | ANNOUNCEMENT | ALL; status: VISIBLE | HIDDEN | DELETED | ALL. */
    public record ContentFilter(Long communityId, String kind, String status, Integer minReports, String q, Long authorId,
                                String from, String to, String sort) {
    }

    private final NamedParameterJdbcTemplate jdbc;
    private final CommunityPostRepository posts;
    private final CommunityPostMedia postMedia;
    private final ClubAuditService audit;
    private final NotificationService notifications;
    private final ModerationNotifier moderationNotifier;
    private final ReportService reports;

    public ClubContentAdminService(NamedParameterJdbcTemplate jdbc, CommunityPostRepository posts,
                                   CommunityPostMedia postMedia, ClubAuditService audit,
                                   NotificationService notifications, ModerationNotifier moderationNotifier,
                                   ReportService reports) {
        this.jdbc = jdbc;
        this.posts = posts;
        this.postMedia = postMedia;
        this.audit = audit;
        this.notifications = notifications;
        this.moderationNotifier = moderationNotifier;
        this.reports = reports;
    }

    // ---- okuma ----

    @Transactional(readOnly = true)
    public PageResult<PostRow> list(ContentFilter f, int page, int size) {
        int n = Math.min(Math.max(size, 1), ClubAdminQueryService.MAX_PAGE);
        int p = Math.max(page, 0);
        MapSqlParameterSource params = new MapSqlParameterSource();
        String where = where(f, params);
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM community_post p JOIN community c ON c.id = p.community_id "
                + "LEFT JOIN app_user u ON u.id = p.author_id" + where, params, Long.class);
        params.addValue("lim", n).addValue("off", (long) p * n);
        String order = "reports".equalsIgnoreCase(f.sort()) ? " ORDER BY open_reports DESC, p.id DESC" : " ORDER BY p.id DESC";
        if (f.sort() != null && !f.sort().isBlank() && !"reports".equalsIgnoreCase(f.sort())
                && !"createdAt".equalsIgnoreCase(f.sort())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sıralama alanı.");
        }
        List<PostRow> rows = jdbc.query(SELECT + where + order + " LIMIT :lim OFFSET :off", params, (rs, i) -> row(rs));
        return PageResult.of(rows, p, n, total == null ? 0 : total);
    }

    @Transactional(readOnly = true)
    public PostDetail detail(Long id) {
        PostRow row = one(id);
        List<ReportRow> items = jdbc.query("SELECT id, reason, note, status, created_at FROM report "
                + "WHERE target_type = 'POST' AND target_id = :id ORDER BY CASE WHEN status = 'OPEN' THEN 0 ELSE 1 END, id DESC LIMIT 50",
                new MapSqlParameterSource("id", id),
                (rs, i) -> new ReportRow(rs.getLong("id"), rs.getString("reason"), rs.getString("note"),
                        rs.getString("status"), ClubAdminQueryService.instant(rs.getTimestamp("created_at"))));
        return new PostDetail(row, items);
    }

    // ---- yazma ----

    /** Metin duzenleme (silinmis gonderi 404). Kufur suzgeci atlanir; yazara bildirim gider. */
    @Transactional
    public PostRow edit(Long id, String text, String reason) {
        CommunityPost p = live(id);
        String clean = text == null ? "" : text.trim();
        if (clean.isEmpty() || clean.length() > 2000) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Metin 1-2000 karakter olmalı.");
        }
        p.setContent(clean);
        p.setEditedAt(Instant.now());
        posts.saveAndFlush(p); // yanit JDBC ile okunur: yazim once veritabanina inmeli
        audit.record(p.getCommunityId(), ClubAdminService.actorId(), p.getAuthorId(), A_POST_EDITED,
                "post=" + id + " " + (p.isAnnouncement() ? "duyuru" : "gonderi"));
        notifyAuthor(p, "notif.community.postAdminEdited");
        target(id).summary("kulüp " + kind(p) + " metni düzenlendi");
        return one(id);
    }

    /** Gizle: akistan/duyurulardan kalkar, silinmez; geri alinabilir. Idempotent. */
    @Transactional
    public PostRow hide(Long id, String reason) {
        CommunityPost p = live(id);
        if (!p.isHidden()) {
            p.setHiddenAt(Instant.now());
            p.setHiddenReason(clip(reason, 300));
            p.setHiddenBy(ClubAdminService.actorId());
            p.setPinned(false);
            posts.saveAndFlush(p);
            audit.record(p.getCommunityId(), ClubAdminService.actorId(), p.getAuthorId(), A_POST_HIDDEN, "post=" + id);
            notifyAuthor(p, "notif.community.postAdminHidden");
        }
        target(id).summary("kulüp " + kind(p) + " gizlendi");
        return one(id);
    }

    @Transactional
    public PostRow unhide(Long id) {
        CommunityPost p = live(id);
        if (p.isHidden()) {
            p.setHiddenAt(null);
            p.setHiddenReason(null);
            p.setHiddenBy(null);
            posts.saveAndFlush(p);
            audit.record(p.getCommunityId(), ClubAdminService.actorId(), p.getAuthorId(), A_POST_UNHIDDEN, "post=" + id);
        }
        target(id).summary("kulüp " + kind(p) + " yeniden gösterildi");
        return one(id);
    }

    /**
     * Yumusak silme (GERI ALINAMAZ: gorsel dosyasi diskten silinir). Acik POST raporu varsa once
     * ReportService.resolve(HIDE) ile sonuclandirilir (yazar + raporlayanlar bilgilendirilir, ihlal kaydi oradan);
     * yoksa yazara dogrudan "kaldirildi" bildirimi gider.
     */
    @Transactional
    public PostActionResult delete(Long id, String reason) {
        CommunityPost p = live(id);
        String why = clip(reason, 300);
        List<Long> open = jdbc.queryForList("SELECT id FROM report WHERE target_type = 'POST' AND target_id = :id "
                + "AND status = 'OPEN' ORDER BY id LIMIT 1", new MapSqlParameterSource("id", id), Long.class);
        if (!open.isEmpty()) {
            reports.resolve(open.get(0), ClubAdminService.actorId(), Report.Resolution.HIDE, why, null);
        } else {
            moderationNotifier.removed(p.getAuthorId(), ReportTargetType.POST, id, why);
        }
        CommunityPost fresh = posts.findById(id).orElse(p);
        if (!fresh.isDeleted()) {
            fresh.setDeleted(true);
            fresh.setPinned(false);
            posts.save(fresh);
        }
        try {
            postMedia.release(List.of(fresh)); // KVKK: gorsel alandan kalkar, dosya diskten silinir
        } catch (RuntimeException e) {
            log.warn("Kulup gonderisi gorseli silinemedi (yazi {}): {}", id, e.toString());
        }
        audit.record(fresh.getCommunityId(), ClubAdminService.actorId(), fresh.getAuthorId(), A_POST_DELETED,
                "post=" + id + (why == null ? "" : " reason=" + why));
        target(id).summary("kulüp " + kind(fresh) + " silindi (geri alınamaz)");
        return new PostActionResult(id, "DELETED", true);
    }

    // ---- ic yardimcilar ----

    private PostRow one(Long id) {
        List<PostRow> rows = jdbc.query(SELECT + " WHERE p.id = :id", new MapSqlParameterSource("id", id), (rs, i) -> row(rs));
        if (rows.isEmpty()) {
            throw notFound();
        }
        return rows.get(0);
    }

    /** Silinmemis gonderi; yoksa 404. */
    private CommunityPost live(Long id) {
        return posts.findById(id).filter(x -> !x.isDeleted()).orElseThrow(ClubContentAdminService::notFound);
    }

    private String where(ContentFilter f, MapSqlParameterSource p) {
        StringBuilder w = new StringBuilder(" WHERE 1 = 1");
        if (f.communityId() != null) {
            w.append(" AND p.community_id = :cid");
            p.addValue("cid", f.communityId());
        }
        String kind = f.kind() == null ? "" : f.kind().trim().toUpperCase(Locale.ROOT);
        switch (kind) {
            case "", "ALL" -> { }
            case "POST" -> w.append(" AND p.announcement = FALSE");
            case "ANNOUNCEMENT" -> w.append(" AND p.announcement = TRUE");
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz tür süzgeci.");
        }
        String st = f.status() == null ? "" : f.status().trim().toUpperCase(Locale.ROOT);
        switch (st) {
            case "", "ALL" -> { }
            case "VISIBLE" -> w.append(" AND p.deleted = FALSE AND p.hidden_at IS NULL");
            case "HIDDEN" -> w.append(" AND p.deleted = FALSE AND p.hidden_at IS NOT NULL");
            case "DELETED" -> w.append(" AND p.deleted = TRUE");
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz durum süzgeci.");
        }
        if (f.authorId() != null) {
            w.append(" AND p.author_id = :author");
            p.addValue("author", f.authorId());
        }
        if (f.minReports() != null && f.minReports() > 0) {
            w.append(" AND ").append(OPEN_REPORTS).append(" >= :minReports");
            p.addValue("minReports", f.minReports());
        }
        String like = Texts.likePattern(f.q());
        if (!like.isEmpty()) {
            w.append(" AND (lower(p.content) LIKE :like ESCAPE '!' OR lower(u.display_name) LIKE :like ESCAPE '!'"
                    + (PermissionAwareMasking.canSeePii() ? " OR lower(u.email) LIKE :like ESCAPE '!'" : "")
                    + " OR lower(c.name) LIKE :like ESCAPE '!')");
            p.addValue("like", like);
        }
        Instant from = day(f.from(), false);
        if (from != null) {
            w.append(" AND p.created_at >= :from");
            p.addValue("from", Timestamp.from(from));
        }
        Instant to = day(f.to(), true);
        if (to != null) {
            w.append(" AND p.created_at < :to");
            p.addValue("to", Timestamp.from(to));
        }
        return w.toString();
    }

    private static PostRow row(ResultSet rs) throws SQLException {
        boolean deleted = rs.getBoolean("deleted");
        Timestamp hidden = rs.getTimestamp("hidden_at");
        String state = deleted ? "DELETED" : hidden != null ? "HIDDEN" : "VISIBLE";
        PostAuthor a = new PostAuthor(rs.getLong("author_id"), rs.getString("display_name"),
                PermissionAwareMasking.email(rs.getString("email")),
                rs.getString("avatar_url"));
        return new PostRow(rs.getLong("id"), rs.getLong("community_id"), rs.getString("community_name"),
                rs.getBoolean("announcement") ? "ANNOUNCEMENT" : "POST", state, a, rs.getString("content"),
                rs.getString("image_url"), rs.getBoolean("pinned"), rs.getInt("open_reports"),
                rs.getString("hidden_reason"), (Long) rs.getObject("hidden_by"), ClubAdminQueryService.instant(hidden),
                ClubAdminQueryService.instant(rs.getTimestamp("edited_at")),
                ClubAdminQueryService.instant(rs.getTimestamp("created_at")));
    }

    private void notifyAuthor(CommunityPost p, String key) {
        if (p.getAuthorId() == null) {
            return;
        }
        String club = jdbc.queryForObject("SELECT name FROM community WHERE id = :id",
                new MapSqlParameterSource("id", p.getCommunityId()), String.class);
        notifications.sendTemplated(p.getAuthorId(), NotificationType.COMMUNITY, key,
                Map.of("communityId", p.getCommunityId().toString(), "postId", p.getId().toString()), club);
    }

    private static AuditContext.Data target(Long id) {
        return AuditContext.target("COMMUNITY_POST", id);
    }

    private static String kind(CommunityPost p) {
        return p.isAnnouncement() ? "duyurusu" : "gönderisi";
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
    }

    private static String clip(String s, int max) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String t = s.trim();
        return t.length() <= max ? t : t.substring(0, max);
    }

    private static Instant day(String s, boolean endExclusive) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            LocalDate d = LocalDate.parse(s.trim());
            return (endExclusive ? d.plusDays(1) : d).atStartOfDay(ZONE).toInstant();
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz tarih (YYYY-AA-GG bekleniyor).");
        }
    }
}
