package edu.bingol.backend.admin.chat;

import edu.bingol.backend.admin.chat.AdminChatViewerService.Brief;
import edu.bingol.backend.admin.chat.AdminChatViewerService.Built;
import edu.bingol.backend.admin.chat.AdminChatViewerService.MessageItem;
import edu.bingol.backend.admin.chat.AdminChatViewerService.PersonView;
import edu.bingol.backend.admin.chat.AdminChatViewerService.Row;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.AdminDecryptService;
import edu.bingol.backend.crypto.MessageAccessAuditRepository.Entry;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.dto.ModerationDtos.Person;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReportView;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Sikayet baglami (V271 gerektirmez): yonetici bir sikayeti actiginda sikayetin KONUSUNU gorur. MESSAGE/MESSAGE_IMAGE
 * icin mesaj (silinmis olsa da cozulmus), ekler ve +-10 mesaj; USER icin ortak birebir sohbetin son 20 mesaji;
 * POST/COMMUNITY/EVENT icin icerik ozeti. Yonetici icin clearedUpTo/leftAt/gizleme kurallari UYGULANMAZ.
 * Sifreli icerik donmeden ONCE denetim kaydi (kind REPORT_CONTEXT) yazilir.
 */
@Service
public class AdminReportContextService {

    static final int AROUND = 10;
    static final int DIRECT_LAST = 20;

    public record ContextMessage(boolean reported, MessageItem message) {}

    public record ChatInfo(long id, String type, String title, int memberCount, List<AdminChatViewerService.MemberView> members) {}

    /** Kesfet gonderisi/yorumu icin medya onizleme baglantisi (yonetici ucu). */
    public record ContentMedia(long id, String kind, String url, String thumbUrl) {}

    /** postId/media yalniz FEED_POST (media) icin dolar; status VISIBLE|HIDDEN|DELETED (FEED_*). */
    public record Content(String kind, Long id, String title, String text, Long communityId, Long ownerId,
                          String imageUrl, boolean deleted, String status, String createdAt, Long postId,
                          List<ContentMedia> media) {}

    public record UserStats(long reportsAgainstUser, long activeStrikes, long totalStrikes) {}

    /** type: MESSAGE | MESSAGE_IMAGE | USER | CONTENT | NONE. */
    public record Context(String type, boolean targetExists, ChatInfo conversation, Long reportedMessageId,
                          Long reportedAttachmentId, List<ContextMessage> messages, Content content,
                          UserStats userStats) {}

    public record RelatedItem(long id, Person reporter, String reason, String status, String createdAt) {}

    public record Related(long sameTargetCount, List<RelatedItem> last) {}

    public record ReportDetail(long id, String targetType, long targetId, String reason, String reasonCode, String note,
                               String status, String resolution, int priority, String createdAt, String resolvedAt,
                               Person reporter, Person reportedUser, Context context, Related relatedReports,
                               String viewerPath) {}

    private final JdbcTemplate jdbc;
    private final ReportRepository reports;
    private final AdminDecryptService crypto;
    private final AdminChatViewerService viewer;

    public AdminReportContextService(JdbcTemplate jdbc, ReportRepository reports, AdminDecryptService crypto,
                                     AdminChatViewerService viewer) {
        this.jdbc = jdbc;
        this.reports = reports;
        this.crypto = crypto;
        this.viewer = viewer;
    }

