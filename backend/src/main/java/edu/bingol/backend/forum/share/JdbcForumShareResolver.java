package edu.bingol.backend.forum.share;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import edu.bingol.backend.share.ForumShareResolver;
import edu.bingol.backend.share.ShareRef;
import edu.bingol.backend.share.ShareService;
import edu.bingol.backend.share.ShareType;
import java.time.Instant;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Forum konu / yorum paylasim cozumleyicisi (E). Kurallar:
 * <ul>
 *   <li>Yalniz ACTIVE ve silinmemis konu / yorum, yazari ACTIVE hesap. Silinmis/kaldirilmis/yok: hic donmez
 *       (var/yok ayrimi yok).</li>
 *   <li>Goruntuleyen varsa: yazarla engel (iki yonlu) ya da forum sessize alma varsa gorunmez (kendi icerigi hep gorunur).</li>
 *   <li>Herkese acik (goruntuleyen null): gizli hesabin ADIYLA gorunen icerigi onizlenmez; anonim icerik yazari ele
 *       vermedigi icin onizlenir.</li>
 *   <li>ANONIMLIK: anonim konu/yorumda ve anonim konunun yazarinin kendi konusuna adiyla yazdigi yorumda yazar adi
 *       "Anonim" gosterilir; gercek kimlik hicbir alana girmez.</li>
 *   <li>Konu: baslik = konu basligi, aciklama = govdenin ilk 140 karakteri, alt baslik = "Yazar · Kategori", gorsel =
 *       ilk gorselin kucuk resmi. Yorum: baslik = yorumun ilk 140 karakteri, alt baslik = "Yazar · Konu basligi".</li>
 * </ul>
 */
@Component
public class JdbcForumShareResolver implements ForumShareResolver {

    static final int TEXT_MAX = 140;
    static final int SUB_TITLE_MAX = 50;

    private final NamedParameterJdbcTemplate jdbc;
    private final BlockService blocks;
    private final PrivateAccountGate gate;
    private final I18n i18n;

    public JdbcForumShareResolver(NamedParameterJdbcTemplate jdbc, BlockService blocks, PrivateAccountGate gate,
                                  I18n i18n) {
        this.jdbc = jdbc;
        this.blocks = blocks;
        this.gate = gate;
        this.i18n = i18n;
    }

    /** Satir: sorgudan gelen ham konu/yorum + bagli konu bilgisi. */
    record Row(long id, long topicId, long authorId, boolean anonymous, boolean topicAnonymous, long topicAuthorId,
               String text, String topicTitle, String authorName, long categoryId, Instant createdAt, Long mediaId,
               String catTr, String catEn, String catAr) {}

    @Override
    @Transactional(readOnly = true)
    public Map<ShareRef, ShareService.Resolved> resolve(Long viewerId, Collection<ShareRef> refs) {
        Map<ShareRef, ShareService.Resolved> out = new LinkedHashMap<>();
        List<Long> topicIds = refs.stream().filter(r -> r.type() == ShareType.FORUM_TOPIC).map(ShareRef::id).distinct()
                .toList();
        List<Long> commentIds = refs.stream().filter(r -> r.type() == ShareType.FORUM_COMMENT).map(ShareRef::id)
                .distinct().toList();
        Lang lang = Lang.of(LocaleContextHolder.getLocale());
        if (!topicIds.isEmpty()) {
            List<Row> rows = topicRows(topicIds);
            Set<Long> blocked = blockedAuthors(viewerId, rows);
            Set<Long> priv = viewerId == null ? gate.privateAmong(authors(rows)) : Set.of();
            for (Row r : rows) {
                if (visible(viewerId, r, r.anonymous(), blocked, priv)) {
                    out.put(new ShareRef(ShareType.FORUM_TOPIC, r.id()), topicCard(viewerId, r, lang));
                }
            }
        }
        if (!commentIds.isEmpty()) {
            List<Row> rows = commentRows(commentIds);
            Set<Long> blocked = blockedAuthors(viewerId, rows);
            Set<Long> priv = viewerId == null ? gate.privateAmong(authors(rows)) : Set.of();
            for (Row r : rows) {
                // konu da gorunur olmali (konu yazari engelli / sessize alinmis / gizli hesap)
                boolean topicOk = viewerId != null && viewerId.equals(r.topicAuthorId())
                        || !blocked.contains(r.topicAuthorId()) && (viewerId != null || r.topicAnonymous()
                                || !priv.contains(r.topicAuthorId()));
                if (topicOk && visible(viewerId, r, commentAnonymous(r), blocked, priv)) {
                    out.put(new ShareRef(ShareType.FORUM_COMMENT, r.id()), commentCard(viewerId, r, lang));
                }
            }
        }
        return out;
    }

    private static Set<Long> authors(List<Row> rows) {
        Set<Long> ids = new HashSet<>();
        rows.forEach(r -> {
            ids.add(r.authorId());
            ids.add(r.topicAuthorId());
        });
        return ids;
    }

