package edu.bingol.backend.forum.comment;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentPage;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentView;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CreateCommentRequest;
import edu.bingol.backend.forum.comment.ForumCommentDtos.LikeState;
import edu.bingol.backend.forum.comment.ForumCommentDtos.SaveState;
import edu.bingol.backend.forum.comment.spi.ForumCommentCreateGuard;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Forum yorumlari (docs/FORUM_API.md 2-B). Gorunurluk konunun gorunurlugunu izler (ForumTopicLookup; gorunmez = 404);
 * engel (iki yonlu) + sessize alma yazarlari bakanin listelerinden, anonim olsa da, gizler. Yetki SUNUCUDA: duzenleme
 * ve silme yalniz sahibe (403 FORUM_NOT_OWNER); moderator kaldirmasi ForumCommentStateService uzerindendir.
 * Sayaclar atomik UPDATE (ForumCommentCounters); begeni PK kisitiyla idempotent. Bildirim olaylari COMMIT SONRASI.
 */
@Service
public class ForumCommentService {

    private static final Logger log = LoggerFactory.getLogger(ForumCommentService.class);
    private static final Pattern IDEM_KEY = Pattern.compile("[A-Za-z0-9._:-]{8,100}");
    static final int PREVIEW_PER_COMMENT = 2;

    public enum Sort { BEST, NEWEST, OLDEST }

    private final ForumCommentStore store;
    private final ForumCommentRepository repo;
    private final ForumCommentCounters counters;
    private final ForumCommentLifecycle lifecycle;
    private final ForumCommentAssembler assembler;
    private final ForumCommentTopics topics;
    private final BlockService blocks;
    private final ContentGuard guard;
    private final ObjectProvider<ForumCommentCreateGuard> createGuards;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public ForumCommentService(ForumCommentStore store, ForumCommentRepository repo, ForumCommentCounters counters,
                               ForumCommentLifecycle lifecycle, ForumCommentAssembler assembler,
                               ForumCommentTopics topics, BlockService blocks, ContentGuard guard,
                               ObjectProvider<ForumCommentCreateGuard> createGuards, JdbcTemplate jdbc,
                               PlatformTransactionManager tm) {
        this.store = store;
        this.repo = repo;
        this.counters = counters;
        this.lifecycle = lifecycle;
        this.assembler = assembler;
        this.topics = topics;
        this.blocks = blocks;
        this.guard = guard;
        this.createGuards = createGuards;
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
    }

    // ---------------------------------------------------------------- yazma

    /** Yorum / yanit ekler. @param idempotencyKey cift gonderimde ayni yorumu doner (null = korumasiz) */
    public CommentView create(Long uid, Long topicId, CreateCommentRequest req, String idempotencyKey) {
        String key = idempotencyKey != null && IDEM_KEY.matcher(idempotencyKey.strip()).matches() ? idempotencyKey.strip() : null;
        ForumCommentTopics.TopicInfo topic = topics.visible(topicId, uid).orElseThrow(ForumCommentService::topicNotFound);
        if (key != null) {
            ForumCommentRow existing = store.findByIdempotencyKey(uid, key).orElse(null);
            if (existing != null) {
                return replay(uid, topic, existing, key);
            }
        }
        if (topic.locked()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_TOPIC_LOCKED", "Bu konu yorumlara kapatıldı.");
        }
        String body = ForumCommentText.require(req.body());
        guard.assertClean(ContentGuard.Entity.COMMENT, "body", uid, body);
        for (ForumCommentCreateGuard g : createGuards.orderedStream().toList()) {
            g.beforeCreate(uid, topicId, body);
        }
        boolean anonymous = Boolean.TRUE.equals(req.anonymous());
        Set<Long> hidden = hiddenAuthors(uid);
        if (anonymous) {
            topics.ensureAlias(topicId, uid); // konu basina kararli "Anonim #N"
        }
        ForumCommentRow created;
        try {
            created = tx.execute(st -> insert(uid, topic, req.parentCommentId(), body, anonymous, key, hidden));
        } catch (DataIntegrityViolationException e) {
            ForumCommentRow existing = key == null ? null : store.findByIdempotencyKey(uid, key).orElse(null);
            if (existing == null) {
                throw e;
            }
            return replay(uid, topic, existing, key); // es zamanli cift gonderim: kazanan satir
        }
        try {
            topics.commentCreated(created.id(), uid);
        } catch (RuntimeException e) {
            log.warn("Forum yorum bildirimi atlandi (yorum {}): {}", created.id(), e.toString());
        }
        return assembler.assemble(uid, topic, List.of(created)).get(0);
    }