    public ReportDetail detail(long adminId, long reportId, String ip) {
        Report r = reports.findById(reportId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "REPORT_NOT_FOUND", "Rapor bulunamadı."));
        String type = r.getTargetType().name();
        long tid = r.getTargetId();
        Target t = resolve(type, tid);
        if ("USER".equals(type)) { // ortak birebir sohbet varsa derin baglanti ona gider
            Long shared = directChat(r.getReporterId(), tid);
            if (shared != null) {
                t = new Target(tid, null, shared, null);
            }
        }
        final Target target = t;
        Map<Long, Person> people = persons(t.ownerId == null ? List.of(r.getReporterId())
                : List.of(r.getReporterId(), t.ownerId));
        Context ctx = context(adminId, r, target, ip);
        return new ReportDetail(r.getId(), type, tid, r.getReason().name(), r.getReasonCode(), r.getNote(),
                r.getStatus().name(), r.getResolution() == null ? null : r.getResolution().name(), r.getPriority(),
                r.getCreatedAt().toString(), r.getResolvedAt() == null ? null : r.getResolvedAt().toString(),
                people.get(r.getReporterId()), target.ownerId == null ? null : people.get(target.ownerId), ctx,
                related(r), target.viewerPath());
    }

    /** Kuyruk satirlarina sikayet eden / edilen kullanici ve derin baglanti ekler (hafif; icerik cozmez). */
    public List<ReportView> decorate(List<ReportView> items) {
        if (items.isEmpty()) {
            return items;
        }
        Map<Long, Target> targets = new HashMap<>();
        List<Long> ids = new ArrayList<>();
        for (ReportView v : items) {
            Target t = resolve(v.targetType().name(), v.targetId());
            targets.put(v.id(), t);
            ids.add(v.reporterId());
            if (t.ownerId != null) {
                ids.add(t.ownerId);
            }
        }
        Map<Long, Person> people = persons(ids);
        List<ReportView> out = new ArrayList<>();
        for (ReportView v : items) {
            Target t = targets.get(v.id());
            out.add(v.withPeople(people.get(v.reporterId()), t.ownerId == null ? null : people.get(t.ownerId),
                    t.viewerPath()));
        }
        return out;
    }

    // --- hedef cozumleme ---

    private record Target(Long ownerId, Long messageId, Long conversationId, Long attachmentId) {
        String viewerPath() {
            if (ownerId == null || conversationId == null) {
                return ownerId == null ? null : "/admin/users/" + ownerId + "/messages";
            }
            return "/admin/users/" + ownerId + "/messages?c=" + conversationId
                    + (messageId == null ? "" : "&m=" + messageId);
        }
    }

    private Target resolve(String type, long id) {
        switch (type) {
            case "MESSAGE": {
                var rows = jdbc.query("SELECT sender_id, conversation_id FROM message WHERE id = ?",
                        (rs, i) -> new long[] {rs.getLong(1), rs.getLong(2)}, id);
                return rows.isEmpty() ? new Target(null, null, null, null)
                        : new Target(rows.get(0)[0], id, rows.get(0)[1], null);
            }
            case "MESSAGE_IMAGE": {
                var rows = jdbc.query("SELECT uploader_id, conversation_id, message_id FROM message_attachment WHERE id = ?",
                        (rs, i) -> new Long[] {rs.getLong(1), rs.getLong(2), (Long) rs.getObject(3)}, id);
                return rows.isEmpty() ? new Target(null, null, null, null)
                        : new Target(rows.get(0)[0], rows.get(0)[2], rows.get(0)[1], id);
            }
            case "USER", "USER_AVATAR":
                return new Target(id, null, null, null);
            case "POST":
                return owner("SELECT author_id FROM community_post WHERE id = ?", id);
            case "COMMUNITY":
                return owner("SELECT owner_id FROM community WHERE id = ?", id);
            case "EVENT":
                return owner("SELECT created_by FROM user_event WHERE id = ?", id);
            case "FEED_POST":
                return owner("SELECT author_id FROM post WHERE id = ?", id);
            default:
                return new Target(null, null, null, null);
        }
    }

    private Target owner(String sql, long id) {
        List<Long> r = jdbc.query(sql, (rs, i) -> (Long) rs.getObject(1), id);
        return new Target(r.isEmpty() ? null : r.get(0), null, null, null);
    }

    // --- baglam ---

    private Context context(long adminId, Report r, Target t, String ip) {
        String type = r.getTargetType().name();
        switch (type) {
            case "MESSAGE", "MESSAGE_IMAGE":
                if (t.conversationId == null || t.messageId == null) {
                    return new Context(type, false, null, null, t.attachmentId, List.of(), null, stats(t.ownerId));
                }
                return chatContext(adminId, type, t, aroundRows(t.conversationId, t.messageId), ip);
            case "USER", "USER_AVATAR": {
                Long cid = directChat(r.getReporterId(), r.getTargetId());
                if ("USER".equals(type) && cid != null) {
                    return chatContext(adminId, type, new Target(t.ownerId, null, cid, null), lastRows(cid), ip);
                }
                return new Context(type, t.ownerId != null && userExists(r.getTargetId()), null, null, null, List.of(),
                        null, stats(t.ownerId));
            }
            case "POST", "COMMUNITY", "EVENT", "FEED_POST":
                return new Context(type, t.ownerId != null, null, null, null, List.of(), content(type, r.getTargetId()),
                        stats(t.ownerId));
            default:
                return new Context("NONE", false, null, null, null, List.of(), null, stats(t.ownerId));
        }
    }

    private Context chatContext(long adminId, String type, Target t, List<Row> rows, String ip) {
        if (rows.isEmpty()) {
            return new Context(type, false, null, t.messageId, t.attachmentId, List.of(), null, stats(t.ownerId));
        }
        crypto.requireEnabled();
        crypto.requireReason();
        Built built = viewer.build(rows, t.ownerId);
        long cid = t.conversationId;
        Brief b = viewer.briefs(List.of(cid)).get(cid);
        List<ContextMessage> msgs = new ArrayList<>();
        for (MessageItem it : built.items()) {
            msgs.add(new ContextMessage(t.messageId != null && it.id() == t.messageId, it));
        }
        Long from = rows.get(0).id();
        Long to = rows.get(rows.size() - 1).id();
        crypto.record(List.of(new Entry(adminId, t.ownerId, cid, built.decrypted(), from, to,
                AdminDecryptService.currentReason(), ip, "REPORT_CONTEXT")), ip); // once denetim, sonra icerik
        ChatInfo info = b == null ? null : new ChatInfo(b.id(), b.type(), b.title(), b.memberCount(), b.members());
        boolean exists = t.messageId == null || rows.stream().anyMatch(x -> x.id() == t.messageId);
        return new Context(type, exists, info, t.messageId, t.attachmentId, msgs, null, stats(t.ownerId));
    }

    /** Sikayet edilen mesaj + oncesinden/sonrasindan AROUND mesaj (eskiden yeniye). Yonetici icin kisit yok. */
    private List<Row> aroundRows(long cid, long mid) {
        List<Row> before = new ArrayList<>(jdbc.query(AdminChatViewerService.MESSAGE_SELECT
                        + " WHERE m.conversation_id = ? AND m.id <= ? ORDER BY m.id DESC LIMIT ?",
                (rs, i) -> AdminChatViewerService.row(rs), cid, mid, AROUND + 1));
        Collections.reverse(before);
        List<Row> after = jdbc.query(AdminChatViewerService.MESSAGE_SELECT
                        + " WHERE m.conversation_id = ? AND m.id > ? ORDER BY m.id ASC LIMIT ?",
                (rs, i) -> AdminChatViewerService.row(rs), cid, mid, AROUND);
        before.addAll(after);
        return before;
    }

    private List<Row> lastRows(long cid) {
        List<Row> rows = new ArrayList<>(jdbc.query(AdminChatViewerService.MESSAGE_SELECT
                        + " WHERE m.conversation_id = ? ORDER BY m.id DESC LIMIT ?",
                (rs, i) -> AdminChatViewerService.row(rs), cid, DIRECT_LAST));
        Collections.reverse(rows);
        return rows;
    }

    /** Yalniz iki kullanici arasindaki birebir sohbet (varsa en yenisi). */
    private Long directChat(long a, long b) {
        List<Long> r = jdbc.query("SELECT c.id FROM conversation c WHERE c.type = 'DIRECT' "
                        + "AND EXISTS (SELECT 1 FROM conversation_member x WHERE x.conversation_id = c.id AND x.user_id = ?) "
                        + "AND EXISTS (SELECT 1 FROM conversation_member y WHERE y.conversation_id = c.id AND y.user_id = ?) "
                        + "ORDER BY c.id DESC LIMIT 1", (rs, i) -> rs.getLong(1), a, b);
        return r.isEmpty() ? null : r.get(0);
    }

    private boolean userExists(long id) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT COUNT(*) > 0 FROM app_user WHERE id = ?", Boolean.class, id));
    }

    private Content content(String type, long id) {
        switch (type) {
            case "POST":
                return first(jdbc.query("SELECT id, community_id, author_id, content, image_url, deleted, created_at "
                                + "FROM community_post WHERE id = ?", (rs, i) -> new Content("POST", rs.getLong("id"), null,
                        rs.getString("content"), rs.getLong("community_id"), rs.getLong("author_id"),
                        rs.getString("image_url"), rs.getBoolean("deleted"), null, ts(rs.getTimestamp("created_at")), null, null), id));
            case "COMMUNITY":
                return first(jdbc.query("SELECT id, name, description, owner_id, status, cover_url, created_at "
                                + "FROM community WHERE id = ?", (rs, i) -> new Content("COMMUNITY", rs.getLong("id"),
                        rs.getString("name"), rs.getString("description"), rs.getLong("id"), rs.getLong("owner_id"),
                        rs.getString("cover_url"), false, rs.getString("status"), ts(rs.getTimestamp("created_at")), null, null), id));
            case "FEED_POST":
                return feedPost(id);
            default:
                return first(jdbc.query("SELECT id, title, description, community_id, created_by, created_at "
                                + "FROM user_event WHERE id = ?", (rs, i) -> new Content("EVENT", rs.getLong("id"),
                        rs.getString("title"), rs.getString("description"), (Long) rs.getObject("community_id"),
                        rs.getLong("created_by"), null, false, null, ts(rs.getTimestamp("created_at")), null, null), id));
        }
    }

    private Content feedPost(long id) {
        List<ContentMedia> media = jdbc.query("SELECT id, kind FROM post_media WHERE post_id = ? ORDER BY position, id",
                (rs, i) -> new ContentMedia(rs.getLong(1), rs.getString(2), "/api/admin/posts/media/" + rs.getLong(1),
                        "/api/admin/posts/media/" + rs.getLong(1) + "?thumb=true"), id);
        String thumb = media.isEmpty() ? null : media.get(0).thumbUrl();
        return first(jdbc.query("SELECT id, author_id, body, created_at, deleted_at, hidden_at FROM post WHERE id = ?",
                (rs, i) -> new Content("FEED_POST", rs.getLong("id"), null, rs.getString("body"), null,
                        rs.getLong("author_id"), thumb, rs.getTimestamp("deleted_at") != null,
                        feedStatus(rs.getTimestamp("deleted_at"), rs.getTimestamp("hidden_at")),
                        ts(rs.getTimestamp("created_at")), rs.getLong("id"), media), id));
    }

    private static String feedStatus(java.sql.Timestamp deletedAt, java.sql.Timestamp hiddenAt) {
        return deletedAt != null ? "DELETED" : hiddenAt != null ? "HIDDEN" : "VISIBLE";
    }

    private static <T> T first(List<T> l) {
        return l.isEmpty() ? null : l.get(0);
    }

    private static String ts(java.sql.Timestamp t) {
        return t == null ? null : t.toInstant().toString();
    }

    private UserStats stats(Long userId) {
        if (userId == null) {
            return null;
        }
        long against = jdbc.queryForObject("SELECT COUNT(*) FROM report WHERE target_type = 'USER' AND target_id = ?",
                Long.class, userId);
        long total = jdbc.queryForObject("SELECT COUNT(*) FROM moderation_strike WHERE user_id = ?", Long.class, userId);
        long active = jdbc.queryForObject("SELECT COUNT(*) FROM moderation_strike WHERE user_id = ? AND revoked_at IS NULL",
                Long.class, userId);
        return new UserStats(against, active, total);
    }

    private Related related(Report r) {
        long n = jdbc.queryForObject("SELECT COUNT(*) FROM report WHERE target_type = ? AND target_id = ? AND id <> ?",
                Long.class, r.getTargetType().name(), r.getTargetId(), r.getId());
        List<Object[]> last = jdbc.query("SELECT id, reporter_id, reason, status, created_at FROM report "
                        + "WHERE target_type = ? AND target_id = ? AND id <> ? ORDER BY id DESC LIMIT 5",
                (rs, i) -> new Object[] {rs.getLong(1), rs.getLong(2), rs.getString(3), rs.getString(4),
                        ts(rs.getTimestamp(5))}, r.getTargetType().name(), r.getTargetId(), r.getId());
        Map<Long, Person> people = persons(last.stream().map(o -> (Long) o[1]).toList());
        return new Related(n, last.stream().map(o -> new RelatedItem((Long) o[0], people.get((Long) o[1]),
                (String) o[2], (String) o[3], (String) o[4])).toList());
    }

    private Map<Long, Person> persons(List<Long> ids) {
        Map<Long, Person> out = new HashMap<>();
        Map<Long, PersonView> p = viewer.people(ids.stream().distinct().toList());
        p.forEach((k, v) -> out.put(k, new Person(v.id(), v.displayName(), v.email())));
        return out;
    }
}
