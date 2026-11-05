package edu.bingol.backend.post.notify;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gönderi etkileşim bildirimleri (beğeni, etiket, takip). Hata bildirimi kullanıcı eylemini ASLA bozmaz.
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
            d.put("actorId", String.valueOf(actorId)); // gelen kutusu avatar projeksiyonu icin (kisi kimligi)
            putAvatar(d, actorId, postAuthorId);
            notifications.send(postAuthorId, NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE, key, title, body,
                    d);
        } catch (RuntimeException e) {
            log.warn("Begeni bildirimi gonderilemedi (gonderi {}): {}", postId, e.toString());
        }
    }

    /**
     * Gonderide etiketlendi: etiketlenene "{ad} seni bir gonderide etiketledi". Hedef: gonderi (targetType POST).
     * Kendi kendine, engel iliskisinde, alici gonderiyi goremiyorsa (yazar gizli hesap, alici kabul edilmis takipci degil:
     * bildirim 404'e acilir) bildirim gitmez. collapseKey postmention:&lt;gonderi&gt;: ayni (gonderi, kisi) icin okunmus
     * ya da silinmis olsa da ikinci bildirim yok (etiketi kaldirip yeniden eklemek bildirim spam'i olmasin).
     * Tercih (sosyal/communities) ve alt tur POST_MENTION {@code NotificationService.send} icinde uygulanir.
     * Push yuku: senderName, senderAvatarUrl (gizlilik suzgeciyle), imageUrl (gonderi kucuk resmi; yalniz push).
     */
    public void onMention(Long authorId, Long postId, Long targetId) {
        try {
            if (!shouldNotify(authorId, targetId)) {
                return;
            }
            if (gate != null && !gate.canSeeContent(targetId, authorId)) {
                return;
            }
            String key = "postmention:" + postId;
            if (notificationRows.existsByUserIdAndCollapseKey(targetId, key)) {
                return;
            }
            Lang lang = i18n.langOf(targetId);
            String name = actorName(authorId);
            Map<String, String> d = data(postId);
            d.put("userId", String.valueOf(authorId)); // gelen kutusu avatar projeksiyonu icin (etiketleyen)
            d.put("senderName", name);
            putAvatar(d, authorId, targetId);
            putPostThumb(d, postId);
            notifications.send(targetId, NotificationType.POST_MENTION, NotificationSubtype.POST_MENTION, key,
                    i18n.msg("notif.post.mention.title", lang), i18n.msg("notif.post.mention.body", lang, name), d);
        } catch (RuntimeException e) {
            log.warn("Etiket bildirimi gonderilemedi (gonderi {}): {}", postId, e.toString());
        }
    }

    /** Gizli hesap kapisi (yoksa tum hesaplar acik sayilir). */
    private edu.bingol.backend.post.follow.PrivateAccountGate gate;
    private edu.bingol.backend.post.media.PostMediaRepository postMedia;
    private edu.bingol.backend.media.transcode.MediaCdnLinks cdn;

    @Autowired(required = false)
    void setMentionDeps(edu.bingol.backend.post.follow.PrivateAccountGate gate,
                        edu.bingol.backend.post.media.PostMediaRepository postMedia,
                        edu.bingol.backend.media.transcode.MediaCdnLinks cdn) {
        this.gate = gate;
        this.postMedia = postMedia;
        this.cdn = cdn;
    }

    /**
     * Gonderi kucuk resmi (yalniz push yuku; kalici data'ya yazilmaz): CDN imzali baglanti aciksa o, degilse
     * PostView.thumbUrl ile ayni oturumlu yol (/api/posts/media/&lt;id&gt;?thumb=true; sohbet bildirim gorseliyle ayni kural).
     * Kucuk resmi olmayan (poster'siz video) gonderide imageUrl konmaz.
     */
    private void putPostThumb(Map<String, String> d, Long postId) {
        try {
            if (postMedia == null) {
                return;
            }
            postMedia.findByPostIdOrderByPositionAscIdAsc(postId).stream()
                    .filter(m -> m.getThumbKey() != null && !m.isHidden()).findFirst().ifPresent(m -> {
                        String signed = cdn == null ? null : cdn.url(m.getId(), true);
                        d.put("imageUrl", signed != null ? signed : "/api/posts/media/" + m.getId() + "?thumb=true");
                    });
        } catch (RuntimeException e) {
            log.debug("Etiket bildirimi gorseli eklenemedi: {}", e.getClass().getSimpleName());
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
            putAvatar(d, followerId, followeeId);
            notifications.send(followeeId, NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW,
                    "follow:" + followerId, i18n.msg("notif.user.follow.title", lang),
                    i18n.msg("notif.user.follow.body", lang, actorName(followerId)), d);
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
            putAvatar(d, requesterId, targetId);
            notifications.send(targetId, NotificationType.FOLLOW_REQUEST, NotificationSubtype.FOLLOW_REQUEST,
                    "followreq:" + requesterId, i18n.msg("notif.follow.request.title", lang),
                    i18n.msg("notif.follow.request.body", lang, actorName(requesterId)), d);
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
            putAvatar(d, accepterId, requesterId);
            notifications.send(requesterId, NotificationType.FOLLOW_ACCEPTED, NotificationSubtype.FOLLOW_ACCEPTED,
                    "followacc:" + accepterId, i18n.msg("notif.follow.accepted.title", lang),
                    i18n.msg("notif.follow.accepted.body", lang, actorName(accepterId)), d);
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

    /** Aktor avatari (yalniz push yuku; kalici data'ya yazilmaz): alicinin gormesine izin veriliyorsa. */
    private edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility;

    @Autowired(required = false)
    void setAvatarVisibility(edu.bingol.backend.profile.privacy.AvatarVisibility avatarVisibility) {
        this.avatarVisibility = avatarVisibility;
    }

    private void putAvatar(Map<String, String> d, Long actorId, Long recipientId) {
        try {
            if (avatarVisibility == null) {
                return;
            }
            String avatar = users.findById(actorId).map(User::getAvatarUrl).filter(u -> u != null && !u.isBlank()).orElse(null);
            if (avatar != null && avatarVisibility.canSee(recipientId, actorId,
                    edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR)) {
                d.put("senderAvatarUrl", avatar);
            }
        } catch (RuntimeException e) {
            log.debug("Bildirim avatari eklenemedi: {}", e.getClass().getSimpleName());
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
