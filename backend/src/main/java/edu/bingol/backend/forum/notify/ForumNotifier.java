package edu.bingol.backend.forum.notify;

import edu.bingol.backend.forum.notify.ForumNotifyReader.CommentInfo;
import edu.bingol.backend.forum.notify.ForumNotifyReader.TopicInfo;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.PushDisplay;
import edu.bingol.backend.notification.RecipientGuard;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Forum bildirim KARARI ve gonderimi (FORUM_API.md 2-E). Olay kaynaklari {@link ForumEventPublisherImpl} uzerinden
 * gelir; hata ana islemi ASLA bozmaz (her giris noktasi RuntimeException yutar).
 *
 * <p>Kurallar: kendine bildirim yok; ayni olay icin ayni aliciya ikinci bildirim yok (kalici defter,
 * {@link ForumNotifyLedger}); engel (iki yonlu) ve forum sessize alma uygulanir; alici tercihi
 * ({@link ForumNotificationPref}, tum forum/konu/yanit/begeni/takip) ve konu bazli bildirim kapatma
 * ({@code forum_topic_follow.notify=false}) uygulanir; pasif/silinmis alici atlanir; moderasyon bildirimi
 * tercihle susturulamaz. Yorum yaginini azaltma: ayni konu/hedef icin 10 dakikalik sabit pencerede okunmamis
 * bildirim tek satirda birlesir ({@code NotificationService} gruplamasi, "A ve N kisi ..."), ilk bildirimden sonra
 * push gitmez.
 *
 * <p>GIZLILIK: bildirim yukunde kullanici kimligi/avatar YOK. Anonim yazar "Anonim #N" olarak adlandirilir; ayrica
 * anonim konunun yazari, konusunda adiyla yorum yazsa ya da yorum begense bile takma adiyla gosterilir (adi
 * baskalarina o konunun yazari oldugunu ifsa etmesin).
 */
@Service
public class ForumNotifier {

    private static final Logger log = LoggerFactory.getLogger(ForumNotifier.class);

    /** Birlesme penceresi (sn): sabit 10 dakikalik dilim. */
    static final long WINDOW_SECONDS = 600;
    /** Bir olayda en cok bu kadar konu takipcisine bildirim (fazlasi atlanir; boyle kalabalik konuda her yorum yine 10 dakikada bir satira birlesir). */
    static final int FOLLOWER_CAP = 2000;
    static final int FOLLOWER_PAGE = 250;
    static final int PREVIEW_MAX = 100;

    private final NotificationService notifications;
    private final NotificationRepository rows;
    private final I18n i18n;
    private final UserRepository users;
    private final BlockService blocks;
    private final RecipientGuard guard;
    private final ForumNotificationPrefService prefs;
    private final ForumNotifyReader reader;
    private final ForumNotifyLedger ledger;
    private final Clock clock;
    private final String shareBase;

    @Autowired
    public ForumNotifier(NotificationService notifications, NotificationRepository rows, I18n i18n,
                         UserRepository users, BlockService blocks, RecipientGuard guard,
                         ForumNotificationPrefService prefs, ForumNotifyReader reader, ForumNotifyLedger ledger,
                         @Value("${app.share.base-url:${PUBLIC_WEB_URL:https://bukampus.com.tr}}") String shareBase) {
        this(notifications, rows, i18n, users, blocks, guard, prefs, reader, ledger, shareBase, Clock.systemUTC());
    }

    ForumNotifier(NotificationService notifications, NotificationRepository rows, I18n i18n, UserRepository users,
                  BlockService blocks, RecipientGuard guard, ForumNotificationPrefService prefs,
                  ForumNotifyReader reader, ForumNotifyLedger ledger, String shareBase, Clock clock) {
        this.notifications = notifications;
        this.rows = rows;
        this.i18n = i18n;
        this.users = users;
        this.blocks = blocks;
        this.guard = guard;
        this.prefs = prefs;
        this.reader = reader;
        this.ledger = ledger;
        this.shareBase = shareBase == null ? "https://bukampus.com.tr" : shareBase.replaceAll("/+$", "");
        this.clock = clock;
    }

