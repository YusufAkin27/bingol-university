package edu.bingol.backend.post.notify;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gönderi etkileşim bildirimleri (beğeni, takip). Hata bildirimi kullanıcı eylemini ASLA bozmaz.
 *
 * <p>Beğeni birleştirme: mevcut {@code NotificationService} gruplamasına dayanır. Toplama anahtarı
 * {@code postlike:<postId>:<pencere>}; pencere = epoch saniye / 600 (sabit 10 dakikalık dilim). Aynı anahtarlı
 * OKUNMAMIŞ bildirim varsa satır güncellenir (metin "{ad} ve {n} kişi gönderini beğendi", sayaç artar);
 * okunmuşsa ya da yeni dilime girilmişse yeni bildirim açılır. Redis / gecikmeli iş gerekmez.
 * Alıcı metni kendi dilinde üretilir. Tercih ve sessiz saat {@code NotificationService.send} içinde uygulanır.
 */
@Service
public class PostNotifier {

    private static final Logger log = LoggerFactory.getLogger(PostNotifier.class);
    static final long WINDOW_SECONDS = 600;

    private final NotificationService notifications;
    private final NotificationRepository notificationRows;
    private final I18n i18n;
    private final UserRepository users;
    private final BlockService blocks;
    private final Clock clock;

    @Autowired
    public PostNotifier(NotificationService notifications, NotificationRepository notificationRows, I18n i18n,
                        UserRepository users, BlockService blocks) {
        this(notifications, notificationRows, i18n, users, blocks, Clock.systemUTC());
    }

    PostNotifier(NotificationService notifications, NotificationRepository notificationRows, I18n i18n,
                 UserRepository users, BlockService blocks, Clock clock) {
        this.notifications = notifications;
        this.notificationRows = notificationRows;
        this.i18n = i18n;
        this.users = users;
        this.blocks = blocks;
        this.clock = clock;
    }

    /** Gonderen avatari / bolum / sinif gizlilik kontrolu (yoksa avatar ve ayrinti eklenmez). */
    private AvatarVisibility visibility;

    @Autowired(required = false)
    void setVisibility(AvatarVisibility visibility) {
        this.visibility = visibility;
    }

    /** Gonderi onizleme adresi (yalniz CDN imzali adres varsa; yoksa kart gorselsiz gider). */
    private org.springframework.beans.factory.ObjectProvider<edu.bingol.backend.post.media.PostMediaService> postMedia;

    @Autowired(required = false)
    void setPostMedia(org.springframework.beans.factory.ObjectProvider<edu.bingol.backend.post.media.PostMediaService> m) {
        this.postMedia = m;
    }

    /** Gönderi beğenildi; yazara (kendi beğenisi hariç) birleşen bildirim. */
    public void onLike(Long actorId, Long postId, Long postAuthorId) {
        try {
            if (!shouldNotify(actorId, postAuthorId)) {
                return;
            }
            // A06#11: begen/begenme/begen tekrarlari ("X ve 59 kisi begendi") grup sayacini sisirmesin
            if (!firstLikeInWindow(actorId, postId)) {
                return;
            }
            String key = "postlike:" + postId + ":" + (clock.instant().getEpochSecond() / WINDOW_SECONDS);
            int others = notificationRows.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(postAuthorId, key)
                    .map(Notification::getGroupCount).orElse(0);
            Lang lang = i18n.langOf(postAuthorId);
            String name = actorName(actorId);
            String title = i18n.msg("notif.post.like.title", lang);
            String body = others > 0
                    ? i18n.msg("notif.post.like.many.body", lang, name, String.valueOf(others))
                    : i18n.msg("notif.post.like.body", lang, name);
            Map<String, String> d = data(postId);
            d.put("actorId", String.valueOf(actorId)); // kutuda gonderen adi/avatari bakana gore uretilir
            Map<String, String> extra = actorExtra(postAuthorId, actorId, name);
            String thumb = postThumb(postId);
            if (thumb != null) {
                extra.put("imageUrl", thumb);
            }
            // Push: "{ad} gonderini begendi" (govde bos), kutu: "Yeni begeni" + ayrintili govde
            notifications.sendCard(postAuthorId, NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE, key, title,
                    body, body, "", d, extra);
        } catch (RuntimeException e) {
            log.warn("Begeni bildirimi gonderilemedi (gonderi {}): {}", postId, e.toString());
        }
    }

