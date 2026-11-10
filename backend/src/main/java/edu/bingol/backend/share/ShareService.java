package edu.bingol.backend.share;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.net.URI;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Paylasilan icerigin (gonderi, reel, haber/duyuru, etkinlik) gorunurluk karari ve onizleme verisi: TEK YER.
 * <ul>
 *   <li><b>Mesajla paylasim</b> ({@link #cards}, {@link #requireVisible}): goruntuleyen kullaniciya gore; gonderen
 *       gonderirken, alici/gonderen okurken ayri ayri hesaplanir (gizli hesap, engel, ozel kulup, silinme/gizleme).</li>
 *   <li><b>Herkese acik onizleme sayfasi</b> ({@link #publicView}): goruntuleyen YOK (anonim); yalniz herkese acik
 *       icerik: gizli olmayan haber/duyuru, aktif + herkese acik kulup (ya da kulupsuz) etkinlik, herkese acik hesabin
 *       silinmemis/gizlenmemis gonderisi.</li>
 * </ul>
 * Gorunmeyen icerik icin neden ayrimi YAPILMAZ (yok / gizli / engelli hepsi ayni "kullanilamaz" sonucu).
 */
@Service
public class ShareService {

    /** Gonderi metni, kart basligi icin ust siniri (sade gonderi zaten 60 karakter). */
    static final int TITLE_MAX = 140;
    static final int DESC_MAX = 200;

    private final NewsRepository news;
    private final PostRepository posts;
    private final PostMediaRepository postMedia;
    private final UserEventRepository events;
    private final CommunityRepository communities;
    private final CommunityMemberRepository communityMembers;
    private final UserRepository users;
    private final PrivateAccountGate gate;
    private final BlockService blocks;
    private final String baseUrl;

    public ShareService(NewsRepository news, PostRepository posts, PostMediaRepository postMedia,
                        UserEventRepository events, CommunityRepository communities,
                        CommunityMemberRepository communityMembers, UserRepository users, PrivateAccountGate gate,
                        BlockService blocks,
                        @Value("${app.share.base-url:${PUBLIC_WEB_URL:https://bukampus.com.tr}}") String baseUrl) {
        this.news = news;
        this.posts = posts;
        this.postMedia = postMedia;
        this.events = events;
        this.communities = communities;
        this.communityMembers = communityMembers;
        this.users = users;
        this.gate = gate;
        this.blocks = blocks;
        this.baseUrl = baseUrl == null ? "https://bukampus.com.tr" : baseUrl.replaceAll("/+$", "");
    }

    /** Cozulmus icerik (yalniz gorunur olanlar); alanlar tur bagimsiz. */
    public record Resolved(ShareRef ref, Long authorId, String title, String subtitle, String description,
                           String imageUrl, Long mediaId, String kind, Instant when, String place) {}

    // ------------------------------------------------------------------ baglanti

    public String baseUrl() {
        return baseUrl;
    }

    /** Herkese acik paylasim baglantisi: {@code https://bukampus.com.tr/s/{p|r|n|e}/{id}}. */
    public String link(ShareRef ref) {
        return baseUrl + "/s/" + ref.type().code() + "/" + ref.id();
    }

    // ------------------------------------------------------------------ mesajla paylasim

    /** Gonderen gonderirken: goremiyorsa 422 SHARE_TARGET_INVALID (icerigin varligi gonderen icin zaten gorunur). */
    @Transactional(readOnly = true)
    public ShareRef requireVisible(Long viewerId, String typeRaw, Long id) {
        ShareType type = ShareType.parse(typeRaw);
        if (type == null || id == null || id <= 0) {
            throw invalid();
        }
        ShareRef ref = new ShareRef(type, id);
        if (viewerId == null || !resolve(viewerId, List.of(ref)).containsKey(ref)) {
            throw invalid();
        }
        return ref;
    }

    public static ApiException invalid() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SHARE_TARGET_INVALID",
                "Bu içerik paylaşılamıyor.");
    }

    /** Sayfa basina toplu kart hesabi (goruntuleyene gore); gorunmeyenler `available=false`. */
    @Transactional(readOnly = true)
    public Map<ShareRef, ShareCard> cards(Long viewerId, Collection<ShareRef> refs) {
        Map<ShareRef, ShareCard> out = new HashMap<>();
        if (refs == null || refs.isEmpty()) {
            return out;
        }
        Set<ShareRef> distinct = new LinkedHashSet<>(refs);
        Map<ShareRef, Resolved> ok = resolve(viewerId, distinct);
        for (ShareRef r : distinct) {
            Resolved v = ok.get(r);
            out.put(r, v == null ? ShareCard.unavailable(r, link(r)) : card(v));
        }
        return out;
    }

    /**
     * Yayin (WebSocket) icin alici basina kart: once TEK anonim cozum; herkese acik ve alici yazarla engel iliskisinde
     * degilse ayni kart, aksi halde alici icin ayrica cozulur (gizli hesap/ozel kulup/engel nadirdir).
     */
    @Transactional(readOnly = true)
    public Map<Long, ShareCard> cardsForViewers(ShareRef ref, Collection<Long> viewerIds) {
        Map<Long, ShareCard> out = new HashMap<>();
        if (viewerIds == null || viewerIds.isEmpty()) {
            return out;
        }
        Resolved pub = resolve(null, List.of(ref)).get(ref);
        Set<Long> blockedWithAuthor = pub == null || pub.authorId() == null ? Set.of()
                : blocks.hiddenFrom(pub.authorId());
        for (Long vid : viewerIds) {
            if (pub != null && !blockedWithAuthor.contains(vid)) {
                out.put(vid, card(pub));
            } else {
                out.put(vid, cards(vid, List.of(ref)).get(ref));
            }
        }
        return out;
    }

    private ShareCard card(Resolved v) {
        return new ShareCard(v.ref().type().name(), v.ref().id(), true, v.title(), v.subtitle(), v.imageUrl(),
                v.kind(), link(v.ref()));
    }

    // ------------------------------------------------------------------ herkese acik sayfa

    /** Anonim (herkese acik) cozum; gorunmuyorsa bos. */
    @Transactional(readOnly = true)
    public Optional<Resolved> publicView(ShareRef ref) {
        return Optional.ofNullable(resolve(null, List.of(ref)).get(ref));
    }

    /** Kampus Forum konu/yorum cozumleyici (forum.share; yoksa forum turleri hic gorunmez). */
    private ForumShareResolver forumResolver;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setForumResolver(ForumShareResolver forumResolver) {
        this.forumResolver = forumResolver;
    }

    // ------------------------------------------------------------------ cozum

    /**
     * @param viewerId null = anonim (herkese acik kurallar); degilse o kullanicinin goruntuleme yetkisi
     * @return yalniz GORUNEN icerikler
     */
    Map<ShareRef, Resolved> resolve(Long viewerId, Collection<ShareRef> refs) {
        Map<ShareRef, Resolved> out = new LinkedHashMap<>();
        List<ShareRef> postRefs = new ArrayList<>();
        List<ShareRef> newsRefs = new ArrayList<>();
        List<ShareRef> eventRefs = new ArrayList<>();
        List<ShareRef> forumRefs = new ArrayList<>();
        List<ShareRef> userRefs = new ArrayList<>();
        for (ShareRef r : refs) {
            switch (r.type()) {
                case POST, REEL -> postRefs.add(r);
                case NEWS -> newsRefs.add(r);
                case EVENT -> eventRefs.add(r);
                case FORUM_TOPIC, FORUM_COMMENT -> forumRefs.add(r);
                case USER -> userRefs.add(r);
            }
        }
        if (!forumRefs.isEmpty() && forumResolver != null) {
            out.putAll(forumResolver.resolve(viewerId, forumRefs));
        }
        resolveNews(newsRefs, out);
        resolvePosts(viewerId, postRefs, out);
        resolveEvents(viewerId, eventRefs, out);
        resolveUsers(viewerId, userRefs, out);
        return out;
    }

    /** Avatar gorunurlugu (profil gizliligi; yoksa avatar hic gonderilmez). */
    private AvatarVisibility avatarVisibility;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAvatarVisibility(AvatarVisibility avatarVisibility) {
        this.avatarVisibility = avatarVisibility;
    }

    /**
     * Profil karti: YALNIZ giris yapmis goruntuleyene (anonim = hicbir sey; herkese acik sayfa zaten notrdur).
     * Gorunmez: yok/askida/silinmis hesap ve iki yonlu engel. Gizli hesap profil basligi (ad, kullanici adi, avatar)
     * zaten her uyeye gorunur; icerik kilidi profil ekraninda takip istegi akisiyla surer. Ad/@kullanici adi disinda
     * hicbir alan (e-posta, bolum, biyografi) karta girmez.
     */
    private void resolveUsers(Long viewerId, List<ShareRef> refs, Map<ShareRef, Resolved> out) {
        if (refs.isEmpty() || viewerId == null) {
            return;
        }
        Map<Long, User> byId = users.findAllById(ids(refs)).stream()
                .collect(Collectors.toMap(User::getId, u -> u, (a, b) -> a));
        Set<Long> related = blocks.hiddenFrom(viewerId);
        Set<Long> avatarOk = Set.of();
        if (avatarVisibility != null && !byId.isEmpty()) {
            try {
                avatarOk = avatarVisibility.visibleOwners(viewerId, byId.keySet(), AvatarVisibility.Field.AVATAR);
            } catch (RuntimeException e) {
                avatarOk = Set.of(); // karar verilemezse avatar gonderilmez
            }
        }
        for (ShareRef r : refs) {
            User u = byId.get(r.id());
            if (u == null || u.getStatus() != UserStatus.ACTIVE || u.getDisplayName() == null
                    || u.getDisplayName().isBlank()) {
                continue;
            }
            boolean self = viewerId.equals(u.getId());
            if (!self && related.contains(u.getId())) {
                continue;
            }
            String uname = u.getUsername() == null || u.getUsername().isBlank() ? null : "@" + u.getUsername().strip();
            String avatar = u.getAvatarUrl() != null && avatarOk.contains(u.getId()) ? eventImage(u.getAvatarUrl()) : null;
            out.put(r, new Resolved(r, u.getId(), clip(u.getDisplayName(), TITLE_MAX), uname, null, avatar, null,
                    null, null, null));
        }
    }

    private void resolveNews(List<ShareRef> refs, Map<ShareRef, Resolved> out) {
        if (refs.isEmpty()) {
            return;
        }
        Map<Long, NewsItem> byId = news.findAllById(ids(refs)).stream()
                .collect(Collectors.toMap(NewsItem::getId, n -> n, (a, b) -> a));
        for (ShareRef r : refs) {
            NewsItem n = byId.get(r.id());
            if (n == null || n.isHidden() || n.getTitle() == null || n.getTitle().isBlank()) {
                continue;
            }
            String desc = firstNonBlank(n.getSummary(), n.getContent());
            out.put(r, new Resolved(r, null, clip(n.getTitle(), TITLE_MAX), "Bingöl Üniversitesi",
                    desc == null ? null : clip(desc, DESC_MAX), safeBingolImage(n.getImageUrl()), null,
                    n.getType() == null ? null : n.getType().name(),
                    n.getPublishedDate() == null ? null
                            : n.getPublishedDate().atStartOfDay(java.time.ZoneId.of("Europe/Istanbul")).toInstant(),
                    null));
        }
    }

    private void resolvePosts(Long viewerId, List<ShareRef> refs, Map<ShareRef, Resolved> out) {
        if (refs.isEmpty()) {
            return;
        }
        Map<Long, Post> byId = posts.findAllById(ids(refs)).stream()
                .collect(Collectors.toMap(Post::getId, p -> p, (a, b) -> a));
        List<Post> visible = byId.values().stream().filter(Post::isVisible).toList();
        if (visible.isEmpty()) {
            return;
        }
        Set<Long> authorIds = visible.stream().map(Post::getAuthorId).collect(Collectors.toSet());
        Map<Long, User> authors = users.findAllById(authorIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u, (a, b) -> a));
        // gizli hesap: anonim hic gormez; kullanici yalniz sahibi ya da kabul edilmis takipci ise
        Set<Long> locked = viewerId == null ? gate.privateAmong(authorIds) : gate.lockedAmong(viewerId, authorIds);
        Set<Long> related = viewerId == null ? Set.of() : blocks.hiddenFrom(viewerId);
        Map<Long, PostMedia> firstMedia = new HashMap<>();
        postMedia.findByPostIdIn(visible.stream().map(Post::getId).toList()).stream()
                .filter(m -> !m.isHidden())
                .sorted(Comparator.comparing(PostMedia::getPostId).thenComparing(PostMedia::getPosition)
                        .thenComparing(PostMedia::getId))
                .forEach(m -> firstMedia.putIfAbsent(m.getPostId(), m));
        for (ShareRef r : refs) {
            Post p = byId.get(r.id());
            if (p == null || !p.isVisible()) {
                continue;
            }
            User a = authors.get(p.getAuthorId());
            boolean self = viewerId != null && viewerId.equals(p.getAuthorId());
            if (a == null || a.getStatus() != UserStatus.ACTIVE && !self) {
                continue;
            }
            if (!self && (locked.contains(p.getAuthorId()) || related.contains(p.getAuthorId()))) {
                continue;
            }
            PostMedia m = firstMedia.get(p.getId());
            String name = a.getDisplayName();
            String body = p.getBody() == null || p.getBody().isBlank() ? null : clip(p.getBody().strip(), TITLE_MAX);
            String image = m == null || m.getThumbKey() == null ? null : "/api/posts/media/" + m.getId() + "?thumb=true";
            out.put(r, new Resolved(r, p.getAuthorId(), body == null ? name : body, body == null ? null : name,
                    body, image, m == null || m.getThumbKey() == null ? null : m.getId(),
                    p.isVideo() ? "VIDEO" : "PHOTO", p.getCreatedAt(), null));
        }
    }

    private void resolveEvents(Long viewerId, List<ShareRef> refs, Map<ShareRef, Resolved> out) {
        if (refs.isEmpty()) {
            return;
        }
        Map<Long, UserEvent> byId = events.findAllById(ids(refs)).stream()
                .collect(Collectors.toMap(UserEvent::getId, e -> e, (a, b) -> a));
        Set<Long> clubIds = byId.values().stream().filter(e -> e.getStatus() == UserEvent.Status.ACTIVE)
                .map(UserEvent::getCommunityId).filter(java.util.Objects::nonNull).collect(Collectors.toSet());
        Map<Long, Community> clubs = clubIds.isEmpty() ? Map.of() : communities.findAllById(clubIds).stream()
                .collect(Collectors.toMap(Community::getId, c -> c, (a, b) -> a));
        for (ShareRef r : refs) {
            UserEvent e = byId.get(r.id());
            if (e == null || e.getStatus() != UserEvent.Status.ACTIVE) {
                continue;
            }
            String club = null;
            if (e.getCommunityId() != null) {
                Community c = clubs.get(e.getCommunityId());
                if (c == null || c.getStatus() != Community.Status.ACTIVE) {
                    continue;
                }
                if (c.getVisibility() == Community.Visibility.PRIVATE && !isMember(c.getId(), viewerId)) {
                    continue; // ozel kulubun etkinligi yalniz uyesine
                }
                club = c.getName();
            }
            String desc = e.getDescription() == null || e.getDescription().isBlank() ? null
                    : clip(e.getDescription().strip(), DESC_MAX);
            out.put(r, new Resolved(r, null, clip(e.getTitle(), TITLE_MAX), club != null ? club : e.getLocation(), desc,
                    eventImage(e.getCoverUrl()), null, null, e.getStartsAt(), e.getLocation()));
        }
    }

    private boolean isMember(Long communityId, Long viewerId) {
        return viewerId != null && communityMembers.findByCommunityIdAndUserId(communityId, viewerId)
                .filter(m -> m.isActive()).isPresent();
    }

    // ------------------------------------------------------------------ yardimcilar

    private static List<Long> ids(Collection<ShareRef> refs) {
        return refs.stream().map(ShareRef::id).distinct().toList();
    }

    private static String firstNonBlank(String... v) {
        for (String s : v) {
            if (s != null && !s.isBlank()) {
                return s.strip();
            }
        }
        return null;
    }

    static String clip(String s, int max) {
        String t = s.replaceAll("\\s+", " ").strip();
        if (t.codePointCount(0, t.length()) <= max) {
            return t;
        }
        return t.substring(0, t.offsetByCodePoints(0, max - 1)).stripTrailing() + "…";
    }

    /** Etkinlik kapagi: yalniz sunucunun kendi `/files/` yolu. */
    static String eventImage(String url) {
        return url != null && url.startsWith("/files/") && !url.contains("..") && url.length() <= 300 ? url : null;
    }

    /**
     * Haber gorseli: yalniz https ve bingol.edu.tr (alt alanlar dahil), kullanici bilgisi yok (`http://` https'e
     * cevrilir). Aksi halde null (OG sayfasi marka gorseline duser).
     */
    public static String safeBingolImage(String raw) {
        if (raw == null || raw.isBlank() || raw.length() > 1000) {
            return null;
        }
        try {
            URI u = URI.create(raw.trim());
            String scheme = u.getScheme() == null ? "" : u.getScheme().toLowerCase(Locale.ROOT);
            String host = u.getHost() == null ? "" : u.getHost().toLowerCase(Locale.ROOT);
            boolean hostOk = host.equals("bingol.edu.tr") || host.endsWith(".bingol.edu.tr");
            boolean portOk = u.getPort() == -1 || u.getPort() == 443 || u.getPort() == 80;
            if (!(scheme.equals("https") || scheme.equals("http")) || !hostOk || !portOk || u.getUserInfo() != null) {
                return null;
            }
            String path = u.getRawPath() == null || u.getRawPath().isEmpty() ? "/" : u.getRawPath();
            return "https://" + host + path + (u.getRawQuery() == null ? "" : "?" + u.getRawQuery());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