    // ------------------------------------------------------------------ olaylar

    /** Konu begenildi: yazara (kendi begenisi hariç). */
    public void topicLiked(long topicId, long actorId) {
        try {
            TopicInfo t = reader.topic(topicId).orElse(null);
            if (t == null || !t.visible()) {
                return;
            }
            long owner = t.authorId();
            if (!eligible(owner, actorId, t.id(), isAnonActor(t, actorId, false), ForumNotifyKind.FORUM_TOPIC_LIKE, prefs.byUser(List.of(owner)).get(owner))
                    || !ledger.firstTime(ForumNotifyKind.FORUM_TOPIC_LIKE.ledgerKind(), t.id(), actorId, owner)) {
                return;
            }
            Lang lang = i18n.langOf(owner);
            String name = senderName(lang, t, actorId, false);
            String key = "fotl:" + t.id() + ":" + window();
            int others = existingCount(owner, key);
            String title = i18n.msg("notif.forum.topicLike.title", lang);
            String topicTitle = clip(t.title(), 60);
            String body = others > 0
                    ? i18n.msg("notif.forum.topicLike.many.body", lang, name, String.valueOf(others), topicTitle)
                    : i18n.msg("notif.forum.topicLike.body", lang, name, topicTitle);
            Map<String, String> d = data(ForumNotifyKind.FORUM_TOPIC_LIKE, "FORUM_TOPIC", t.id(), t.id(), name, t, lang);
            notifications.send(owner, ForumNotifyKind.FORUM_TOPIC_LIKE.type(), ForumNotifyKind.FORUM_TOPIC_LIKE.subtype(),
                    key, title, body, d);
        } catch (RuntimeException e) {
            log.warn("Forum konu begeni bildirimi gonderilemedi (konu {}): {}", topicId, e.toString());
        }
    }

    /** Yorum begenildi: yorum sahibine (kendi begenisi hariç). */
    public void commentLiked(long commentId, long actorId) {
        try {
            CommentInfo c = reader.comment(commentId).orElse(null);
            if (c == null || !c.visible()) {
                return;
            }
            TopicInfo t = reader.topic(c.topicId()).orElse(null);
            if (t == null || !t.visible()) {
                return;
            }
            long owner = c.authorId();
            if (!eligible(owner, actorId, t.id(), isAnonActor(t, actorId, false), ForumNotifyKind.FORUM_COMMENT_LIKE, prefs.byUser(List.of(owner)).get(owner))
                    || !ledger.firstTime(ForumNotifyKind.FORUM_COMMENT_LIKE.ledgerKind(), c.id(), actorId, owner)) {
                return;
            }
            Lang lang = i18n.langOf(owner);
            String name = senderName(lang, t, actorId, false);
            String key = "focl:" + c.id() + ":" + window();
            int others = existingCount(owner, key);
            String title = i18n.msg("notif.forum.commentLike.title", lang);
            String body = others > 0
                    ? i18n.msg("notif.forum.commentLike.many.body", lang, name, String.valueOf(others))
                    : i18n.msg("notif.forum.commentLike.body", lang, name);
            Map<String, String> d = data(ForumNotifyKind.FORUM_COMMENT_LIKE, "FORUM_COMMENT", c.id(), t.id(), name, t, lang);
            notifications.send(owner, ForumNotifyKind.FORUM_COMMENT_LIKE.type(), ForumNotifyKind.FORUM_COMMENT_LIKE.subtype(),
                    key, title, body, d);
        } catch (RuntimeException e) {
            log.warn("Forum yorum begeni bildirimi gonderilemedi (yorum {}): {}", commentId, e.toString());
        }
    }

