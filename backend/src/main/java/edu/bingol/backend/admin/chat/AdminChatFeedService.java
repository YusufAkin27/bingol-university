package edu.bingol.backend.admin.chat;

import edu.bingol.backend.admin.chat.AdminChatViewerService.Built;
import edu.bingol.backend.admin.chat.AdminChatViewerService.Brief;
import edu.bingol.backend.admin.chat.AdminChatViewerService.MessageItem;
import edu.bingol.backend.admin.chat.AdminChatViewerService.PersonView;
import edu.bingol.backend.admin.chat.AdminChatViewerService.Row;
import edu.bingol.backend.admin.chat.AdminChatViewerService.ViewerView;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.AdminDecryptService;
import edu.bingol.backend.crypto.MessageAccessAuditRepository.Entry;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Yonetici toplu izleme alani (V270): TUM sohbetlerdeki ekler ve mesajlar. Salt okunur; gorunurluk kisiti yoktur
 * (silinmis, gizlenmis, golge engelli, tek gosterimlik dahil). Her sayfa icerik donmeden ONCE degistirilemez denetim
 * kaydina yazilir (konusma basina bir satir; kind = MEDIA / FEED). Sorgular imlecli (id) ve parametrelidir;
 * mesaj cozme sayfa basina toplu yapilir, cozme hatasi satir bazindadir (`error`).
 */
@Service
public class AdminChatFeedService {

    public static final int MAX_MEDIA = 60;
    public static final int MAX_MESSAGES = 50;
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    public record ConversationBrief(long id, String type, String title, int memberCount) {}

    public record MediaItem(long attachmentId, long conversationId, String conversationTitle, String conversationType,
                            long messageId, PersonView sender, List<PersonView> recipients, int memberCount,
                            String kind, boolean viewOnce, List<ViewerView> viewedBy, boolean purged,
                            boolean messageDeleted, boolean hidden, boolean suppressed, String createdAt, int width,
                            int height, Integer durationMs, long bytes, String previewUrl, String thumbUrl) {}

    public record MediaPage(List<MediaItem> items, Long nextCursor) {}

    public record FeedMessage(MessageItem message, ConversationBrief conversation) {}

    public record FeedPage(List<FeedMessage> items, Long nextCursor) {}

    public record Counts(long imageCount, long videoCount, long viewOnceCount, long deletedMessageMediaCount,
                         long hiddenCount, long suppressedCount, long purgedCount, long totalBytes) {}

    public record Stats(long imageCount, long videoCount, long viewOnceCount, long deletedMessageMediaCount,
                        long hiddenCount, long suppressedCount, long purgedCount, long totalBytes, Counts last24h) {}

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final AdminDecryptService crypto;
    private final AdminChatViewerService viewer;