    private CommentView replay(Long uid, ForumCommentTopics.TopicInfo topic, ForumCommentRow existing, String key) {
        if (existing.topicId() != topic.id()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "IDEMPOTENCY_KEY_REUSED",
                    "Bu Idempotency-Key başka bir istek için kullanılmış.");
        }
        return assembler.assemble(uid, topic, List.of(existing)).get(0);
    }

    private ForumCommentRow insert(Long uid, ForumCommentTopics.TopicInfo topic, Long parentId, String body,
                                   boolean anonymous, String key, Set<Long> hidden) {
        ForumCommentRow parent = null;
        if (parentId != null) {
            // Ust yorumu KILITLE: ayni anda silinme / yanit yarisinda sirali (silme de bu satiri kilitler)
            parent = store.findForUpdate(parentId).orElseThrow(ForumCommentService::notFound);
            if (parent.topicId() != topic.id() || (parent.live() && hidden.contains(parent.userId()))) {
                throw notFound();
            }
            if (!parent.live()) {
                throw new ApiException(HttpStatus.CONFLICT, "FORUM_COMMENT_PARENT_UNAVAILABLE",
                        "Yanıtlamak istediğin yorum silinmiş ya da kaldırılmış.");
            }
        }
        ForumComment c = new ForumComment();
        c.setTopicId(topic.id());
        c.setUserId(uid);
        c.setBody(body);
        c.setAnonymous(anonymous);
        c.setIdempotencyKey(key);
        if (parent != null) {
            c.setParentCommentId(parent.id());
            c.setRootCommentId(parent.rootId() != null ? parent.rootId() : parent.id());
            c.setDepth(parent.depth() + 1);
        }
        c = repo.saveAndFlush(c);
        if (parent != null) {
            counters.replies(parent.id(), 1);
        }
        counters.topicComments(topic.id(), 1, true); // konu satiri EN SON
        return store.find(c.getId()).orElseThrow();
    }

    /** Duzenle (yalniz sahip). Kilitli konuda duzenleme yok; eszamanli silinmisse 404. */
    public CommentView edit(Long uid, Long commentId, String rawBody) {
        ForumCommentRow row = store.find(commentId).orElseThrow(ForumCommentService::notFound);
        ForumCommentTopics.TopicInfo topic = topics.visible(row.topicId(), uid).orElseThrow(ForumCommentService::notFound);
        if (!row.live()) {
            throw notFound();
        }
        if (row.userId() != uid) {
            if (hiddenAuthors(uid).contains(row.userId())) {
                throw notFound();
            }
            throw new ApiException(HttpStatus.FORBIDDEN, "FORUM_NOT_OWNER", "Bu yorumu yalnızca yazarı değiştirebilir.");
        }
        if (topic.locked()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_TOPIC_LOCKED", "Bu konu yorumlara kapatıldı.");
        }
        String body = ForumCommentText.require(rawBody);
        if (body.equals(row.body())) {
            return assembler.assemble(uid, topic, List.of(row)).get(0); // degisiklik yok: "Duzenlendi" damgasi basilmaz
        }
        guard.assertChanged(ContentGuard.Entity.COMMENT, "body", uid, row.body(), body);
        Timestamp now = Timestamp.from(Instant.now());
        // Sahiplik + canlilik KOSULU UPDATE'in icinde: eszamanli silme/kaldirma kazanirsa 0 satir -> 404
        int n = jdbc.update("UPDATE forum_comment SET body = ?, edited_at = ?, updated_at = ? WHERE id = ? AND user_id = ? "
                + "AND deleted_at IS NULL AND status = 'ACTIVE'", body, now, now, commentId, uid);
        if (n == 0) {
            throw notFound();
        }
        return assembler.assemble(uid, topic, List.of(store.find(commentId).orElseThrow())).get(0);
    }

    /** Sil (yalniz sahip). Zaten silinmisse sessizce 204 (cift dokunma). */
    public void delete(Long uid, Long commentId) {
        tx.executeWithoutResult(st -> {
            ForumCommentRow r = store.findForUpdate(commentId).orElseThrow(ForumCommentService::notFound);
            if (r.userId() != uid) {
                boolean visible = r.live() && topics.visible(r.topicId(), uid).isPresent()
                        && !hiddenAuthors(uid).contains(r.userId());
                if (!visible) {
                    throw notFound();
                }
                throw new ApiException(HttpStatus.FORBIDDEN, "FORUM_NOT_OWNER", "Bu yorumu yalnızca yazarı silebilir.");
            }
            if (r.removed() && !r.deleted()) {
                throw notFound(); // moderator kaldirmis: sahibe de gorunmez
            }
            lifecycle.deleteByOwner(r);
        });
    }

    // ---------------------------------------------------------------- okuma

    /** Ust duzey yorumlar + her birinde ilk 2 yanit onizlemesi. */
    public CommentPage list(Long viewer, Long topicId, Sort sort, String cursor, Integer size) {
        ForumCommentTopics.TopicInfo topic = topics.visible(topicId, viewer).orElseThrow(ForumCommentService::topicNotFound);
        int n = pageSize(size);
        Set<Long> hidden = hiddenAuthors(viewer);
        Sort s = sort == null ? Sort.BEST : sort;
        List<Long> ids;
        String next = null;
        switch (s) {
            case NEWEST -> {
                Long after = decodeId(cursor, 'N');
                ids = store.topIdsNewest(topicId, hidden, after, n + 1);
                if (ids.size() > n) {
                    ids = ids.subList(0, n);
                    next = enc("N|" + ids.get(n - 1));
                }
            }
            case OLDEST -> {
                Long after = decodeId(cursor, 'O');
                ids = store.topIdsOldest(topicId, hidden, after, n + 1);
                if (ids.size() > n) {
                    ids = ids.subList(0, n);
                    next = enc("O|" + ids.get(n - 1));
                }
            }
            default -> {
                long asOf = Instant.now().getEpochSecond();
                Long afterScore = null;
                Long afterId = null;
                if (cursor != null && !cursor.isBlank()) {
                    long[] c = decodeBest(cursor);
                    asOf = c[0];
                    afterScore = c[1];
                    afterId = c[2];
                }
                List<long[]> rows = store.topIdsBest(topicId, hidden, asOf, afterScore, afterId, n + 1);
                boolean more = rows.size() > n;
                List<long[]> page = more ? rows.subList(0, n) : rows;
                ids = page.stream().map(r -> r[0]).toList();
                if (more) {
                    long[] last = page.get(n - 1);
                    next = enc("B|" + asOf + "|" + last[1] + "|" + last[0]);
                }
            }
        }
        return new CommentPage(withPreviews(viewer, topic, hidden, store.findAllOrdered(ids)), next);
    }

    /** Bir yorumun dogrudan yanitlari (eskiden yeniye); her yanitta kendi ilk 2 yaniti onizlemesi. */
    public CommentPage replies(Long viewer, Long commentId, String cursor, Integer size) {
        ForumCommentRow parent = store.find(commentId).orElseThrow(ForumCommentService::notFound);
        ForumCommentTopics.TopicInfo topic = topics.visible(parent.topicId(), viewer).orElseThrow(ForumCommentService::notFound);
        Set<Long> hidden = hiddenAuthors(viewer);
        requireListed(parent, hidden);
        int n = pageSize(size);
        Long after = decodeId(cursor, 'R');
        List<Long> ids = store.replyIds(commentId, hidden, after, n + 1);
        String next = null;
        if (ids.size() > n) {
            ids = ids.subList(0, n);
            next = enc("R|" + ids.get(n - 1));
        }
        return new CommentPage(withPreviews(viewer, topic, hidden, store.findAllOrdered(ids)), next);
    }

    /** Tek yorum + ata zinciri (baglanti / bildirimden acma). */
    public CommentView get(Long viewer, Long commentId) {
        ForumCommentRow r = store.find(commentId).orElseThrow(ForumCommentService::notFound);
        ForumCommentTopics.TopicInfo topic = topics.visible(r.topicId(), viewer).orElseThrow(ForumCommentService::notFound);
        requireListed(r, hiddenAuthors(viewer));
        return assembler.assemble(viewer, topic, List.of(r)).get(0).withPath(store.ancestorPath(r));
    }

    // ---------------------------------------------------------------- begeni + kaydet

    /** Idempotent begeni (PK kisiti; eszamanli cift PUT tek begeni, sayac tek artar). */
    public LikeState like(Long uid, Long commentId) {
        ForumCommentRow r = likeable(uid, commentId);
        boolean added = false;
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                added = Boolean.TRUE.equals(tx.execute(st -> insertLike(uid, commentId)));
                break;
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (store.likeExists(uid, commentId)) {
                    added = false; // satiri ilk istek ekledi ve sayaci artirdi
                    break;
                }
                if (attempt == 2) {
                    throw e;
                }
            }
        }
        if (added) {
            try {
                topics.commentLiked(commentId, uid);
            } catch (RuntimeException e) {
                log.warn("Forum yorum begeni bildirimi atlandi (yorum {}): {}", commentId, e.toString());
            }
        }
        return new LikeState(true, store.likeCount(r.id()));
    }

    public LikeState unlike(Long uid, Long commentId) {
        likeable(uid, commentId);
        tx.executeWithoutResult(st -> {
            if (jdbc.update("DELETE FROM forum_comment_like WHERE comment_id = ? AND user_id = ?", commentId, uid) > 0) {
                counters.likes(commentId, -1);
            }
        });
        return new LikeState(false, store.likeCount(commentId));
    }

    private boolean insertLike(Long uid, Long commentId) {
        int n = jdbc.update("INSERT INTO forum_comment_like (comment_id, user_id, created_at) SELECT ?, ?, ? "
                + "WHERE NOT EXISTS (SELECT 1 FROM forum_comment_like WHERE comment_id = ? AND user_id = ?)",
                commentId, uid, Timestamp.from(Instant.now()), commentId, uid);
        if (n == 0) {
            return false;
        }
        counters.likes(commentId, 1);
        return true;
    }

    public SaveState save(Long uid, Long commentId) {
        likeable(uid, commentId);
        topics.setSaved(uid, commentId, true);
        return new SaveState(true);
    }

    public SaveState unsave(Long uid, Long commentId) {
        likeable(uid, commentId);
        topics.setSaved(uid, commentId, false);
        return new SaveState(false);
    }

    /** Canli, konusu gorunur, yazari bakandan gizli olmayan yorum (begeni/kaydet icin). */
    private ForumCommentRow likeable(Long uid, Long commentId) {
        ForumCommentRow r = store.find(commentId).orElseThrow(ForumCommentService::notFound);
        topics.visible(r.topicId(), uid).orElseThrow(ForumCommentService::notFound);
        if (!r.live() || hiddenAuthors(uid).contains(r.userId())) {
            throw notFound();
        }
        return r;
    }

    // ---------------------------------------------------------------- yardimcilar

    /** Listede olmayan / gizli yorum 404: unlisted mezar tasi, ya da canli ve yazari bakandan gizli. */
    private void requireListed(ForumCommentRow r, Set<Long> hidden) {
        if (!r.listed() || (r.live() && hidden.contains(r.userId()))) {
            throw notFound();
        }
    }

    private List<CommentView> withPreviews(Long viewer, ForumCommentTopics.TopicInfo topic, Set<Long> hidden,
                                           List<ForumCommentRow> rows) {
        if (rows.isEmpty()) {
            return List.of();
        }
        Map<Long, List<Long>> previewIds = store.previewIds(rows.stream().map(ForumCommentRow::id).toList(), hidden,
                PREVIEW_PER_COMMENT);
        List<Long> flatIds = new ArrayList<>();
        previewIds.values().forEach(flatIds::addAll);
        // Tek toplu birlestirme: ust yorumlar + onizleme yanitlari birlikte (profil/begeni sorgulari bir kez)
        List<ForumCommentRow> previewRows = store.findAllOrdered(flatIds);
        List<ForumCommentRow> all = new ArrayList<>(rows);
        all.addAll(previewRows);
        Map<Long, CommentView> byId = new java.util.HashMap<>();
        for (CommentView v : assembler.assemble(viewer, topic, all)) {
            byId.put(v.id(), v);
        }
        List<CommentView> out = new ArrayList<>(rows.size());
        for (ForumCommentRow r : rows) {
            List<CommentView> prev = new ArrayList<>();
            for (Long pid : previewIds.getOrDefault(r.id(), List.of())) {
                CommentView pv = byId.get(pid);
                if (pv != null) {
                    prev.add(pv);
                }
            }
            out.add(byId.get(r.id()).withPreview(prev));
        }
        return out;
    }

    /** Bakanin gordugu listelerden gizlenecek yazarlar: engel (iki yonlu) + sessize alma. */
    Set<Long> hiddenAuthors(Long viewer) {
        if (viewer == null) {
            return Set.of();
        }
        Set<Long> out = new HashSet<>(blocks.hiddenFrom(viewer));
        out.addAll(topics.mutedBy(viewer));
        return out;
    }

    private static int pageSize(Integer size) {
        if (size == null || size <= 0) {
            return ForumCommentDtos.DEFAULT_SIZE;
        }
        return Math.min(size, ForumCommentDtos.MAX_SIZE);
    }

    private static String enc(String s) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(s.getBytes(StandardCharsets.UTF_8));
    }

    private static String[] decode(String cursor, char kind, int parts) {
        try {
            String[] p = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split("\\|");
            if (p.length != parts || p[0].length() != 1 || p[0].charAt(0) != kind) {
                throw new IllegalArgumentException();
            }
            return p;
        } catch (RuntimeException e) {
            throw badCursor();
        }
    }

    /** Tek kimlikli imlec (N/O/R); bos imlec = ilk sayfa. */
    private static Long decodeId(String cursor, char kind) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            return Long.parseLong(decode(cursor, kind, 2)[1]);
        } catch (NumberFormatException e) {
            throw badCursor();
        }
    }

    /** EN IYI imleci: {an, puan, id}. */
    private static long[] decodeBest(String cursor) {
        String[] p = decode(cursor, 'B', 4);
        try {
            return new long[] {Long.parseLong(p[1]), Long.parseLong(p[2]), Long.parseLong(p[3])};
        } catch (NumberFormatException e) {
            throw badCursor();
        }
    }

    private static ApiException badCursor() {
        return new ApiException(HttpStatus.BAD_REQUEST, "FORUM_CURSOR_INVALID", "Geçersiz sayfa imleci.");
    }

    static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_COMMENT_NOT_FOUND", "Yorum bulunamadı.");
    }

    static ApiException topicNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_TOPIC_NOT_FOUND", "Konu bulunamadı.");
    }
}