    /**
     * Yeni yorum: (1) ust yorumun sahibine YANIT, (2) konu sahibine YORUM (ust yorumun sahibiyle ayniysa yalniz yanit),
     * (3) konuyu takip edenlere TAKIP bildirimi. Bir kisi bir yorum icin en cok BIR bildirim alir.
     */
    public void commentCreated(long commentId, long actorIdHint) {
        try {
            CommentInfo c = reader.comment(commentId).orElse(null);
            if (c == null || !c.visible()) {
                return;
            }
            TopicInfo t = reader.topic(c.topicId()).orElse(null);
            if (t == null || !t.visible()) {
                return;
            }
            long actor = c.authorId(); // yorumun gercek yazari (cagri argumani yalniz ipucu)
            boolean forcedAnon = c.anonymous();
            String preview = preview(c.body());
            Set<Long> done = new HashSet<>();
            done.add(actor);

            Long parentAuthor = c.parentAuthorId();
            if (parentAuthor != null && !done.contains(parentAuthor)) {
                done.add(parentAuthor);
                sendComment(parentAuthor, actor, forcedAnon, ForumNotifyKind.FORUM_COMMENT_REPLY, "focr:" + c.parentId(),
                        "notif.forum.commentReply", c, t, preview);
            }
            if (!done.contains(t.authorId())) {
                done.add(t.authorId());
                sendComment(t.authorId(), actor, forcedAnon, ForumNotifyKind.FORUM_TOPIC_COMMENT, "fotc:" + t.id(),
                        "notif.forum.topicComment", c, t, preview);
            }
            notifyFollowers(c, t, actor, forcedAnon, preview, done);
        } catch (RuntimeException e) {
            log.warn("Forum yorum bildirimi gonderilemedi (yorum {}): {}", commentId, e.toString());
        }
    }

    /**
     * Moderator islemi: icerik sahibine (SYSTEM turu, tercihle susturulamaz). {@code action}: konu icin
     * PIN/UNPIN/LOCK/UNLOCK/REMOVE/RESTORE, yorum icin REMOVE/RESTORE; taninmayan eylem genel metin alir.
     *
     * @param comment true ise {@code targetId} yorum kimligi, degilse konu kimligi
     */
    public void moderated(boolean comment, long targetId, String action, String reason) {
        try {
            long owner;
            long topicId;
            String summary;
            if (comment) {
                CommentInfo c = reader.comment(targetId).orElse(null);
                if (c == null) {
                    return;
                }
                owner = c.authorId();
                topicId = c.topicId();
                summary = clip(c.body(), 60);
            } else {
                TopicInfo t = reader.topic(targetId).orElse(null);
                if (t == null) {
                    return;
                }
                owner = t.authorId();
                topicId = t.id();
                summary = clip(t.title(), 60);
            }
            if (!guard.canReceive(owner)) {
                return; // pasif / silinmis hesap
            }
            Lang lang = i18n.langOf(owner);
            String act = action == null ? "" : action.trim().toUpperCase(Locale.ROOT);
            String base = "notif.forum.moderation." + (comment ? "comment" : "topic") + "." + act;
            boolean known = !act.isEmpty() && !isMissing(base + ".title", lang);
            if (!known) {
                base = "notif.forum.moderation.other";
            }
            boolean hasReason = reason != null && !reason.isBlank();
            String title = i18n.msg(base + ".title", lang);
            String body = hasReason
                    ? i18n.msg(base + ".bodyReason", lang, summary, clip(reason.strip(), 140))
                    : i18n.msg(base + ".body", lang, summary);
            Map<String, String> d = new LinkedHashMap<>();
            d.put("target", comment ? "FORUM_COMMENT" : "FORUM_TOPIC");
            d.put("value", String.valueOf(targetId));
            d.put("topicId", String.valueOf(topicId));
            if (comment) {
                d.put("commentId", String.valueOf(targetId));
            }
            d.put("forumKind", ForumNotifyKind.FORUM_MODERATION.name());
            d.put("moderation", "1"); // style=MODERATION (docs/changes/push.md)
            d.put("action", act);
            String category = categoryOf(topicId, lang);
            PushDisplay.put(d, "sourceName", category, 60);
            // Ayni icerige ayni islem tekrar: okunmamis satir birlesir (collapseKey), yeni satir yigilmaz
            notifications.send(owner, ForumNotifyKind.FORUM_MODERATION.type(), null,
                    "fomod:" + (comment ? "c" : "t") + targetId + ":" + act, title, body, d);
        } catch (RuntimeException e) {
            log.warn("Forum moderasyon bildirimi gonderilemedi (hedef {}): {}", targetId, e.toString());
        }
    }

