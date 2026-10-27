package edu.bingol.backend.community.extras;

import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnnouncementView;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kulup duyurulari: MANAGE_POSTS yetkilisi yazar, tum ACTIVE uyelere (engel iliskisi haric) alicinin dilinde bildirim
 * gider. Kulup basina gunde en fazla {@value #DAILY_LIMIT} duyuru (silinenler dahil sayilir).
 */
@Service
public class ClubAnnouncementService {

    static final int DAILY_LIMIT = 3;
    /** Tek duyuruda en fazla bu kadar uyeye bildirim (istegi sonsuza uzatmamak icin; sonrakiler akistan gorur). */
    static final int NOTIFY_MAX = 5000;
    private static final int PAGE = 500;

    private final CommunityService communities;
    private final CommunityRepository communityRepo;
    private final ClubAnnouncementRepository announcements;
    private final ClubMemberQueryRepository memberQuery;
    private final ClubPermissions permissions;
    private final ClubAuditService audit;
    private final BlockService blocks;
    private final NotificationService notifications;

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public ClubAnnouncementService(CommunityService communities, CommunityRepository communityRepo,
                                   ClubAnnouncementRepository announcements, ClubMemberQueryRepository memberQuery,
                                   ClubPermissions permissions, ClubAuditService audit, BlockService blocks,
                                   NotificationService notifications) {
        this.communities = communities;
        this.communityRepo = communityRepo;
        this.announcements = announcements;
        this.memberQuery = memberQuery;
        this.permissions = permissions;
        this.audit = audit;
        this.blocks = blocks;
        this.notifications = notifications;
    }

    @Transactional
    public AnnouncementView create(Actor a, Long cid, String rawText) {
        Community c = communities.load(cid);
        permissions.require(a, cid, ClubPermission.MANAGE_POSTS);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        String text = rawText == null ? "" : rawText.trim();
        if (text.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Duyuru metni boş olamaz.");
        }
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "text", a.id(), text);
        communityRepo.lockById(cid); // say-sonra-ekle yarisi: es zamanli duyurular siraya girer
        if (announcements.countSince(cid, Instant.now().minus(Duration.ofHours(24))) >= DAILY_LIMIT) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "CLUB_ANNOUNCEMENT_LIMIT",
                    "Bir kulüp günde en fazla " + DAILY_LIMIT + " duyuru yapabilir.", String.valueOf(DAILY_LIMIT));
        }
        CommunityPost p = new CommunityPost();
        p.setCommunityId(cid);
        p.setAuthorId(a.id());
        p.setContent(text);
        p.setAnnouncement(true);
        announcements.save(p);
        audit.record(cid, a.id(), null, ClubAuditService.ANNOUNCEMENT_POSTED, "post=" + p.getId());

        Map<Long, User> authors = communities.usersById(List.of(a.id()));
        User author = authors.get(a.id());
        notifyMembers(c, p, a.id());
        return new AnnouncementView(p.getId(), cid, a.id(), author == null ? "Kullanıcı" : author.getDisplayName(),
                p.getContent(), p.getCreatedAt());
    }

    /** Duyuru akisi: PRIVATE kulupte yalnizca uyeler okur; engellenen yazarlar listelenmez. */
    @Transactional(readOnly = true)
    public CursorPage<AnnouncementView> list(Actor a, Long cid, Long cursor, int size) {
        Community c = communities.loadVisible(a, cid);
        communities.requireReadable(a, c);
        int s = CursorPage.clampSize(size);
        Set<Long> excluded = communities.blockedFor(a);
        List<CommunityPost> rows = announcements.page(cid, Paging.descStart(cursor), excluded, PageRequest.of(0, s + 1));
        return Paging.map(rows, s, CommunityPost::getId, items -> {
            Map<Long, User> authors = communities.usersById(items.stream().map(CommunityPost::getAuthorId).toList());
            return items.stream().map(p -> {
                User u = authors.get(p.getAuthorId());
                return new AnnouncementView(p.getId(), p.getCommunityId(), p.getAuthorId(),
                        u == null ? "Kullanıcı" : u.getDisplayName(), p.getContent(), p.getCreatedAt());
            }).toList();
        });
    }

    /** Servis sozlesmesi: bildirim hatasi duyuruyu bozmaz (NotificationService zaten exception sizdirmaz). */
    private void notifyMembers(Community c, CommunityPost p, Long authorId) {
        Set<Long> hidden = blocks.hiddenFrom(authorId);
        String preview = preview(p.getContent());
        Map<String, String> data = Map.of("communityId", c.getId().toString(), "postId", p.getId().toString(),
                "kind", "announcement");
        long after = 0;
        int sent = 0;
        while (sent < NOTIFY_MAX) {
            List<Long> page = memberQuery.activeUserIdsAfter(c.getId(), after, PageRequest.of(0, PAGE));
            for (Long uid : page) {
                if (uid.equals(authorId) || hidden.contains(uid)) {
                    continue;
                }
                notifications.sendTemplated(uid, NotificationType.COMMUNITY, "notif.community.announcement", data,
                        c.getName(), preview);
                sent++;
            }
            if (page.size() < PAGE) {
                return;
            }
            after = page.get(page.size() - 1);
        }
    }

    static String preview(String s) {
        return s.length() <= 120 ? s : s.substring(0, 119) + "…";
    }
}
