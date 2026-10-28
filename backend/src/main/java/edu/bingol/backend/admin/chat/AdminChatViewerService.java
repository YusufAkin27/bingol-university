package edu.bingol.backend.admin.chat;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.AdminDecryptService;
import edu.bingol.backend.crypto.AdminDecryptService.Plain;
import edu.bingol.backend.crypto.MessageAccessAuditRepository.Entry;
import edu.bingol.backend.crypto.Sealed;
import edu.bingol.backend.messaging.MessageCodec;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Yonetici kullanici-bazli sohbet goruntuleyicisi (T24, V270 ile genisletildi). Salt okunur; sayfa istegi basina
 * sunucu toplu cozer, her sayfa icin degistirilemez denetim kaydi YAZILDIKTAN SONRA icerik doner.
 * Yonetici icin gorunurluk KISITI YOKTUR: kullanicinin uye oldugu ve OLMUS oldugu tum konusmalar (ayrilmis, listeden
 * silinmis/gizlenmis, "sohbeti sil" ile temizlenmis, arsivli, sessize alinmis), konusmadaki TUM uyelerin tum mesajlari
 * (silinmis, moderasyonla gizlenmis, golge engelle bastirilmis dahil), duzenleme gecmisi ve ekler gosterilir.
 * Kapsam yalnizca UYELIKLE sinirlidir (IDOR): hedef kullanici hic uye olmadigi konusma 404.
 */
@Service
public class AdminChatViewerService {

    public static final int MAX_CONVERSATIONS = 30;
    public static final int MAX_MESSAGES = 50;
    static final int PREVIEW_LENGTH = 100;

    public record PersonView(Long id, String displayName, String avatarUrl, String email) {}

    public record LastMessage(long id, long senderId, boolean mine, String text, String error, boolean deleted,
                              boolean hidden, boolean suppressed, String createdAt) {}

    /** Kullanicinin konusma uzerindeki kendi durumu; yonetici icin gorunurluk kisiti DEGILDIR (yalniz bilgi). */
    public record UserState(boolean hiddenByUser, boolean cleared, boolean archived, boolean muted) {}

    public record ConversationItem(long id, String type, String title, PersonView peer, int memberCount,
                                   long totalMessages, String lastActivityAt, boolean left, String joinedAt,
                                   String leftAt, UserState state, LastMessage lastMessage) {}

    public record ConversationPage(PersonView user, List<ConversationItem> items, Long nextCursor) {}

    public record ReplyView(long id, Long senderId, String text, String error, boolean deleted) {}

    public record ReactionView(String emoji, long userId) {}

    public record RevisionView(String text, String error, String revisedAt) {}

    /** Tek gosterimlik eki acan kullanici ve an. */
    public record ViewerView(long id, String displayName, String at) {}

    /**
     * Mesaj eki (`message_attachment`); gizli/silinmis mesajin eki de listelenir. previewUrl/thumbUrl yonetici
     * onizleme ucuna (`/api/admin/media/attachments/{id}/preview`) isaret eder (Bearer ile istenir); baytlari saklama
     * suresi nedeniyle silinmis (purged) eklerde null.
     */
    public record AttachmentView(long id, String kind, String contentType, int width, int height, Integer durationMs,
                                 long bytes, boolean viewOnce, List<ViewerView> viewedBy, boolean purged,
                                 boolean hidden, boolean messageDeleted, String previewUrl, String thumbUrl) {}

    /** status: SENT / DELIVERED / READ (gonderen disindaki herhangi bir uyenin makbuzuna gore; bastirilmis mesaj hep SENT). */
    public record MessageItem(long id, long conversationId, long senderId, String senderName, PersonView sender,
                              boolean mine, String createdAt, String text, String error, boolean edited,
                              String editedAt, List<RevisionView> revisions, boolean deleted, String deletedAt,
                              Long deletedBy, String deletedByName, String deleteKind, boolean hidden,
                              boolean suppressed, PersonView blockedBy, String status, ReplyView replyTo,
                              List<ReactionView> reactions, List<AttachmentView> attachments) {}