    /** Yeni takipci: takip edilene. Hedef: takipcinin profili (targetType USER). */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onFollow(Long followerId, Long followeeId) {
        try {
            if (!shouldNotify(followerId, followeeId)) {
                return;
            }
            // Takip birak-al spam'i: ayni kisiden bir kez bildirildiyse (okunmus olsa da) tekrar bildirilmez.
            if (notificationRows.existsByUserIdAndCollapseKey(followeeId, "follow:" + followerId)) {
                return;
            }
            Lang lang = i18n.langOf(followeeId);
            Map<String, String> d = new LinkedHashMap<>();
            d.put("target", "USER");
            d.put("value", String.valueOf(followerId));
            d.put("userId", String.valueOf(followerId));
            String name = actorName(followerId);
            Map<String, String> extra = actorExtra(followeeId, followerId, name);
            notifications.sendCard(followeeId, NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW,
                    "follow:" + followerId, i18n.msg("notif.user.follow.title", lang),
                    i18n.msg("notif.user.follow.body", lang, name), i18n.msg("notif.push.follow.title", lang, name),
                    actorLine(followeeId, followerId, lang), d, extra);
        } catch (RuntimeException e) {
            log.warn("Takip bildirimi gonderilemedi (kullanici {}): {}", followeeId, e.toString());
        }
    }

    /**
     * Gizli hesaba takip istegi: hedefe. collapseKey followreq:&lt;istekci&gt; (ayni kisiden tekrar istek ayni satiri
     * gunceller), push targetType FOLLOW_REQUESTS (istek kutusunu acar).
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onFollowRequest(Long requesterId, Long targetId) {
        try {
            if (!shouldNotify(requesterId, targetId)) {
                return;
            }
            Lang lang = i18n.langOf(targetId);
            Map<String, String> d = new LinkedHashMap<>();
            d.put("target", "FOLLOW_REQUESTS");
            d.put("value", String.valueOf(requesterId));
            d.put("userId", String.valueOf(requesterId));
            String name = actorName(requesterId);
            d.put("requestId", String.valueOf(requesterId)); // kabul/red: /api/users/me/follow-requests/{requestId}/accept|decline
            Map<String, String> extra = actorExtra(targetId, requesterId, name);
            notifications.sendCard(targetId, NotificationType.FOLLOW_REQUEST, NotificationSubtype.FOLLOW_REQUEST,
                    "followreq:" + requesterId, i18n.msg("notif.follow.request.title", lang),
                    i18n.msg("notif.follow.request.body", lang, name), i18n.msg("notif.push.request.title", lang, name),
                    actorLine(targetId, requesterId, lang), d, extra);
        } catch (RuntimeException e) {
            log.warn("Takip istegi bildirimi gonderilemedi (kullanici {}): {}", targetId, e.toString());
        }
    }

    /** Istek kabul edildi: istek sahibine. Push targetType USER, targetId = kabul eden. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onFollowAccepted(Long accepterId, Long requesterId) {
        try {
            if (!shouldNotify(accepterId, requesterId)) {
                return;
            }
            Lang lang = i18n.langOf(requesterId);
            Map<String, String> d = new LinkedHashMap<>();
            d.put("target", "USER");
            d.put("value", String.valueOf(accepterId));
            d.put("userId", String.valueOf(accepterId));
            String name = actorName(accepterId);
            Map<String, String> extra = actorExtra(requesterId, accepterId, name);
            notifications.sendCard(requesterId, NotificationType.FOLLOW_ACCEPTED, NotificationSubtype.FOLLOW_ACCEPTED,
                    "followacc:" + accepterId, i18n.msg("notif.follow.accepted.title", lang),
                    i18n.msg("notif.follow.accepted.body", lang, name), i18n.msg("notif.push.accepted.title", lang, name),
                    "", d, extra);
        } catch (RuntimeException e) {
            log.warn("Takip kabul bildirimi gonderilemedi (kullanici {}): {}", requesterId, e.toString());
        }
    }

    /** Aynı (kişi, gönderi) çiftine {@link #LIKE_DEDUPE_SECONDS} içinde ikinci beğeni bildirimi gitmez. */
    static final long LIKE_DEDUPE_SECONDS = 600;
    private static final int LIKE_DEDUPE_MAX = 20_000;

