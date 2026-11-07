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

    /**
     * Yorum begenisi: yorum sahibine. Kendi yorumu ve engel iliskisinde yok; ayni kisi ayni yorumu tekrar begenince
     * (geri alip yeniden) ikinci bildirim gitmez: toplama anahtari yorum+kisi, kutuda satiri varsa (okunmus da olsa) atlanir.
     */
    public void onLike(Long actorId, Long postId, Long commentId, Long commentAuthorId) {
        try {
            if (!shouldNotify(actorId, commentAuthorId)) {
                return;
            }
            String key = "pclk:" + commentId + ":" + actorId;
            Integer seen = jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ? AND collapse_key = ?",
                    Integer.class, commentAuthorId, key);
            if (seen != null && seen > 0) {
                return;
            }
            Lang lang = i18n.langOf(commentAuthorId);
            notifications.send(commentAuthorId, NotificationType.COMMENT_LIKE, NotificationSubtype.COMMENT_LIKE, key,
                    i18n.msg("notif.comment.like.title", lang), i18n.msg("notif.comment.like.body", lang, actorName(actorId)),
                    data(postId, commentId));
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
