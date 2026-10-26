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
import java.util.HashMap;
import java.util.HashSet;
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
 * Yonetici kullanici-bazli sohbet goruntuleyicisi (T24). Salt okunur; sayfa istegi basina sunucu toplu cozer,
 * her sayfa icin degistirilemez denetim kaydi YAZILDIKTAN SONRA icerik doner (yazilamazsa icerik donmez).
 * Silinmis (tombstone) ve moderasyonla gizlenmis mesajlar da cozulmus gosterilir; kullanici API'sindeki kapali
 * erisim burada gecerli degildir. Erisim kapsami hedef kullanicinin UYELIGIYLE sinirlidir (IDOR): uye olmadigi
 * konusma 404; grupta yalnizca uyelik suresi (katilma..ayrilma) icindeki mesajlar.
 */
@Service
public class AdminChatViewerService {

    public static final int MAX_CONVERSATIONS = 30;
    public static final int MAX_MESSAGES = 50;
    static final int PREVIEW_LENGTH = 100;

    public record PersonView(Long id, String displayName, String avatarUrl) {}

    public record LastMessage(long id, long senderId, boolean mine, String text, String error, boolean deleted,
                              boolean hidden, String createdAt) {}

    public record ConversationItem(long id, String type, String title, PersonView peer, int memberCount,
                                   long totalMessages, String lastActivityAt, boolean left, LastMessage lastMessage) {}

    public record ConversationPage(PersonView user, List<ConversationItem> items, Long nextCursor) {}

    public record ReplyView(long id, Long senderId, String text, String error, boolean deleted) {}

    public record ReactionView(String emoji, long userId) {}

    public record RevisionView(String text, String error, String revisedAt) {}

    /** Mesaj eki (T8 ile uyumlu bicim); ek yoksa liste bos. previewUrl yonetici onizleme ucuna isaret eder. */
    public record AttachmentView(String id, String kind, String mime, long size, String previewUrl) {}

    public record MessageItem(long id, long senderId, String senderName, boolean mine, String createdAt, String text,
                              String error, boolean edited, String editedAt, List<RevisionView> revisions,
                              boolean deleted, String deletedAt, Long deletedBy, String deletedByName, boolean hidden,
                              ReplyView replyTo, List<ReactionView> reactions, List<AttachmentView> attachments) {}

    public record ConversationInfo(long id, String type, String title, PersonView peer, boolean left) {}

    /** items: eskiden yeniye. nextBefore: bir sonraki (daha eski) sayfa icin imlec; yoksa null. */
    public record MessagePage(PersonView user, ConversationInfo conversation, List<MessageItem> items, Long nextBefore) {}

    private record Membership(long conversationId, String type, String title, Instant joinedAt, Instant leftAt) {
        boolean group() {
            return "GROUP".equals(type);
        }
    }

    private record Row(long id, long senderId, String clientId, Instant createdAt, Sealed sealed, Long replyTo,
                       Instant editedAt, Instant deletedAt, Long deletedBy, boolean hidden) {}

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
        PersonView user = person(userId);
        if (user == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        int s = Math.min(Math.max(size, 1), MAX_CONVERSATIONS);
        List<Object> args = new ArrayList<>();
        args.add(userId);
        String sql = "SELECT c.id, c.type, c.title, c.last_message_id, c.last_message_at, cm.joined_at, cm.left_at "
                + "FROM conversation_member cm JOIN conversation c ON c.id = cm.conversation_id "
                + "WHERE cm.user_id = ? AND c.last_message_id IS NOT NULL";
        if (cursor != null) {
            sql += " AND c.last_message_id < ?";
            args.add(cursor);
        }
        sql += " ORDER BY c.last_message_id DESC LIMIT ?";
        args.add(s + 1);
        List<Object[]> rows = jdbc.query(sql, (rs, i) -> new Object[] {rs.getLong("id"), rs.getString("type"),
                rs.getString("title"), rs.getLong("last_message_id"), instant(rs.getTimestamp("last_message_at")),
                new Membership(rs.getLong("id"), rs.getString("type"), rs.getString("title"),
                        instant(rs.getTimestamp("joined_at")), instant(rs.getTimestamp("left_at")))}, args.toArray());
        boolean more = rows.size() > s;
        List<Object[]> page = more ? rows.subList(0, s) : rows;
        Long next = more ? (Long) page.get(page.size() - 1)[3] : null;

        List<Long> ids = page.stream().map(r -> (Long) r[0]).toList();
        Map<Long, PersonView> peers = peers(ids, userId);
        Map<Long, Integer> memberCounts = memberCounts(ids);

        List<ConversationItem> items = new ArrayList<>();
        List<Entry> audit = new ArrayList<>();
        for (Object[] r : page) {
            long cid = (Long) r[0];
            Membership m = (Membership) r[5];
            Window w = window(m);
            long total = jdbc.queryForObject("SELECT COUNT(*) FROM message m WHERE m.conversation_id = ?" + w.sql,
                    Long.class, w.args(cid));
            List<Row> last = jdbc.query(MESSAGE_SELECT + " WHERE m.conversation_id = ?" + w.sql
                    + " ORDER BY m.id DESC LIMIT 1", (rs, i) -> row(rs), w.args(cid));
            LastMessage preview = null;
            if (!last.isEmpty()) {
                Row l = last.get(0);
                Plain p = crypto.open(cid, MessageCodec.context(l.senderId(), l.clientId()), l.sealed());
                preview = new LastMessage(l.id(), l.senderId(), l.senderId() == userId, truncate(p.text()), p.error(),
                        l.deletedAt() != null, l.hidden(), l.createdAt().toString());
                audit.add(new Entry(adminId, userId, cid, 1, l.id(), l.id(), AdminDecryptService.SYSTEM_REASON, ip,
                        "LIST_PREVIEW"));
            }
            items.add(new ConversationItem(cid, m.type(), m.title(), m.group() ? null : peers.get(cid),
                    memberCounts.getOrDefault(cid, 0), total, r[4] == null ? null : r[4].toString(),
                    m.leftAt() != null, preview));
        }
        crypto.record(audit, ip); // once denetim, sonra icerik
        return new ConversationPage(user, items, next);
    }