    // ------------------------------------------------------------------ yorum alicilari

    private void sendComment(long recipient, long actor, boolean forcedAnon, ForumNotifyKind kind, String keyBase,
                             String i18nBase, CommentInfo c, TopicInfo t, String preview) {
        if (!eligible(recipient, actor, t.id(), isAnonActor(t, actor, forcedAnon), kind, prefs.byUser(List.of(recipient)).get(recipient))
                || !ledger.firstTime(kind.ledgerKind(), c.id(), actor, recipient)) {
            return;
        }
        Lang lang = i18n.langOf(recipient);
        String name = senderName(lang, t, actor, forcedAnon);
        String key = keyBase + ":" + window();
        int others = existingCount(recipient, key);
        String title = kind == ForumNotifyKind.FORUM_TOPIC_COMMENT
                ? i18n.msg(i18nBase + ".title", lang, clip(t.title(), 60))
                : i18n.msg(i18nBase + ".title", lang);
        String body = others > 0
                ? i18n.msg(i18nBase + ".many.body", lang, name, String.valueOf(others))
                : i18n.msg(i18nBase + ".body", lang, name, preview);
        Map<String, String> d = data(kind, "FORUM_COMMENT", c.id(), t.id(), name, t, lang);
        d.put("commentId", String.valueOf(c.id()));
        notifications.send(recipient, kind.type(), kind.subtype(), key, title, body, d);
    }

    /** Konuyu takip edip bildirimi acik olanlar: dil gruplarina gore toplu gonderim (tek sorgu kumesi / parca). */
    private void notifyFollowers(CommentInfo c, TopicInfo t, long actor, boolean forcedAnon, String preview,
                                 Set<Long> done) {
        Set<Long> hidden = blocks.hiddenFrom(actor);
        List<Long> followers = reader.notifyingFollowers(t.id(), FOLLOWER_CAP);
        for (int from = 0; from < followers.size(); from += FOLLOWER_PAGE) {
            List<Long> page = followers.subList(from, Math.min(from + FOLLOWER_PAGE, followers.size()));
            List<Long> cand = new ArrayList<>();
            for (Long id : page) {
                if (!done.contains(id) && !hidden.contains(id)) {
                    cand.add(id);
                }
            }
            if (cand.isEmpty()) {
                continue;
            }
            // Anonim gonderen icin sessize alma UYGULANMAZ (kimlik sinanamasin; engel yine gecerli)
            Set<Long> muters = isAnonActor(t, actor, forcedAnon) ? Set.of() : reader.mutersAmong(cand, actor);
            Map<Long, ForumNotificationPref> pm = prefs.byUser(cand);
            Map<Lang, List<Long>> byLang = new EnumMap<>(Lang.class);
            for (User u : users.findAllById(cand)) {
                Long id = u.getId();
                if (!u.isActive() || muters.contains(id)
                        || !ForumNotifyKind.FORUM_FOLLOWED_TOPIC_COMMENT.allowed(pm.get(id))
                        || !ledger.firstTime(ForumNotifyKind.FORUM_FOLLOWED_TOPIC_COMMENT.ledgerKind(), c.id(), actor, id)) {
                    continue;
                }
                byLang.computeIfAbsent(Lang.of(u.getLanguage()), l -> new ArrayList<>()).add(id);
            }
            for (Map.Entry<Lang, List<Long>> e : byLang.entrySet()) {
                sendFollowers(e.getKey(), e.getValue(), c, t, actor, forcedAnon, preview);
            }
        }
    }