    /** Engel (iki yonlu) + forum sessize alma: goruntuleyene gizli yazarlar. */
    private Set<Long> blockedAuthors(Long viewerId, List<Row> rows) {
        if (viewerId == null || rows.isEmpty()) {
            return Set.of();
        }
        Set<Long> out = new HashSet<>(blocks.hiddenFrom(viewerId));
        out.addAll(jdbc.queryForList("SELECT muted_user_id FROM forum_user_mute WHERE user_id = :v",
                new MapSqlParameterSource("v", viewerId), Long.class));
        out.remove(viewerId);
        return out;
    }

    private static boolean visible(Long viewerId, Row r, boolean shownAnonymous, Set<Long> blocked, Set<Long> priv) {
        boolean self = viewerId != null && viewerId.equals(r.authorId());
        if (!self && blocked.contains(r.authorId())) {
            return false;
        }
        return viewerId != null || shownAnonymous || !priv.contains(r.authorId());
    }

    /** Yorum yazari adiyla gosterilir mi: anonim yorum ya da anonim konunun yazarinin kendi yorumu = gosterilmez. */
    private static boolean commentAnonymous(Row r) {
        return r.anonymous() || r.topicAnonymous() && r.topicAuthorId() == r.authorId();
    }

    private ShareService.Resolved topicCard(Long viewerId, Row r, Lang lang) {
        String author = r.anonymous() ? i18n.msg("share.forum.anonymous", lang) : r.authorName();
        String category = category(r, lang);
        String sub = category == null ? author : author + " · " + category;
        String body = ShareTexts.clip(r.text(), TEXT_MAX);
        return new ShareService.Resolved(new ShareRef(ShareType.FORUM_TOPIC, r.id()), r.authorId(),
                ShareTexts.clip(r.topicTitle(), TEXT_MAX), sub, body, thumb(r), r.mediaId(), null, r.createdAt(), null);
    }

    private ShareService.Resolved commentCard(Long viewerId, Row r, Lang lang) {
        String author = commentAnonymous(r) ? i18n.msg("share.forum.anonymous", lang) : r.authorName();
        String sub = author + " · " + ShareTexts.clip(r.topicTitle(), SUB_TITLE_MAX);
        String body = ShareTexts.clip(r.text(), TEXT_MAX);
        return new ShareService.Resolved(new ShareRef(ShareType.FORUM_COMMENT, r.id()), r.authorId(), body, sub, body,
                thumb(r), r.mediaId(), null, r.createdAt(), null);
    }

    private static String category(Row r, Lang lang) {
        String n = switch (lang) {
            case EN -> r.catEn();
            case AR -> r.catAr();
            default -> r.catTr();
        };
        return n == null || n.isBlank() ? r.catTr() : n;
    }

    /** Sohbet karti kucuk resmi: oturumlu goreli yol (istemci kimlik bilgisiyle ceker). */
    private static String thumb(Row r) {
        return r.mediaId() == null ? null : "/api/forum/media/" + r.mediaId() + "?thumb=true";
    }

    private static final String FIRST_IMAGE = """
            (SELECT fi.media_id FROM forum_topic_image fi JOIN forum_media m ON m.id = fi.media_id
              WHERE fi.topic_id = t.id AND m.hidden_at IS NULL AND m.thumb_key IS NOT NULL
              ORDER BY fi.position, fi.id LIMIT 1)""";

    private List<Row> topicRows(List<Long> ids) {
        return jdbc.query("""
                SELECT t.id, t.id AS topic_id, t.user_id, t.anonymous, t.anonymous AS topic_anon, t.user_id AS topic_user,
                       t.body AS text, t.title, u.display_name, t.category_id, t.created_at, %s AS media_id,
                       c.name_tr, c.name_en, c.name_ar
                  FROM forum_topic t
                  JOIN app_user u ON u.id = t.user_id AND u.status = 'ACTIVE'
                  LEFT JOIN forum_category c ON c.id = t.category_id
                 WHERE t.id IN (:ids) AND t.deleted_at IS NULL AND t.status = 'ACTIVE'""".formatted(FIRST_IMAGE),
                new MapSqlParameterSource("ids", ids), ForumShareRows::map);
    }

    private List<Row> commentRows(List<Long> ids) {
        return jdbc.query("""
                SELECT c.id, t.id AS topic_id, c.user_id, c.anonymous, t.anonymous AS topic_anon, t.user_id AS topic_user,
                       c.body AS text, t.title, u.display_name, t.category_id, c.created_at, %s AS media_id,
                       cat.name_tr, cat.name_en, cat.name_ar
                  FROM forum_comment c
                  JOIN forum_topic t ON t.id = c.topic_id AND t.deleted_at IS NULL AND t.status = 'ACTIVE'
                  JOIN app_user tu ON tu.id = t.user_id AND tu.status = 'ACTIVE'
                  JOIN app_user u ON u.id = c.user_id AND u.status = 'ACTIVE'
                  LEFT JOIN forum_category cat ON cat.id = t.category_id
                 WHERE c.id IN (:ids) AND c.deleted_at IS NULL AND c.status = 'ACTIVE'""".formatted(FIRST_IMAGE),
                new MapSqlParameterSource("ids", ids), ForumShareRows::map);
    }
}
