package edu.bingol.backend.post.comment;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Yorum bildirimleri: yoruma yanit (yanitlanan yorumun yazarina) ve gonderiye yeni yorum (gonderi sahibine; sahibi
 * zaten yanit alicisiysa tekrar gitmez). Alici metni kendi dilinde uretilir; hata kullanici eylemini ASLA bozmaz.
 * Push yuku: target=POST, value=postId, commentId (mobil gonderi/reel yorum panelini acar).
 */
@Service
public class CommentNotifier {

    private static final Logger log = LoggerFactory.getLogger(CommentNotifier.class);

    private final NotificationService notifications;
    private final I18n i18n;
    private final UserRepository users;
    private final BlockService blocks;
    private final JdbcTemplate jdbc;

    public CommentNotifier(NotificationService notifications, I18n i18n, UserRepository users, BlockService blocks,
                           JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.notifications = notifications;
        this.i18n = i18n;
        this.users = users;
        this.blocks = blocks;
    }

    /** Ust duzey yorum: gonderi sahibine. */
    public void onComment(Long actorId, Long postId, Long postAuthorId, Long commentId) {
        try {
            if (!shouldNotify(actorId, postAuthorId)) {
                return;
            }
            Lang lang = i18n.langOf(postAuthorId);
            notifications.send(postAuthorId, NotificationType.POST_COMMENT, NotificationSubtype.POST_COMMENT,
                    "pcmt:" + commentId, i18n.msg("notif.comment.post.title", lang),
                    i18n.msg("notif.comment.post.body", lang, actorName(actorId)), data(postId, commentId));
        } catch (RuntimeException e) {
            log.warn("Yorum bildirimi gonderilemedi (gonderi {}): {}", postId, e.toString());
        }
    }

    /**
     * Yanit: yanitlanan yorumun yazarina; gonderi sahibi baska biriyse ona da "gonderine yorum" gider (yalniz yanitlanan
     * kisi gonderi sahibi degilse).
     */
    public void onReply(Long actorId, Long postId, Long postAuthorId, Long replyId, Long repliedAuthorId) {
        try {
            if (shouldNotify(actorId, repliedAuthorId)) {
                Lang lang = i18n.langOf(repliedAuthorId);
                notifications.send(repliedAuthorId, NotificationType.COMMENT_REPLY, NotificationSubtype.COMMENT_REPLY,
                        "pcrep:" + replyId, i18n.msg("notif.comment.reply.title", lang),
                        i18n.msg("notif.comment.reply.body", lang, actorName(actorId)), data(postId, replyId));
            }
            if (!Objects.equals(postAuthorId, repliedAuthorId)) {
                onComment(actorId, postId, postAuthorId, replyId);
            }
        } catch (RuntimeException e) {
            log.warn("Yanit bildirimi gonderilemedi (gonderi {}): {}", postId, e.toString());
        }
    }

    static final long WINDOW_SECONDS = 600;
    static final long LIKE_DEDUPE_SECONDS = 600;
    private static final int LIKE_DEDUPE_MAX = 20_000;
    private java.time.Clock clock = java.time.Clock.systemUTC();

    /** (kisi, yorum) -> bildirimin yeniden gonderilebilecegi an (epoch sn); sinirli LRU, orneğe ozel (en iyi caba). */
    private final Map<String, Long> likeSeen = new LinkedHashMap<>(256, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, Long> eldest) {
            return size() > LIKE_DEDUPE_MAX;
        }
    };

    /**
     * Yorum begenisi: yorum sahibine, BIRLESEN bildirim. Toplama anahtari {@code pclk:<yorum>:<pencere>} (pencere = 10 dk);
     * ayni anahtarli OKUNMAMIS satir varsa guncellenir ("{ad} ve {n} kisi yorumunu begendi", sayac artar). Kendi yorumu ve
     * engel iliskisinde yok; ayni kisinin begen/geri al/begen tekrari sayaci sisirmesin diye 10 dk icinde ikinci bildirim yok.
     * Push yuku postId + commentId tasir (eski istemciler icin degismedi).
     */
    public void onLike(Long actorId, Long postId, Long commentId, Long commentAuthorId) {
        try {
            if (!shouldNotify(actorId, commentAuthorId)) {
                return;
            }
            long nowS = clock.instant().getEpochSecond();
            String seenKey = actorId + ":" + commentId;
            synchronized (likeSeen) {
                Long until = likeSeen.get(seenKey);
                if (until != null && until > nowS) {
                    return;
                }
                likeSeen.put(seenKey, nowS + LIKE_DEDUPE_SECONDS);
            }
            String key = "pclk:" + commentId + ":" + (nowS / WINDOW_SECONDS);
            Integer prev = jdbc.queryForObject(
                    "SELECT COALESCE(MAX(group_count), 0) FROM notification WHERE user_id = ? AND collapse_key = ? AND read_at IS NULL",
                    Integer.class, commentAuthorId, key);
            int others = prev == null ? 0 : prev;
            Lang lang = i18n.langOf(commentAuthorId);
            String name = actorName(actorId);
            String body = others > 0
                    ? i18n.msg("notif.comment.like.many.body", lang, name, String.valueOf(others))
                    : i18n.msg("notif.comment.like.body", lang, name);
            Map<String, String> d = data(postId, commentId);
            d.put("userId", String.valueOf(actorId)); // gelen kutusu avatar projeksiyonu icin (son begenen)
            notifications.send(commentAuthorId, NotificationType.COMMENT_LIKE, NotificationSubtype.COMMENT_LIKE, key,
                    i18n.msg("notif.comment.like.title", lang), body, d);
        } catch (RuntimeException e) {
            log.warn("Yorum begeni bildirimi gonderilemedi (yorum {}): {}", commentId, e.toString());
        }
    }

    private boolean shouldNotify(Long actorId, Long recipientId) {
        return recipientId != null && actorId != null && !Objects.equals(actorId, recipientId)
                && !blocks.isBlocked(actorId, recipientId);
    }

    private String actorName(Long actorId) {
        return users.findById(actorId).map(User::getDisplayName).filter(s -> s != null && !s.isBlank()).orElse("?");
    }

    private static Map<String, String> data(Long postId, Long commentId) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", "POST");
        d.put("value", String.valueOf(postId));
        d.put("targetType", "POST");
        d.put("targetId", String.valueOf(postId));
        d.put("postId", String.valueOf(postId));
        d.put("commentId", String.valueOf(commentId));
        return d;
    }
}