    private void sendFollowers(Lang lang, List<Long> ids, CommentInfo c, TopicInfo t, long actor, boolean forcedAnon,
                               String preview) {
        ForumNotifyKind kind = ForumNotifyKind.FORUM_FOLLOWED_TOPIC_COMMENT;
        String name = senderName(lang, t, actor, forcedAnon);
        Map<String, String> d = data(kind, "FORUM_COMMENT", c.id(), t.id(), name, t, lang);
        d.put("commentId", String.valueOf(c.id()));
        NotificationTemplates.Template tpl = new NotificationTemplates.Template("notif.forum.followedTopic",
                kind.type(), kind.subtype());
        String window = String.valueOf(window());
        notifications.sendTemplatedBulkBy(ids, tpl, d, id -> "foft:" + t.id() + ":" + window, clip(t.title(), 60), name,
                preview);
    }

    // ------------------------------------------------------------------ ortak

    /** Kendine/engelli/sessiz/tercih/konu-kapali/pasif alici elenir. */
    private boolean eligible(long recipient, long actor, long topicId, boolean anonymousActor, ForumNotifyKind kind,
                            ForumNotificationPref pref) {
        if (recipient == actor || !kind.allowed(pref)) {
            return false;
        }
        // Sessize alma yalniz gonderen ADIYLA gorunuyorsa uygulanir: anonim icerikte uygulanirsa 'bildirim gelmedi' kimlik sinamasi olur
        if (blocks.isBlocked(actor, recipient) || (!anonymousActor && reader.muted(recipient, actor))) {
            return false;
        }
        return !reader.topicNotificationsOff(topicId, recipient) && guard.canReceive(recipient);
    }

    /** Gonderen bu olayda anonim gorunuyor mu (senderName ile ayni kural). */
    static boolean isAnonActor(TopicInfo topic, long actorId, boolean forcedAnonymous) {
        return forcedAnonymous || (topic.anonymous() && topic.authorId() == actorId);
    }

    /** Gonderen adi; anonimse "Anonim #N" (alici dilinde), kimlik/ad sizmaz. */
    String senderName(Lang lang, TopicInfo topic, long actorId, boolean forcedAnonymous) {
        if (isAnonActor(topic, actorId, forcedAnonymous)) {
            Integer n = reader.anonAlias(topic.id(), actorId);
            return n == null ? i18n.msg("notif.forum.anonPlain", lang)
                    : i18n.msg("notif.forum.anon", lang, String.valueOf(n));
        }
        return users.findById(actorId).map(User::getDisplayName).filter(s -> s != null && !s.isBlank()).orElse("?");
    }

    /** Ortak yuk: hedef, topicId, tur adi, gonderen adi; push-only: kategori (sourceName), konu kucuk resmi. */
    private Map<String, String> data(ForumNotifyKind kind, String targetType, long targetId, long topicId,
                                     String senderName, TopicInfo t, Lang lang) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", targetType);
        d.put("value", String.valueOf(targetId));
        d.put("topicId", String.valueOf(topicId));
        d.put("forumKind", kind.name());
        PushDisplay.put(d, "senderName", senderName, 60);
        PushDisplay.put(d, "sourceName", reader.categoryName(t.categoryId(), lang), 60);
        if (reader.topicHasImage(t.id())) {
            d.put("imageUrl", shareBase + "/s/f/" + t.id() + "/img");
        }
        return d;
    }

    private String categoryOf(long topicId, Lang lang) {
        return reader.topic(topicId).map(t -> reader.categoryName(t.categoryId(), lang)).orElse(null);
    }

    private int existingCount(long recipient, String key) {
        return rows.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(recipient, key)
                .map(Notification::getGroupCount).orElse(0);
    }

    private long window() {
        return clock.instant().getEpochSecond() / WINDOW_SECONDS;
    }

    private boolean isMissing(String key, Lang lang) {
        return Objects.equals(i18n.msg(key, lang), key);
    }

    /** Bosluklari sadelestirir, ilk {@value #PREVIEW_MAX} karakter. */
    static String preview(String body) {
        return clip(body, PREVIEW_MAX);
    }

    static String clip(String s, int max) {
        if (s == null) {
            return "";
        }
        String t = s.replaceAll("\\s+", " ").strip();
        if (t.codePointCount(0, t.length()) <= max) {
            return t;
        }
        return t.substring(0, t.offsetByCodePoints(0, max - 1)).stripTrailing() + "…";
    }
}
