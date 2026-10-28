package edu.bingol.backend.community;

import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.dto.CommunityDtos.CreatePostRequest;
import edu.bingol.backend.community.dto.CommunityDtos.PostView;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** Topluluk akisi: yalnizca aktif uyeler yazar; PRIVATE toplulukta yalnizca uyeler okur. */
@Service
public class CommunityPostService {

    static final int MAX_PINNED = 3;
    /** Yeni yazi bildirimi tek istekte en fazla bu kadar uyeye gider (istegi yavaslatmamak icin). */
    static final int NOTIFY_LIMIT = 500;
    static final String IMAGE_PREFIX = "/files/posts/";
    private static final Set<String> IMAGE_TYPES = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long IMAGE_MAX_BYTES = 3L * 1024 * 1024;

    private final CommunityService communities;
    private final CommunityPostRepository posts;
    private final CommunityMemberRepository members;
    private final BlockService blocks;
    private final NotificationService notifications;
    private final FileStorage storage;

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public CommunityPostService(CommunityService communities, CommunityPostRepository posts,
                                CommunityMemberRepository members, BlockService blocks,
                                NotificationService notifications, FileStorage storage) {
        this.communities = communities;
        this.posts = posts;
        this.members = members;
        this.blocks = blocks;
        this.notifications = notifications;
        this.storage = storage;
    }

    @Transactional
    public PostView create(Actor a, Long cid, CreatePostRequest r) {
        Community c = writableCommunity(a, cid);
        String image = Texts.blankToNull(r.imageUrl());
        if (image != null && !validImageUrl(image)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_IMAGE_URL", "Görsel yalnızca yüklenen dosyalardan olabilir.");
        }
        if (r.text().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Yazı boş olamaz.");
        }
        ContentGuard.clean(guard, Entity.POST, "text", a.id(), r.text());
        CommunityPost p = new CommunityPost();
        p.setCommunityId(cid);
        p.setAuthorId(a.id());
        p.setContent(r.text().trim());
        p.setImageUrl(image);
        posts.save(p);

        PostView view = views(List.of(p), a, communities.can(a, cid, ClubPermission.MANAGE_POSTS)).get(0);
        Set<Long> hidden = blocks.hiddenFrom(a.id());
        for (Long uid : members.userIdsByStatus(cid, CommunityMember.Status.ACTIVE, PageRequest.of(0, NOTIFY_LIMIT))) {
            if (uid.equals(a.id()) || hidden.contains(uid)) {
                continue;
            }
            // Alt tur COMMUNITY_POST (tercihle kapatilabilir) + kulup basina birlesme: okunmamis yazilar tek satir.
            notifications.send(uid, NotificationType.COMMUNITY, edu.bingol.backend.notification.NotificationSubtype.COMMUNITY_POST,
                    "commpost:" + cid, c.getName(), view.authorName() + ": " + preview(p.getContent()),
                    Map.of("communityId", cid.toString(), "postId", p.getId().toString()));
        }
        return view;
    }

    /** Ilk sayfada (cursor yok) sabitli yazilar basa eklenir. */
    @Transactional(readOnly = true)
    public CursorPage<PostView> feed(Actor a, Long cid, Long cursor, int size) {
        Community c = communities.loadVisible(a, cid);
        communities.requireReadable(a, c);
        boolean mod = communities.can(a, cid, ClubPermission.MANAGE_POSTS);
        Set<Long> excluded = communities.blockedFor(a);
        int s = CursorPage.clampSize(size);
        List<CommunityPost> rows = posts.feed(cid, Paging.descStart(cursor), excluded, PageRequest.of(0, s + 1));
        return Paging.map(rows, s, CommunityPost::getId, items -> {
            List<CommunityPost> all = new ArrayList<>();
            if (cursor == null) {
                all.addAll(posts.pinned(cid, excluded));
            }
            all.addAll(items);
            return views(all, a, mod);
        });
    }

    @Transactional
    public void delete(Actor a, Long cid, Long postId) {
        communities.load(cid);
        CommunityPost p = find(cid, postId);
        boolean mod = communities.can(a, cid, ClubPermission.MANAGE_POSTS);
        if (!p.getAuthorId().equals(a.id()) && !mod) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu yazıyı silemezsiniz.");
        }
        p.setDeleted(true);
        p.setPinned(false);
        posts.save(p);
        if (postMedia != null) {
            postMedia.release(List.of(p)); // KVKK: gorsel alandan kalkar, dosya diskten silinir
        }
    }

    /** Gorsel temizligi (testlerde yoksa atlanir). */
    private CommunityPostMedia postMedia;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPostMedia(CommunityPostMedia postMedia) {
        this.postMedia = postMedia;
    }

    @Transactional
    public void pin(Actor a, Long cid, Long postId, boolean pinned) {
        communities.load(cid);
        communities.require(a, cid, ClubPermission.MANAGE_POSTS);
        CommunityPost p = find(cid, postId);
        if (pinned && !p.isPinned() && posts.countByCommunityIdAndPinnedTrueAndDeletedFalse(cid) >= MAX_PINNED) {
            throw new ApiException(HttpStatus.CONFLICT, "PIN_LIMIT", "En fazla " + MAX_PINNED + " yazı sabitlenebilir.", String.valueOf(MAX_PINNED));
        }
        p.setPinned(pinned);
        posts.save(p);
    }

    /** Yazi gorseli yukler (yalnizca uyeler); donen URL yazi olustururken imageUrl olarak verilir. */
    public String uploadImage(Actor a, Long cid, MultipartFile file) {
        writableCommunity(a, cid);
        return storage.save("posts", file, IMAGE_TYPES, IMAGE_MAX_BYTES);
    }

    // ---- ic yardimcilar ----

    /** Yazma icin: topluluk ACTIVE olmali ve istek sahibi aktif uye olmali. */
    private Community writableCommunity(Actor a, Long cid) {
        Community c = communities.loadVisible(a, cid);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        if (communities.roleOf(cid, a.id()).isEmpty()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_MEMBER", "Yalnızca topluluk üyeleri paylaşım yapabilir.");
        }
        return c;
    }

    /** Yalnizca /files/posts/<dosya>: yol gezintisi (..), alt dizin, sorgu/parca ve kodlanmis ayiricilar reddedilir. */
    static boolean validImageUrl(String url) {
        return url.startsWith(IMAGE_PREFIX) && url.substring(IMAGE_PREFIX.length()).matches("[A-Za-z0-9][A-Za-z0-9._-]*")
                && !url.contains("..");
    }

    private CommunityPost find(Long cid, Long postId) {
        return posts.findByIdAndCommunityIdAndDeletedFalse(postId, cid)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı."));
    }

    private List<PostView> views(List<CommunityPost> list, Actor a, boolean mod) {
        Set<Long> hideAvatar = communities.blockedFor(a); // engel iliskisi olanin avatari gorunmez
        Map<Long, User> authors = communities.usersById(list.stream().map(CommunityPost::getAuthorId).toList());
        return list.stream().map(p -> {
            User u = authors.get(p.getAuthorId());
            return new PostView(p.getId(), p.getCommunityId(), p.getAuthorId(),
                    u == null ? "Kullanıcı" : u.getDisplayName(),
                    u == null || hideAvatar.contains(p.getAuthorId()) ? null : u.getAvatarUrl(),
                    p.getContent(), p.getImageUrl(), p.isPinned(), p.getCreatedAt(),
                    mod || p.getAuthorId().equals(a.id()));
        }).toList();
    }

    private static String preview(String s) {
        return s.length() <= 120 ? s : s.substring(0, 119) + "…";
    }
}