    public record MemberView(PersonView person, String role, String joinedAt, String leftAt) {}

    public record ConversationInfo(long id, String type, String title, PersonView peer, boolean left, UserState state,
                                   List<MemberView> members) {}

    /** items: eskiden yeniye. nextBefore: bir sonraki (daha eski) sayfa icin imlec; yoksa null. */
    public record MessagePage(PersonView user, ConversationInfo conversation, List<MessageItem> items, Long nextBefore) {}

    /** Konusma ozeti (birebirde baslik katilimci adlarindan turetilir). */
    record Brief(long id, String type, String title, int memberCount, List<MemberView> members) {}

    private record Membership(long conversationId, String type, String title, Instant joinedAt, Instant leftAt,
                              UserState state) {
        boolean group() {
            return "GROUP".equals(type);
        }
    }

    record Row(long id, long conversationId, long senderId, String clientId, Instant createdAt, Sealed sealed,
               Long replyTo, Instant editedAt, Instant deletedAt, Long deletedBy, boolean hidden, boolean suppressed) {}

    record Built(List<MessageItem> items, int decrypted) {}

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final AdminDecryptService crypto;

    public AdminChatViewerService(JdbcTemplate jdbc, AdminDecryptService crypto) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
        this.crypto = crypto;
    }

    // --- konusma listesi ---

    public ConversationPage conversations(long adminId, long userId, Long cursor, int size, String ip) {
        crypto.requireEnabled();
        crypto.requireReason();
        PersonView user = person(userId);
        if (user == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        int s = Math.min(Math.max(size, 1), MAX_CONVERSATIONS);
        List<Object> args = new ArrayList<>();
        args.add(userId);
        // Hic mesaji olmayan konusma bos; geri kalan her uyelik (ayrilmis/gizlenmis/arsivli dahil) listelenir
        String sql = "SELECT c.id, c.type, c.title, c.last_message_id, c.last_message_at, cm.joined_at, cm.left_at, "
                + "cm.hidden_at, cm.cleared_up_to_message_id, cm.archived_at, cm.muted_until "
                + "FROM conversation_member cm JOIN conversation c ON c.id = cm.conversation_id "
                + "WHERE cm.user_id = ? AND c.last_message_id IS NOT NULL";
        if (cursor != null) {
            sql += " AND c.last_message_id < ?";
            args.add(cursor);
        }
        sql += " ORDER BY c.last_message_id DESC LIMIT ?";
        args.add(s + 1);
        List<Object[]> rows = jdbc.query(sql, (rs, i) -> new Object[] {rs.getLong("id"), rs.getLong("last_message_id"),
                rs.getTimestamp("last_message_at"), membership(rs)}, args.toArray());
        boolean more = rows.size() > s;
        List<Object[]> page = more ? rows.subList(0, s) : rows;
        Long next = more ? (Long) page.get(page.size() - 1)[1] : null;

        List<Long> ids = page.stream().map(r -> (Long) r[0]).toList();
        Map<Long, PersonView> peers = peers(ids, userId);
        Map<Long, Integer> memberCounts = memberCounts(ids);
        Map<Long, Long> totals = totals(ids);
        Map<Long, Row> lasts = lastRows(page.stream().map(r -> (Long) r[1]).toList());

        List<ConversationItem> items = new ArrayList<>();
        List<Entry> audit = new ArrayList<>();
        for (Object[] r : page) {
            long cid = (Long) r[0];
            Membership m = (Membership) r[3];
            Row l = lasts.get((Long) r[1]);
            LastMessage preview = null;
            if (l != null && l.conversationId() == cid) {
                Plain p = crypto.open(cid, MessageCodec.context(l.senderId(), l.clientId()), l.sealed());
                preview = new LastMessage(l.id(), l.senderId(), l.senderId() == userId, truncate(p.text()), p.error(),
                        l.deletedAt() != null, l.hidden(), l.suppressed(), l.createdAt().toString());
                audit.add(new Entry(adminId, userId, cid, 1, l.id(), l.id(), AdminDecryptService.currentReason(), ip,
                        "LIST_PREVIEW"));
            }
            Timestamp at = (Timestamp) r[2];
            items.add(new ConversationItem(cid, m.type(), m.title(), m.group() ? null : peers.get(cid),
                    memberCounts.getOrDefault(cid, 0), totals.getOrDefault(cid, 0L), at == null ? null : at.toInstant().toString(),
                    m.leftAt() != null, str(m.joinedAt()), str(m.leftAt()), m.state(), preview));
        }
        crypto.record(audit, ip); // once denetim, sonra icerik
        return new ConversationPage(user, items, next);
    }

    // --- mesajlar ---

    public MessagePage messages(long adminId, long userId, long conversationId, Long before, int size, String ip) {
        crypto.requireEnabled();
        crypto.requireReason();
        PersonView user = person(userId);
        if (user == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        Membership m = jdbc.query("SELECT c.id, c.type, c.title, cm.joined_at, cm.left_at, cm.hidden_at, "
                        + "cm.cleared_up_to_message_id, cm.archived_at, cm.muted_until FROM conversation_member cm "
                        + "JOIN conversation c ON c.id = cm.conversation_id WHERE cm.user_id = ? AND c.id = ?",
                (rs, i) -> membership(rs), userId, conversationId).stream().findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı."));
        int s = Math.min(Math.max(size, 1), MAX_MESSAGES);
        // Yonetici icin uyelik penceresi, clearedUpTo ve gizleme uygulanmaz: konusmanin TUM mesajlari
        List<Object> args = new ArrayList<>(List.of(conversationId));
        String sql = MESSAGE_SELECT + " WHERE m.conversation_id = ?";
        if (before != null) {
            sql += " AND m.id < ?";
            args.add(before);
        }
        sql += " ORDER BY m.id DESC LIMIT ?";
        args.add(s + 1);
        List<Row> rows = new ArrayList<>(jdbc.query(sql, (rs, i) -> row(rs), args.toArray()));
        boolean more = rows.size() > s;
        if (more) {
            rows = new ArrayList<>(rows.subList(0, s));
        }
        Long nextBefore = more ? rows.get(rows.size() - 1).id() : null;
        java.util.Collections.reverse(rows); // eskiden yeniye

        Built built = build(rows, userId);
        List<Long> ids = rows.stream().map(Row::id).toList();
        Long from = ids.isEmpty() ? null : ids.get(0);
        Long to = ids.isEmpty() ? null : ids.get(ids.size() - 1);
        crypto.record(List.of(new Entry(adminId, userId, conversationId, built.decrypted(), from, to,
                AdminDecryptService.currentReason(), ip, "VIEW_MESSAGES")), ip); // once denetim, sonra icerik

        Brief brief = briefs(List.of(conversationId)).get(conversationId);
        PersonView peer = m.group() ? null : peers(List.of(conversationId), userId).get(conversationId);
        return new MessagePage(user, new ConversationInfo(conversationId, m.type(), m.title(), peer, m.leftAt() != null,
                m.state(), brief == null ? List.of() : brief.members()), built.items(), nextBefore);
    }

    // --- ortak kurucular (akis servisi de kullanir) ---

    static final String MESSAGE_SELECT = "SELECT m.id, m.conversation_id, m.sender_id, m.client_id, m.created_at, "
            + "m.body_ciphertext, m.body_nonce, m.key_version, m.reply_to_message_id, m.edited_at, m.deleted_at, "
            + "m.deleted_by, m.hidden_at, m.suppressed FROM message m";

    static Row row(java.sql.ResultSet rs) throws java.sql.SQLException {
        byte[] ct = rs.getBytes("body_ciphertext");
        byte[] nonce = rs.getBytes("body_nonce");
        Sealed sealed = ct == null || nonce == null ? null : new Sealed(ct, nonce, rs.getInt("key_version"));
        long replyTo = rs.getLong("reply_to_message_id");
        boolean replyNull = rs.wasNull();
        long deletedBy = rs.getLong("deleted_by");
        boolean deletedByNull = rs.wasNull();
        return new Row(rs.getLong("id"), rs.getLong("conversation_id"), rs.getLong("sender_id"),
                rs.getString("client_id"), instant(rs.getTimestamp("created_at")), sealed, replyNull ? null : replyTo,
                instant(rs.getTimestamp("edited_at")), instant(rs.getTimestamp("deleted_at")),
                deletedByNull ? null : deletedBy, rs.getTimestamp("hidden_at") != null, rs.getBoolean("suppressed"));
    }

    /**
     * Satirlari (birden fazla konusmadan olabilir) toplu cozer: sayfa basina sabit sayida sorgu (N+1 yok).
     * viewerId: "mine" icin goz onundeki kullanici (yoksa null).
     */
    Built build(List<Row> rows, Long viewerId) {
        List<Long> ids = rows.stream().map(Row::id).toList();
        Set<Long> convIds = new LinkedHashSet<>();
        rows.forEach(r -> convIds.add(r.conversationId()));
        Map<Long, List<ReactionView>> reactions = reactions(ids);
        Map<Long, List<RevisionView>> revisions = revisions(rows);
        Map<Long, ReplyView> replies = replies(rows);
        Map<Long, List<AttachmentView>> attachments = attachments(ids);
        Map<Long, List<long[]>> receipts = receipts(convIds);
        Map<Long, PersonView> blockers = rows.stream().anyMatch(Row::suppressed) ? blockers(rows) : Map.of();
        Set<Long> userIds = new LinkedHashSet<>();
        rows.forEach(r -> {
            userIds.add(r.senderId());
            if (r.deletedBy() != null) {
                userIds.add(r.deletedBy());
            }
        });
        Map<Long, PersonView> people = people(userIds);

        List<MessageItem> items = new ArrayList<>();
        int decrypted = 0;
        for (Row r : rows) {
            Plain p = crypto.open(r.conversationId(), MessageCodec.context(r.senderId(), r.clientId()), r.sealed());
            List<RevisionView> revs = revisions.getOrDefault(r.id(), List.of());
            decrypted += 1 + revs.size();
            PersonView sender = people.get(r.senderId());
            PersonView deleter = r.deletedBy() == null ? null : people.get(r.deletedBy());
            items.add(new MessageItem(r.id(), r.conversationId(), r.senderId(), sender == null ? null : sender.displayName(),
                    sender, viewerId != null && r.senderId() == viewerId, r.createdAt().toString(), p.text(), p.error(),
                    r.editedAt() != null, str(r.editedAt()), revs, r.deletedAt() != null, str(r.deletedAt()),
                    r.deletedBy(), deleter == null ? null : deleter.displayName(), deleteKind(r), r.hidden(),
                    r.suppressed(), r.suppressed() ? blockers.get(r.id()) : null, status(r, receipts.get(r.conversationId())),
                    replies.get(r.id()), reactions.getOrDefault(r.id(), List.of()),
                    attachments.getOrDefault(r.id(), List.of())));
        }
        return new Built(items, decrypted);
    }

    /** Silme yalnizca "herkes icin" vardir; kendi silmesi (BY_SENDER) ile yonetici/moderator silmesi (BY_OTHER) ayrilir. */
    private static String deleteKind(Row r) {
        if (r.deletedAt() == null) {
            return null;
        }
        return r.deletedBy() != null && r.deletedBy() != r.senderId() ? "EVERYONE_BY_OTHER" : "EVERYONE_BY_SENDER";
    }

    private static String status(Row r, List<long[]> members) {
        if (r.suppressed() || members == null) {
            return "SENT"; // golge engel: karsi tarafa hicbir zaman ulasmaz
        }
        boolean delivered = false;
        for (long[] mm : members) { // {userId, lastRead, lastDelivered}
            if (mm[0] == r.senderId()) {
                continue;
            }
            if (mm[1] >= r.id()) {
                return "READ";
            }
            delivered |= mm[2] >= r.id();
        }
        return delivered ? "DELIVERED" : "SENT";
    }

    // --- yardimcilar ---

    private static Membership membership(java.sql.ResultSet rs) throws java.sql.SQLException {
        UserState st = new UserState(rs.getTimestamp("hidden_at") != null, rs.getLong("cleared_up_to_message_id") > 0,
                rs.getTimestamp("archived_at") != null,
                rs.getTimestamp("muted_until") != null && rs.getTimestamp("muted_until").toInstant().isAfter(Instant.now()));
        return new Membership(rs.getLong("id"), rs.getString("type"), rs.getString("title"),
                instant(rs.getTimestamp("joined_at")), instant(rs.getTimestamp("left_at")), st);
    }

    private PersonView person(long userId) {
        return jdbc.query("SELECT id, display_name, avatar_url, email FROM app_user WHERE id = ?",
                (rs, i) -> new PersonView(rs.getLong("id"), rs.getString("display_name"), rs.getString("avatar_url"),
                        rs.getString("email")), userId).stream().findFirst().orElse(null);
    }

    Map<Long, PersonView> people(Collection<Long> ids) {
        Map<Long, PersonView> out = new HashMap<>();
        if (ids.isEmpty()) {
            return out;
        }
        named.query("SELECT id, display_name, avatar_url, email FROM app_user WHERE id IN (:ids)",
                new MapSqlParameterSource("ids", ids), rs -> {
                    out.put(rs.getLong("id"), new PersonView(rs.getLong("id"), rs.getString("display_name"),
                            rs.getString("avatar_url"), rs.getString("email")));
                });
        return out;
    }

    private Map<Long, PersonView> peers(List<Long> conversationIds, long userId) {
        Map<Long, PersonView> out = new HashMap<>();
        if (conversationIds.isEmpty()) {
            return out;
        }
        named.query("SELECT cm.conversation_id AS cid, u.id, u.display_name, u.avatar_url, u.email FROM conversation_member cm "
                        + "JOIN app_user u ON u.id = cm.user_id JOIN conversation c ON c.id = cm.conversation_id "
                        + "WHERE cm.conversation_id IN (:ids) AND cm.user_id <> :uid AND c.type = 'DIRECT' ORDER BY cm.id",
                new MapSqlParameterSource("ids", conversationIds).addValue("uid", userId), rs -> {
                    out.putIfAbsent(rs.getLong("cid"), new PersonView(rs.getLong("id"), rs.getString("display_name"),
                            rs.getString("avatar_url"), rs.getString("email")));
                });
        return out;
    }

    private Map<Long, Integer> memberCounts(List<Long> conversationIds) {
        Map<Long, Integer> out = new HashMap<>();
        if (conversationIds.isEmpty()) {
            return out;
        }
        named.query("SELECT conversation_id AS cid, COUNT(*) AS n FROM conversation_member "
                        + "WHERE conversation_id IN (:ids) AND left_at IS NULL GROUP BY conversation_id",
                new MapSqlParameterSource("ids", conversationIds), rs -> {
                    out.put(rs.getLong("cid"), rs.getInt("n"));
                });
        return out;
    }

    /** Konusma basina TUM mesaj sayisi (silinmis ve bastirilmis dahil), tek sorgu. */
    private Map<Long, Long> totals(List<Long> conversationIds) {
        Map<Long, Long> out = new HashMap<>();
        if (conversationIds.isEmpty()) {
            return out;
        }
        named.query("SELECT conversation_id AS cid, COUNT(*) AS n FROM message WHERE conversation_id IN (:ids) "
                        + "GROUP BY conversation_id", new MapSqlParameterSource("ids", conversationIds), rs -> {
                    out.put(rs.getLong("cid"), rs.getLong("n"));
                });
        return out;
    }

    private Map<Long, Row> lastRows(List<Long> messageIds) {
        Map<Long, Row> out = new HashMap<>();
        if (messageIds.isEmpty()) {
            return out;
        }
        named.query(MESSAGE_SELECT + " WHERE m.id IN (:ids)", new MapSqlParameterSource("ids", messageIds), rs -> {
            Row r = row(rs);
            out.put(r.id(), r);
        });
        return out;
    }

    /** Konusma ozetleri: baslik (birebirde katilimci adlari), aktif uye sayisi, TUM uyeler (ayrilmislar dahil). */
    Map<Long, Brief> briefs(Collection<Long> conversationIds) {
        Map<Long, Brief> out = new HashMap<>();
        if (conversationIds.isEmpty()) {
            return out;
        }
        Map<Long, String[]> convs = new LinkedHashMap<>();
        named.query("SELECT id, type, title FROM conversation WHERE id IN (:ids)",
                new MapSqlParameterSource("ids", conversationIds), rs -> {
                    convs.put(rs.getLong("id"), new String[] {rs.getString("type"), rs.getString("title")});
                });
        Map<Long, List<MemberView>> members = new HashMap<>();
        named.query("SELECT cm.conversation_id AS cid, cm.role, cm.joined_at, cm.left_at, u.id, u.display_name, "
                        + "u.avatar_url, u.email FROM conversation_member cm JOIN app_user u ON u.id = cm.user_id "
                        + "WHERE cm.conversation_id IN (:ids) ORDER BY cm.id",
                new MapSqlParameterSource("ids", conversationIds), rs -> {
                    members.computeIfAbsent(rs.getLong("cid"), k -> new ArrayList<>()).add(new MemberView(
                            new PersonView(rs.getLong("id"), rs.getString("display_name"), rs.getString("avatar_url"),
                                    rs.getString("email")), rs.getString("role"),
                            str(instant(rs.getTimestamp("joined_at"))), str(instant(rs.getTimestamp("left_at")))));
                });
        convs.forEach((id, c) -> {
            List<MemberView> ms = members.getOrDefault(id, List.of());
            String title = c[1];
            if (title == null || title.isBlank()) {
                title = String.join(" · ", ms.stream().map(m -> m.person().displayName() == null ? "?"
                        : m.person().displayName()).toList());
            }
            out.put(id, new Brief(id, c[0], title, (int) ms.stream().filter(m -> m.leftAt() == null).count(), ms));
        });
        return out;
    }

    private Map<Long, List<ReactionView>> reactions(List<Long> messageIds) {
        Map<Long, List<ReactionView>> out = new HashMap<>();
        if (messageIds.isEmpty()) {
            return out;
        }
        named.query("SELECT message_id, user_id, emoji FROM message_reaction WHERE message_id IN (:ids) ORDER BY id",
                new MapSqlParameterSource("ids", messageIds), rs -> {
                    out.computeIfAbsent(rs.getLong("message_id"), k -> new ArrayList<>())
                            .add(new ReactionView(rs.getString("emoji"), rs.getLong("user_id")));
                });
        return out;
    }

    /** Konusma basina {userId, lastRead, lastDelivered} (ayrilmis uyeler dahil: makbuz kayitlari kalir). */
    private Map<Long, List<long[]>> receipts(Collection<Long> conversationIds) {
        Map<Long, List<long[]>> out = new HashMap<>();
        if (conversationIds.isEmpty()) {
            return out;
        }
        named.query("SELECT conversation_id, user_id, last_read_message_id, last_delivered_message_id "
                        + "FROM conversation_member WHERE conversation_id IN (:ids)",
                new MapSqlParameterSource("ids", conversationIds), rs -> {
                    out.computeIfAbsent(rs.getLong("conversation_id"), k -> new ArrayList<>()).add(new long[] {
                            rs.getLong("user_id"), rs.getLong("last_read_message_id"),
                            rs.getLong("last_delivered_message_id")});
                });
        return out;
    }

    /** Golge engel: mesajin bastirilma nedeni olan engelleyen taraf (birebirde iki yonden biri). */
    private Map<Long, PersonView> blockers(List<Row> rows) {
        Map<Long, PersonView> out = new HashMap<>();
        Set<Long> convIds = new LinkedHashSet<>();
        rows.stream().filter(Row::suppressed).forEach(r -> convIds.add(r.conversationId()));
        Map<Long, List<Long>> pair = new HashMap<>();
        named.query("SELECT conversation_id, user_id FROM conversation_member WHERE conversation_id IN (:ids)",
                new MapSqlParameterSource("ids", convIds), rs -> {
                    pair.computeIfAbsent(rs.getLong("conversation_id"), k -> new ArrayList<>()).add(rs.getLong("user_id"));
                });
        Set<Long> users = new HashSet<>();
        pair.values().forEach(users::addAll);
        // blocker -> blocked ciftleri (yalniz ilgili kullanicilar arasinda)
        List<long[]> blocks = new ArrayList<>();
        if (!users.isEmpty()) {
            named.query("SELECT blocker_id, blocked_id FROM user_block WHERE blocker_id IN (:u) AND blocked_id IN (:u)",
                    new MapSqlParameterSource("u", users), rs -> {
                        blocks.add(new long[] {rs.getLong("blocker_id"), rs.getLong("blocked_id")});
                    });
        }
        Map<Long, PersonView> people = people(users);
        for (Row r : rows) {
            if (!r.suppressed()) {
                continue;
            }
            List<Long> members = pair.getOrDefault(r.conversationId(), List.of());
            for (long[] b : blocks) {
                // gonderen engellenmis ya da gondereni engellemis: engelleyen taraf gosterilir
                if (members.contains(b[0]) && members.contains(b[1]) && (b[0] == r.senderId() || b[1] == r.senderId())) {
                    out.put(r.id(), people.get(b[0]));
                    break;
                }
            }
        }
        return out;
    }

    /** Ekler: viewOnce/purged/viewedBy dahil; gizli ya da silinmis mesajin eki de listelenir. */
    Map<Long, List<AttachmentView>> attachments(List<Long> messageIds) {
        Map<Long, List<AttachmentView>> out = new HashMap<>();
        if (messageIds.isEmpty()) {
            return out;
        }
        List<Object[]> rows = new ArrayList<>();
        named.query("SELECT a.id, a.message_id, a.kind, a.content_type, a.width, a.height, a.duration_ms, a.bytes, "
                        + "a.view_once, a.purged_at, a.hidden_at, m.deleted_at FROM message_attachment a "
                        + "LEFT JOIN message m ON m.id = a.message_id WHERE a.message_id IN (:ids) ORDER BY a.id",
                new MapSqlParameterSource("ids", messageIds), rs -> {
                    int d = rs.getInt("duration_ms");
                    rows.add(new Object[] {rs.getLong("id"), rs.getLong("message_id"), rs.getString("kind"),
                            rs.getString("content_type"), rs.getInt("width"), rs.getInt("height"),
                            null, d, rs.getLong("bytes"), rs.getBoolean("view_once"),
                            rs.getTimestamp("purged_at") != null, rs.getTimestamp("hidden_at") != null,
                            rs.getTimestamp("deleted_at") != null});
                });
        List<Long> once = rows.stream().filter(r -> (Boolean) r[9]).map(r -> (Long) r[0]).toList();
        Map<Long, List<ViewerView>> viewers = viewedBy(once);
        for (Object[] r : rows) {
            long id = (Long) r[0];
            boolean purged = (Boolean) r[10];
            String base = "/api/admin/media/attachments/" + id + "/preview";
            out.computeIfAbsent((Long) r[1], k -> new ArrayList<>()).add(new AttachmentView(id, (String) r[2],
                    (String) r[3], (Integer) r[4], (Integer) r[5], videoDuration((String) r[2], (Integer) r[7]),
                    (Long) r[8], (Boolean) r[9], viewers.getOrDefault(id, List.of()), purged, (Boolean) r[11],
                    (Boolean) r[12], purged ? null : base, purged ? null : base + "?thumb=true"));
        }
        return out;
    }

    static Integer videoDuration(String kind, int durationMs) {
        return "VIDEO".equals(kind) && durationMs > 0 ? durationMs : null;
    }

    /** Tek gosterimlik eki acanlar (kullanici + zaman), tek sorgu. */
    Map<Long, List<ViewerView>> viewedBy(Collection<Long> attachmentIds) {
        Map<Long, List<ViewerView>> out = new HashMap<>();
        if (attachmentIds.isEmpty()) {
            return out;
        }
        named.query("SELECT v.attachment_id, v.user_id, v.viewed_at, u.display_name FROM message_attachment_view v "
                        + "LEFT JOIN app_user u ON u.id = v.user_id WHERE v.attachment_id IN (:ids) ORDER BY v.viewed_at",
                new MapSqlParameterSource("ids", attachmentIds), rs -> {
                    out.computeIfAbsent(rs.getLong("attachment_id"), k -> new ArrayList<>()).add(new ViewerView(
                            rs.getLong("user_id"), rs.getString("display_name"), str(instant(rs.getTimestamp("viewed_at")))));
                });
        return out;
    }

    /** Duzenlenen mesajlarin onceki surumleri (eskiden yeniye), cozulmus. */
    private Map<Long, List<RevisionView>> revisions(List<Row> rows) {
        Map<Long, List<RevisionView>> out = new HashMap<>();
        Map<Long, Row> edited = new HashMap<>();
        rows.stream().filter(r -> r.editedAt() != null).forEach(r -> edited.put(r.id(), r));
        if (edited.isEmpty()) {
            return out;
        }
        named.query("SELECT message_id, body_ciphertext, body_nonce, key_version, revised_at FROM message_revision "
                        + "WHERE message_id IN (:ids) ORDER BY id", new MapSqlParameterSource("ids", edited.keySet()),
                rs -> {
                    Row r = edited.get(rs.getLong("message_id"));
                    Plain p = crypto.open(r.conversationId(), MessageCodec.context(r.senderId(), r.clientId()),
                            new Sealed(rs.getBytes("body_ciphertext"), rs.getBytes("body_nonce"), rs.getInt("key_version")));
                    out.computeIfAbsent(r.id(), k -> new ArrayList<>())
                            .add(new RevisionView(p.text(), p.error(), str(instant(rs.getTimestamp("revised_at")))));
                });
        return out;
    }

    /** Yanit onizlemesi: yalnizca AYNI konusmanin ust mesaji (baska konusma sizdirilmaz). */
    private Map<Long, ReplyView> replies(List<Row> rows) {
        Map<Long, ReplyView> out = new HashMap<>();
        Set<Long> parentIds = new HashSet<>();
        rows.forEach(r -> {
            if (r.replyTo() != null) {
                parentIds.add(r.replyTo());
            }
        });
        if (parentIds.isEmpty()) {
            return out;
        }
        Map<Long, Row> parents = lastRows(new ArrayList<>(parentIds));
        for (Row r : rows) {
            if (r.replyTo() == null) {
                continue;
            }
            Row p = parents.get(r.replyTo());
            if (p == null || p.conversationId() != r.conversationId()) {
                out.put(r.id(), new ReplyView(r.replyTo(), null, null, "NOT_FOUND", false));
                continue;
            }
            Plain pl = crypto.open(p.conversationId(), MessageCodec.context(p.senderId(), p.clientId()), p.sealed());
            out.put(r.id(), new ReplyView(p.id(), p.senderId(), truncate(pl.text()), pl.error(), p.deletedAt() != null));
        }
        return out;
    }

    static String truncate(String s) {
        if (s == null || s.codePointCount(0, s.length()) <= PREVIEW_LENGTH) {
            return s;
        }
        return s.substring(0, s.offsetByCodePoints(0, PREVIEW_LENGTH)) + "…";
    }

    static String str(Instant t) {
        return t == null ? null : t.toString();
    }

    static Instant instant(Timestamp t) {
        return t == null ? null : t.toInstant();
    }
}
