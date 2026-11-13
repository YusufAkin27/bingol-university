package edu.bingol.backend.messaging.room.notice;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import edu.bingol.backend.messaging.room.RoomModeration;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.notification.FanoutNotifier;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Oda duyuru panosu. Yetki: yalniz oda moderatoru ({@link RoomModeration}: bolum odasi = ADMIN FULL/MODERATOR,
 * kulup = kulup yetkilisi, etkinlik = etkinlik sahibi/yetkilisi) yazar/duzenler/siler/sabitler; okuma = aktif oda uyesi
 * (ya da moderator). Gorulme sayisi yalniz yetkiliye doner; kimlik listesi HICBIR uctan verilmez (gizlilik).
 */
@Service
public class RoomNoticeService {

    public static final int MAX_PINNED = 3;
    static final int TITLE_MAX = 80;
    static final int BODY_MAX = 600;
    static final int CHUNK = 250;

    static final NotificationTemplates.Template TEMPLATE = NotificationTemplates.register("notif.roomNotice",
            NotificationType.ANNOUNCEMENT, null);

    public record NoticeView(Long id, Long conversationId, String title, String body, boolean pinned, Long authorId,
                             String authorName, Instant createdAt, Instant updatedAt, boolean seenByMe, Integer seenCount) {}

    public record PinnedView(List<NoticeView> items, boolean canManage, long total) {}

    private final RoomNoticeRepository notices;
    private final RoomModeration moderation;
    private final ChatRoomLinkRepository links;
    private final ConversationMemberRepository members;
    private final UserRepository users;
    private final NotificationService notifications;
    private final ContentGuard guard;
    private final BlockService blocks;
    private FanoutNotifier fanout;

    public RoomNoticeService(RoomNoticeRepository notices, RoomModeration moderation, ChatRoomLinkRepository links,
                             ConversationMemberRepository members, UserRepository users,
                             NotificationService notifications, ContentGuard guard, BlockService blocks) {
        this.notices = notices;
        this.moderation = moderation;
        this.links = links;
        this.members = members;
        this.users = users;
        this.notifications = notifications;
        this.guard = guard;
        this.blocks = blocks;
    }

    @Autowired(required = false)
    void setFanout(FanoutNotifier fanout) {
        this.fanout = fanout;
    }

    // ---- yetki ----

    private void requireRoom(Long cid) {
        if (links.findByConversationId(cid).isEmpty()) {
            throw notFound();
        }
    }

    /** Okuma: aktif uye ya da moderator; degilse oda varligi sizmasin diye 404. Doner: yonetebilir mi. */
    private boolean requireReader(Long cid, Long uid) {
        requireRoom(cid);
        boolean manage = moderation.canModerate(cid, uid);
        if (!manage && members.findByConversationIdAndUserIdAndLeftAtIsNull(cid, uid).isEmpty()) {
            throw notFound();
        }
        return manage;
    }

    private void requireManager(Long cid, Long uid) {
        requireRoom(cid);
        if (!moderation.canModerate(cid, uid)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOTICE_FORBIDDEN", "Bu odada duyuru yönetme yetkiniz yok.");
        }
    }

    // ---- okuma ----

    @Transactional(readOnly = true)
    public PinnedView pinned(Long cid, Long uid) {
        boolean manage = requireReader(cid, uid);
        return new PinnedView(views(notices.pinned(cid, PageRequest.of(0, MAX_PINNED)), uid, manage), manage,
                notices.countLive(cid));
    }

    @Transactional(readOnly = true)
    public CursorPage<NoticeView> list(Long cid, Long uid, Long cursor, int size) {
        boolean manage = requireReader(cid, uid);
        int s = CursorPage.clampSize(size);
        List<RoomNotice> rows = notices.page(cid, cursor == null ? Long.MAX_VALUE : cursor, PageRequest.of(0, s + 1));
        boolean more = rows.size() > s;
        List<RoomNotice> page = more ? rows.subList(0, s) : rows;
        return new CursorPage<>(views(page, uid, manage), more ? page.get(page.size() - 1).getId() : null);
    }

    // ---- yazma ----