    // --- mesajlar ---

    public MessagePage messages(long adminId, long userId, long conversationId, Long before, int size, String ip) {
        crypto.requireEnabled();
        PersonView user = person(userId);
        if (user == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        Membership m = jdbc.query("SELECT c.id, c.type, c.title, cm.joined_at, cm.left_at FROM conversation_member cm "
                        + "JOIN conversation c ON c.id = cm.conversation_id WHERE cm.user_id = ? AND c.id = ?",
                (rs, i) -> new Membership(rs.getLong("id"), rs.getString("type"), rs.getString("title"),
                        instant(rs.getTimestamp("joined_at")), instant(rs.getTimestamp("left_at"))),
                userId, conversationId).stream().findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı."));
        int s = Math.min(Math.max(size, 1), MAX_MESSAGES);
        Window w = window(m);
        List<Object> args = new ArrayList<>(List.of(conversationId));
        args.addAll(w.params);
        String sql = MESSAGE_SELECT + " WHERE m.conversation_id = ?" + w.sql;
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

        List<Long> ids = rows.stream().map(Row::id).toList();
        Map<Long, List<ReactionView>> reactions = reactions(ids);
        Map<Long, List<RevisionView>> revisions = revisions(conversationId, rows);
        Map<Long, ReplyView> replies = replies(conversationId, rows);
        Set<Long> userIds = new LinkedHashSet<>();
        rows.forEach(r -> {
            userIds.add(r.senderId());
            if (r.deletedBy() != null) {
                userIds.add(r.deletedBy());
            }
        });
        Map<Long, String> names = names(userIds);

        List<MessageItem> items = new ArrayList<>();
        int decrypted = 0;
        for (Row r : rows) {
            Plain p = crypto.open(conversationId, MessageCodec.context(r.senderId(), r.clientId()), r.sealed());
            List<RevisionView> revs = revisions.getOrDefault(r.id(), List.of());
            decrypted += 1 + revs.size();
            items.add(new MessageItem(r.id(), r.senderId(), names.get(r.senderId()), r.senderId() == userId,
                    r.createdAt().toString(), p.text(), p.error(), r.editedAt() != null,
                    r.editedAt() == null ? null : r.editedAt().toString(), revs, r.deletedAt() != null,
                    r.deletedAt() == null ? null : r.deletedAt().toString(), r.deletedBy(),
                    r.deletedBy() == null ? null : names.get(r.deletedBy()), r.hidden(),
                    replies.get(r.id()), reactions.getOrDefault(r.id(), List.of()), List.of()));
        }
        Long from = ids.isEmpty() ? null : ids.get(0);
        Long to = ids.isEmpty() ? null : ids.get(ids.size() - 1);
        crypto.record(List.of(new Entry(adminId, userId, conversationId, decrypted, from, to,
                AdminDecryptService.SYSTEM_REASON, ip, "VIEW_MESSAGES")), ip); // once denetim, sonra icerik

        PersonView peer = m.group() ? null : peers(List.of(conversationId), userId).get(conversationId);
        return new MessagePage(user, new ConversationInfo(conversationId, m.type(), m.title(), peer, m.leftAt() != null),
                items, nextBefore);
    }

    // --- yardimcilar ---

    private static final String MESSAGE_SELECT = "SELECT m.id, m.sender_id, m.client_id, m.created_at, m.body_ciphertext, "
            + "m.body_nonce, m.key_version, m.reply_to_message_id, m.edited_at, m.deleted_at, m.deleted_by, m.hidden_at "
            + "FROM message m";

    private static Row row(java.sql.ResultSet rs) throws java.sql.SQLException {
        byte[] ct = rs.getBytes("body_ciphertext");
        byte[] nonce = rs.getBytes("body_nonce");
        Sealed sealed = ct == null || nonce == null ? null : new Sealed(ct, nonce, rs.getInt("key_version"));
        long replyTo = rs.getLong("reply_to_message_id");
        boolean replyNull = rs.wasNull();
        long deletedBy = rs.getLong("deleted_by");
        boolean deletedByNull = rs.wasNull();
        return new Row(rs.getLong("id"), rs.getLong("sender_id"), rs.getString("client_id"),
                instant(rs.getTimestamp("created_at")), sealed, replyNull ? null : replyTo,
                instant(rs.getTimestamp("edited_at")), instant(rs.getTimestamp("deleted_at")),
                deletedByNull ? null : deletedBy, rs.getTimestamp("hidden_at") != null);
    }

    /** Uyelik penceresi: grupta katilma..ayrilma; birebirde kisit yok. */
    private record Window(String sql, List<Object> params) {
        Object[] args(long conversationId) {
            List<Object> a = new ArrayList<>();
            a.add(conversationId);
            a.addAll(params);
            return a.toArray();
        }
    }

    private static Window window(Membership m) {
        if (!m.group()) {
            return new Window("", List.of());
        }
        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();
        if (m.joinedAt() != null) {
            sql.append(" AND m.created_at >= ?");
            params.add(Timestamp.from(m.joinedAt()));
        }
        if (m.leftAt() != null) {
            sql.append(" AND m.created_at <= ?");
            params.add(Timestamp.from(m.leftAt()));
        }
        return new Window(sql.toString(), params);
    }

    private PersonView person(long userId) {
        return jdbc.query("SELECT id, display_name, avatar_url FROM app_user WHERE id = ?",
                (rs, i) -> new PersonView(rs.getLong("id"), rs.getString("display_name"), rs.getString("avatar_url")),
                userId).stream().findFirst().orElse(null);
    }

    private Map<Long, PersonView> peers(List<Long> conversationIds, long userId) {
        Map<Long, PersonView> out = new HashMap<>();
        if (conversationIds.isEmpty()) {
            return out;
        }
        named.query("SELECT cm.conversation_id AS cid, u.id, u.display_name, u.avatar_url FROM conversation_member cm "
                        + "JOIN app_user u ON u.id = cm.user_id JOIN conversation c ON c.id = cm.conversation_id "
                        + "WHERE cm.conversation_id IN (:ids) AND cm.user_id <> :uid AND c.type = 'DIRECT' ORDER BY cm.id",
                new MapSqlParameterSource("ids", conversationIds).addValue("uid", userId), rs -> {
                    out.putIfAbsent(rs.getLong("cid"),
                            new PersonView(rs.getLong("id"), rs.getString("display_name"), rs.getString("avatar_url")));
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

    private Map<Long, String> names(Set<Long> ids) {
        Map<Long, String> out = new HashMap<>();
        if (ids.isEmpty()) {
            return out;
        }
        named.query("SELECT id, display_name FROM app_user WHERE id IN (:ids)", new MapSqlParameterSource("ids", ids),
                rs -> {
                    out.put(rs.getLong("id"), rs.getString("display_name"));
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

    /** Duzenlenen mesajlarin onceki surumleri (eskiden yeniye), cozulmus. */
    private Map<Long, List<RevisionView>> revisions(long conversationId, List<Row> rows) {
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
                    Plain p = crypto.open(conversationId, MessageCodec.context(r.senderId(), r.clientId()),
                            new Sealed(rs.getBytes("body_ciphertext"), rs.getBytes("body_nonce"), rs.getInt("key_version")));
                    out.computeIfAbsent(r.id(), k -> new ArrayList<>())
                            .add(new RevisionView(p.text(), p.error(), instant(rs.getTimestamp("revised_at")).toString()));
                });
        return out;
    }

    /** Yanit onizlemesi: yalnizca AYNI konusmanin ust mesaji (baska konusma sizdirilmaz). */
    private Map<Long, ReplyView> replies(long conversationId, List<Row> rows) {
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
        Map<Long, Row> parents = new HashMap<>();
        named.query(MESSAGE_SELECT + " WHERE m.conversation_id = :cid AND m.id IN (:ids)",
                new MapSqlParameterSource("cid", conversationId).addValue("ids", parentIds), rs -> {
                    Row p = row(rs);
                    parents.put(p.id(), p);
                });
        for (Row r : rows) {
            if (r.replyTo() == null) {
                continue;
            }
            Row p = parents.get(r.replyTo());
            if (p == null) {
                out.put(r.id(), new ReplyView(r.replyTo(), null, null, "NOT_FOUND", false));
                continue;
            }
            Plain pl = crypto.open(conversationId, MessageCodec.context(p.senderId(), p.clientId()), p.sealed());
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

    private static Instant instant(Timestamp t) {
        return t == null ? null : t.toInstant();
    }
}