    public AdminChatFeedService(JdbcTemplate jdbc, AdminDecryptService crypto, AdminChatViewerService viewer) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
        this.crypto = crypto;
        this.viewer = viewer;
    }

    // --- ek akisi ---

    public MediaPage media(long adminId, Long cursor, int size, String kind, Boolean viewOnce, Boolean deleted,
                           Long userId, Long conversationId, String from, String to, String order, String ip) {
        crypto.requireEnabled();
        crypto.requireReason();
        int s = Math.min(Math.max(size, 1), MAX_MEDIA);
        boolean asc = isAsc(order);
        String k = kind == null ? "ALL" : kind.trim().toUpperCase(java.util.Locale.ROOT);
        if (!List.of("ALL", "IMAGE", "VIDEO").contains(k)) {
            throw bad();
        }
        MapSqlParameterSource p = new MapSqlParameterSource();
        StringBuilder w = new StringBuilder(" WHERE a.message_id IS NOT NULL");
        if (cursor != null) {
            w.append(asc ? " AND a.id > :cursor" : " AND a.id < :cursor");
            p.addValue("cursor", cursor);
        }
        if (!"ALL".equals(k)) {
            w.append(" AND a.kind = :kind");
            p.addValue("kind", k);
        }
        if (viewOnce != null) {
            w.append(" AND a.view_once = :vo");
            p.addValue("vo", viewOnce);
        }
        if (deleted != null) {
            w.append(deleted ? " AND m.deleted_at IS NOT NULL" : " AND m.deleted_at IS NULL");
        }
        if (userId != null) {
            // kullanicinin uye oldugu/oldugu tum sohbetlerdeki ekler (gonderen ya da alici)
            w.append(" AND a.conversation_id IN (SELECT cm.conversation_id FROM conversation_member cm WHERE cm.user_id = :uid)");
            p.addValue("uid", userId);
        }
        if (conversationId != null) {
            w.append(" AND a.conversation_id = :cid");
            p.addValue("cid", conversationId);
        }
        range(w, p, "a.created_at", from, to);
        String sql = "SELECT a.id, a.conversation_id, a.message_id, a.uploader_id, a.kind, a.view_once, a.purged_at, "
                + "a.hidden_at, a.created_at, a.width, a.height, a.duration_ms, a.bytes, m.deleted_at, m.suppressed "
                + "FROM message_attachment a JOIN message m ON m.id = a.message_id" + w
                + (asc ? " ORDER BY a.id ASC" : " ORDER BY a.id DESC") + " LIMIT :lim";
        p.addValue("lim", s + 1);
        List<Object[]> rows = new ArrayList<>(named.query(sql, p, (rs, i) -> {
            int d = rs.getInt("duration_ms");
            return new Object[] {rs.getLong("id"), rs.getLong("conversation_id"), rs.getLong("message_id"),
                    rs.getLong("uploader_id"), rs.getString("kind"), rs.getBoolean("view_once"),
                    rs.getTimestamp("purged_at") != null, rs.getTimestamp("hidden_at") != null,
                    rs.getTimestamp("created_at"), rs.getInt("width"), rs.getInt("height"), d, rs.getLong("bytes"),
                    rs.getTimestamp("deleted_at") != null, rs.getBoolean("suppressed")};
        }));
        boolean more = rows.size() > s;
        if (more) {
            rows = new ArrayList<>(rows.subList(0, s));
        }
        Long next = more ? (Long) rows.get(rows.size() - 1)[0] : null;

        List<Long> convIds = rows.stream().map(r -> (Long) r[1]).distinct().toList();
        Map<Long, Brief> briefs = viewer.briefs(convIds);
        Map<Long, PersonView> people = viewer.people(rows.stream().map(r -> (Long) r[3]).distinct().toList());
        Map<Long, List<ViewerView>> viewers = viewer.viewedBy(
                rows.stream().filter(r -> (Boolean) r[5]).map(r -> (Long) r[0]).toList());

        List<MediaItem> items = new ArrayList<>();
        Map<Long, long[]> perConv = new LinkedHashMap<>(); // {adet, enKucukMesaj, enBuyukMesaj}
        for (Object[] r : rows) {
            long id = (Long) r[0];
            long cid = (Long) r[1];
            long mid = (Long) r[2];
            long uploader = (Long) r[3];
            Brief b = briefs.get(cid);
            boolean direct = b != null && "DIRECT".equals(b.type());
            List<PersonView> recipients = new ArrayList<>();
            if (direct) {
                b.members().stream().filter(m -> m.person().id() != uploader).forEach(m -> recipients.add(m.person()));
            }
            boolean purged = (Boolean) r[6];
            String base = "/api/admin/media/attachments/" + id + "/preview";
            items.add(new MediaItem(id, cid, b == null ? null : b.title(), b == null ? null : b.type(), mid,
                    people.get(uploader), recipients, b == null ? 0 : b.memberCount(), (String) r[4], (Boolean) r[5],
                    viewers.getOrDefault(id, List.of()), purged, (Boolean) r[13], (Boolean) r[7], (Boolean) r[14],
                    ((Timestamp) r[8]).toInstant().toString(), (Integer) r[9], (Integer) r[10],
                    AdminChatViewerService.videoDuration((String) r[4], (Integer) r[11]), (Long) r[12],
                    purged ? null : base, purged ? null : base + "?thumb=true"));
            long[] c = perConv.computeIfAbsent(cid, x -> new long[] {0, mid, mid});
            c[0]++;
            c[1] = Math.min(c[1], mid);
            c[2] = Math.max(c[2], mid);
        }
        List<Entry> audit = new ArrayList<>();
        perConv.forEach((cid, c) -> audit.add(new Entry(adminId, userId, cid, (int) c[0], c[1], c[2],
                AdminDecryptService.currentReason(), ip, "MEDIA")));
        crypto.record(audit, ip); // once denetim, sonra icerik
        return new MediaPage(items, next);
    }

    // --- mesaj akisi ---

    public FeedPage messages(long adminId, Long cursor, int size, Long userId, Long senderId, Long conversationId,
                             Boolean deleted, Boolean suppressed, Boolean hasMedia, String from, String to, String ip) {
        crypto.requireEnabled();
        crypto.requireReason();
        int s = Math.min(Math.max(size, 1), MAX_MESSAGES);
        MapSqlParameterSource p = new MapSqlParameterSource();
        StringBuilder w = new StringBuilder(" WHERE 1 = 1");
        if (cursor != null) {
            w.append(" AND m.id < :cursor"); // en yeni once
            p.addValue("cursor", cursor);
        }
        if (userId != null) {
            w.append(" AND m.conversation_id IN (SELECT cm.conversation_id FROM conversation_member cm WHERE cm.user_id = :uid)");
            p.addValue("uid", userId);
        }
        if (senderId != null) {
            w.append(" AND m.sender_id = :sid");
            p.addValue("sid", senderId);
        }
        if (conversationId != null) {
            w.append(" AND m.conversation_id = :cid");
            p.addValue("cid", conversationId);
        }
        if (deleted != null) {
            w.append(deleted ? " AND m.deleted_at IS NOT NULL" : " AND m.deleted_at IS NULL");
        }
        if (suppressed != null) {
            w.append(" AND m.suppressed = :sup");
            p.addValue("sup", suppressed);
        }
        if (hasMedia != null) {
            w.append(hasMedia ? " AND" : " AND NOT").append(
                    " EXISTS (SELECT 1 FROM message_attachment x WHERE x.message_id = m.id)");
        }
        range(w, p, "m.created_at", from, to);
        p.addValue("lim", s + 1);
        List<Row> rows = new ArrayList<>(named.query(AdminChatViewerService.MESSAGE_SELECT + w
                + " ORDER BY m.id DESC LIMIT :lim", p, (rs, i) -> AdminChatViewerService.row(rs)));
        boolean more = rows.size() > s;
        if (more) {
            rows = new ArrayList<>(rows.subList(0, s));
        }
        Long next = more ? rows.get(rows.size() - 1).id() : null;

        Built built = viewer.build(rows, userId);
        List<Long> convIds = rows.stream().map(Row::conversationId).distinct().toList();
        Map<Long, Brief> briefs = viewer.briefs(convIds);

        List<FeedMessage> items = new ArrayList<>();
        Map<Long, long[]> perConv = new LinkedHashMap<>(); // {adet, min, max}
        for (MessageItem it : built.items()) {
            Brief b = briefs.get(it.conversationId());
            items.add(new FeedMessage(it, b == null ? null
                    : new ConversationBrief(b.id(), b.type(), b.title(), b.memberCount())));
            long[] c = perConv.computeIfAbsent(it.conversationId(), x -> new long[] {0, it.id(), it.id()});
            c[0]++;
            c[1] = Math.min(c[1], it.id());
            c[2] = Math.max(c[2], it.id());
        }
        List<Entry> audit = new ArrayList<>();
        perConv.forEach((cid, c) -> audit.add(new Entry(adminId, userId, cid, (int) c[0], c[1], c[2],
                AdminDecryptService.currentReason(), ip, "FEED")));
        crypto.record(audit, ip); // once denetim, sonra icerik
        return new FeedPage(items, next);
    }

    // --- istatistik ---

    public Stats stats(long adminId, String ip) {
        crypto.requireEnabled();
        Counts all = counts(null);
        Counts day = counts(Timestamp.from(Instant.now().minusSeconds(24 * 3600L)));
        return new Stats(all.imageCount(), all.videoCount(), all.viewOnceCount(), all.deletedMessageMediaCount(),
                all.hiddenCount(), all.suppressedCount(), all.purgedCount(), all.totalBytes(), day);
    }

    private Counts counts(Timestamp since) {
        String sql = "SELECT COALESCE(SUM(CASE WHEN a.kind = 'IMAGE' THEN 1 ELSE 0 END), 0) AS img, "
                + "COALESCE(SUM(CASE WHEN a.kind = 'VIDEO' THEN 1 ELSE 0 END), 0) AS vid, "
                + "COALESCE(SUM(CASE WHEN a.view_once THEN 1 ELSE 0 END), 0) AS vo, "
                + "COALESCE(SUM(CASE WHEN m.deleted_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS del, "
                + "COALESCE(SUM(CASE WHEN a.hidden_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS hid, "
                + "COALESCE(SUM(CASE WHEN m.suppressed THEN 1 ELSE 0 END), 0) AS sup, "
                + "COALESCE(SUM(CASE WHEN a.purged_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS pur, "
                + "COALESCE(SUM(a.bytes), 0) AS bytes FROM message_attachment a JOIN message m ON m.id = a.message_id"
                + (since == null ? "" : " WHERE a.created_at >= ?");
        return jdbc.query(sql, rs -> {
            rs.next();
            return new Counts(rs.getLong("img"), rs.getLong("vid"), rs.getLong("vo"), rs.getLong("del"),
                    rs.getLong("hid"), rs.getLong("sup"), rs.getLong("pur"), rs.getLong("bytes"));
        }, since == null ? new Object[0] : new Object[] {since});
    }

    // --- yardimcilar ---

    private static boolean isAsc(String order) {
        if (order == null || order.isBlank() || "desc".equalsIgnoreCase(order)) {
            return false;
        }
        if ("asc".equalsIgnoreCase(order)) {
            return true;
        }
        throw bad();
    }

    /** from (dahil) / to (hariç ya da gun ise o gun dahil) sinirlari; ISO an ya da yyyy-MM-dd (Europe/Istanbul). */
    private static void range(StringBuilder w, MapSqlParameterSource p, String col, String from, String to) {
        if (from != null && !from.isBlank()) {
            w.append(" AND ").append(col).append(" >= :from");
            p.addValue("from", Timestamp.from(parse(from, false)));
        }
        if (to != null && !to.isBlank()) {
            w.append(" AND ").append(col).append(" < :to");
            p.addValue("to", Timestamp.from(parse(to, true)));
        }
    }

    static Instant parse(String s, boolean endInclusiveDay) {
        String v = s.trim();
        try {
            if (v.length() == 10) {
                LocalDate d = LocalDate.parse(v);
                return (endInclusiveDay ? d.plusDays(1) : d).atStartOfDay(ZONE).toInstant();
            }
            return Instant.parse(v);
        } catch (DateTimeParseException e) {
            throw bad();
        }
    }

    private static ApiException bad() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_FILTER", "Geçersiz süzgeç değeri.");
    }
}