    @Transactional
    public NoticeView create(Long cid, Long uid, String title, String body, boolean pin) {
        requireManager(cid, uid);
        String t = clean(title, TITLE_MAX);
        String b = clean(body, BODY_MAX);
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "title", uid, t);
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "body", uid, b);
        if (pin) {
            requirePinRoom(cid, null);
        }
        RoomNotice n = new RoomNotice();
        n.setConversationId(cid);
        n.setAuthorId(uid);
        n.setTitle(t);
        n.setBody(b);
        n.setPinned(pin);
        notices.save(n);
        Long id = n.getId();
        FanoutNotifier.dispatch(fanout, "room-notice:" + cid, () -> notifyMembers(cid, uid, id, t));
        return views(List.of(n), uid, true).get(0);
    }

    @Transactional
    public NoticeView update(Long cid, Long uid, Long id, String title, String body, Boolean pin) {
        requireManager(cid, uid);
        RoomNotice n = load(cid, id);
        if (title != null) {
            n.setTitle(clean(title, TITLE_MAX));
            ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "title", uid, n.getTitle());
        }
        if (body != null) {
            n.setBody(clean(body, BODY_MAX));
            ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "body", uid, n.getBody());
        }
        if (pin != null && pin != n.isPinned()) {
            if (pin) {
                requirePinRoom(cid, n.getId());
            }
            n.setPinned(pin);
        }
        n.setUpdatedAt(Instant.now());
        notices.save(n);
        return views(List.of(n), uid, true).get(0);
    }

    @Transactional
    public void delete(Long cid, Long uid, Long id) {
        requireManager(cid, uid);
        RoomNotice n = load(cid, id);
        n.setDeletedAt(Instant.now());
        n.setPinned(false);
        notices.save(n);
    }

    /** Gorulme: idempotent; ayni kullanici ikinci kez sayilmaz, yazar kendi duyurusunu saymaz. */
    public void markSeen(Long cid, Long uid, Long id) {
        requireReader(cid, uid);
        RoomNotice n = load(cid, id);
        if (n.getAuthorId().equals(uid)) {
            return;
        }
        int added;
        try {
            added = notices.insertSeen(id, uid, Instant.now());
        } catch (org.springframework.dao.DataIntegrityViolationException race) {
            added = 0; // es zamanli ayni kayit: zaten sayilmis
        }
        if (added > 0) {
            notices.bumpSeen(id);
        }
    }

    // ---- ic ----

    private void requirePinRoom(Long cid, Long exceptId) {
        long cnt = notices.countPinned(cid);
        boolean already = exceptId != null && notices.findById(exceptId).map(RoomNotice::isPinned).orElse(false);
        if (cnt - (already ? 1 : 0) >= MAX_PINNED) {
            throw new ApiException(HttpStatus.CONFLICT, "NOTICE_PIN_LIMIT", "En fazla {0} duyuru sabitlenebilir.",
                    String.valueOf(MAX_PINNED));
        }
    }

    private RoomNotice load(Long cid, Long id) {
        return notices.findById(id).filter(n -> n.getConversationId().equals(cid) && n.isLive())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOTICE_NOT_FOUND", "Duyuru bulunamadı."));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CHAT_ROOM_NOT_FOUND", "Sohbet odası bulunamadı.");
    }

    private static String clean(String s, int max) {
        String v = s == null ? "" : s.trim();
        if (v.isEmpty() || v.length() > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz alan.");
        }
        return v;
    }

    private List<NoticeView> views(List<RoomNotice> rows, Long uid, boolean manage) {
        if (rows.isEmpty()) {
            return List.of();
        }
        Set<Long> seen = new HashSet<>(notices.seenAmong(uid, rows.stream().map(RoomNotice::getId).toList()));
        Map<Long, User> authors = new HashMap<>();
        users.findAllById(rows.stream().map(RoomNotice::getAuthorId).collect(Collectors.toSet()))
                .forEach(u -> authors.put(u.getId(), u));
        return rows.stream().map(n -> {
            User a = authors.get(n.getAuthorId());
            return new NoticeView(n.getId(), n.getConversationId(), n.getTitle(), n.getBody(), n.isPinned(),
                    n.getAuthorId(), a == null ? null : a.getDisplayName(), n.getCreatedAt(), n.getUpdatedAt(),
                    seen.contains(n.getId()) || n.getAuthorId().equals(uid), manage ? n.getSeenCount() : null);
        }).toList();
    }

    /** Aktif uyelere (yazar ve engel iliskisi olanlar haric) tercih/sessiz saat kurallariyla, 250'lik parcalarla. */
    void notifyMembers(Long cid, Long authorId, Long noticeId, String title) {
        String room = notices.conversationTitle(cid).orElse("");
        Set<Long> hidden = blocks.hiddenFrom(authorId);
        Map<String, String> data = Map.of("conversationId", cid.toString(), "noticeId", noticeId.toString(),
                "type", "ROOM_NOTICE");
        long after = 0;
        int total = 0;
        while (total < 50_000) {
            List<Long> ids = notices.memberIdsAfter(cid, after, PageRequest.of(0, CHUNK));
            if (ids.isEmpty()) {
                break;
            }
            after = ids.get(ids.size() - 1);
            total += ids.size();
            List<Long> to = ids.stream().filter(i -> !i.equals(authorId) && !hidden.contains(i)).toList();
            notifications.sendTemplatedBulk(to, TEMPLATE, data, "roomnotice:" + noticeId, room, title);
            if (ids.size() < CHUNK) {
                break;
            }
        }
    }
}
