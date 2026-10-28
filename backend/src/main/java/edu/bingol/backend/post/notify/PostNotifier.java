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

    /** Gönderi beğenildi; yazara (kendi beğenisi hariç) birleşen bildirim. */
    public void onLike(Long actorId, Long postId, Long postAuthorId) {
        try {
            if (!shouldNotify(actorId, postAuthorId)) {
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
            notifications.send(postAuthorId, NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE, key, title, body,
                    data(postId));
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
            notifications.send(followeeId, NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW,
                    "follow:" + followerId, i18n.msg("notif.user.follow.title", lang),
                    i18n.msg("notif.user.follow.body", lang, actorName(followerId)), d);
        } catch (RuntimeException e) {
            log.warn("Takip bildirimi gonderilemedi (kullanici {}): {}", followeeId, e.toString());
        }
    }

    private boolean shouldNotify(Long actorId, Long recipientId) {
        return recipientId != null && actorId != null && !Objects.equals(actorId, recipientId)
                && !blocks.isBlocked(actorId, recipientId);
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