    /** (kişi, gönderi) → bildirimin yeniden gönderilebileceği an (epoch sn); sınırlı LRU, örneğe özel (en iyi çaba). */
    private final Map<String, Long> likeSeen = new LinkedHashMap<>(256, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, Long> eldest) {
            return size() > LIKE_DEDUPE_MAX;
        }
    };

    private boolean firstLikeInWindow(Long actorId, Long postId) {
        long nowS = clock.instant().getEpochSecond();
        String k = actorId + ":" + postId;
        synchronized (likeSeen) {
            Long until = likeSeen.get(k);
            if (until != null && until > nowS) {
                return false;
            }
            likeSeen.put(k, nowS + LIKE_DEDUPE_SECONDS);
            return true;
        }
    }

    private boolean shouldNotify(Long actorId, Long recipientId) {
        return recipientId != null && actorId != null && !Objects.equals(actorId, recipientId)
                && !blocks.isBlocked(actorId, recipientId);
    }

    /**
     * Yalniz push yukune giren gonderen bilgisi: ad ve (alicinin gormesine gizlilik izin veriyorsa, engel yoksa) avatar.
     * Kutu satirina yazilmaz; kutuda ayni bilgi okuma aninda bakana gore uretilir (InboxCardEnricher).
     */
    private Map<String, String> actorExtra(Long recipientId, Long actorId, String name) {
        Map<String, String> extra = new LinkedHashMap<>();
        extra.put("senderName", name);
        try {
            String avatar = users.findById(actorId).map(User::getAvatarUrl).filter(a -> !a.isBlank()).orElse(null);
            if (avatar != null && visibility != null && !blocks.isBlocked(actorId, recipientId)
                    && visibility.canSee(recipientId, actorId, AvatarVisibility.Field.AVATAR)) {
                extra.put("senderAvatarUrl", avatar);
            }
        } catch (RuntimeException e) {
            log.debug("Gonderen avatari hazirlanamadi: {}", e.toString());
        }
        return extra;
    }

    /** "Bolum - N. sinif" (yalniz alicinin gormesine izin verilen alanlar); bos olabilir. */
    private String actorLine(Long recipientId, Long actorId, Lang lang) {
        try {
            User u = users.findById(actorId).orElse(null);
            if (u == null) {
                return "";
            }
            Set<AvatarVisibility.Field> ok = new java.util.HashSet<>();
            if (visibility != null) {
                Map<AvatarVisibility.Field, Set<Long>> vis = visibility.visibleOwners(recipientId, Set.of(actorId),
                        java.util.EnumSet.of(AvatarVisibility.Field.DEPARTMENT, AvatarVisibility.Field.CLASS_YEAR));
                vis.forEach((f, owners) -> {
                    if (owners.contains(actorId)) {
                        ok.add(f);
                    }
                });
            }
            java.util.List<String> parts = new java.util.ArrayList<>();
            if (ok.contains(AvatarVisibility.Field.DEPARTMENT) && u.getDepartment() != null && !u.getDepartment().isBlank()) {
                parts.add(u.getDepartment());
            }
            if (ok.contains(AvatarVisibility.Field.CLASS_YEAR) && u.getClassYear() != null) {
                parts.add(i18n.msg("notif.push.classYear", lang, String.valueOf(u.getClassYear())));
            }
            return String.join(" · ", parts);
        } catch (RuntimeException e) {
            return "";
        }
    }

    private String postThumb(Long postId) {
        try {
            edu.bingol.backend.post.media.PostMediaService svc = postMedia == null ? null : postMedia.getIfAvailable();
            return svc == null ? null : svc.pushThumbUrl(postId).orElse(null);
        } catch (RuntimeException e) {
            return null;
        }
    }

    private String actorName(Long actorId) {
        return users.findById(actorId).map(User::getDisplayName).filter(s -> s != null && !s.isBlank()).orElse("?");
    }

    /** target/value → push yükünde targetType:"POST", targetId:&lt;postId&gt; olur. */
    private static Map<String, String> data(Long postId) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", "POST");
        d.put("value", String.valueOf(postId));
        d.put("postId", String.valueOf(postId));
        return d;
    }
}
