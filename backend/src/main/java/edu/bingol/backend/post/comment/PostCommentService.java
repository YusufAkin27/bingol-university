package edu.bingol.backend.post.comment;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCounters;
import edu.bingol.backend.post.comment.CommentDtos.AuthorView;
import edu.bingol.backend.post.comment.CommentDtos.CommentPage;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.ReplyPage;
import edu.bingol.backend.post.comment.CommentDtos.ReplyToView;
import edu.bingol.backend.post.spi.PostNotifierPort;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Gonderi yorumlari ve ic ice yanitlar (en cok 3 seviye; daha derin yanit kardes olarak eklenir).
 * comment_count (gonderi) ve reply_count (yorum) ayni islemde atomik SQL ile tutulur.
 */
@Service
public class PostCommentService {

    private static final Logger log = LoggerFactory.getLogger(PostCommentService.class);

    static final int MAX_LEN = 1000;
    static final int MAX_DEPTH = 3;
    static final int PREVIEW = 2;
    static final int MAX_PAGE = 20;
    private static final Set<Long> NONE = Set.of(-1L);

    private final PostCommentRepository comments;
    private final PostCounters counters;
    private final EntityManager em;
    private final UserRepository users;
    private final PublicProfileMapper profiles;
    private final BlockService blocks;
    private final ContentGuard guard;
    private final ObjectProvider<PostNotifierPort> notifier;

    /** Sosyal ekler: metin olayi (etiket) ve yorum etiketleri; setter: kurucu imzasi degismesin. */
    private org.springframework.context.ApplicationEventPublisher publisher;
    private ObjectProvider<edu.bingol.backend.post.spi.PostExtrasLookup> extras;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSocial(org.springframework.context.ApplicationEventPublisher publisher,
            ObjectProvider<edu.bingol.backend.post.spi.PostExtrasLookup> extras) {
        this.publisher = publisher;
        this.extras = extras;
    }

    private void textEvent(Long postId, Long commentId, Long actor, String text) {
        if (publisher != null) {
            publisher.publishEvent(new edu.bingol.backend.post.SocialTextEvent(postId, commentId, actor, text));
        }
    }

    public PostCommentService(PostCommentRepository comments, PostCounters counters, EntityManager em,
            UserRepository users, PublicProfileMapper profiles, BlockService blocks, ContentGuard guard,
            ObjectProvider<PostNotifierPort> notifier) {
        this.comments = comments;
        this.counters = counters;
        this.em = em;
        this.users = users;
        this.profiles = profiles;
        this.blocks = blocks;
        this.guard = guard;
        this.notifier = notifier;
    }

    // ---------------------------------------------------------------- yazma

    @Transactional
    public CommentView create(Long userId, Long postId, String rawText, Long parentId) {
        String text = normalize(rawText);
        Post post = visiblePost(userId, postId);
        guard.assertClean(ContentGuard.Entity.POST, "text", userId, text);

        PostComment c = new PostComment();
        c.setPostId(postId);
        c.setAuthorId(userId);
        c.setBody(text);
        Long notifyParentAuthor = null;
        Long notifyReplyTo = null;
        Long counterParentId = null;
        if (parentId == null) {
            c.setDepth((short) 0);
        } else {
            PostComment parent = comments.findById(parentId).orElseThrow(this::parentInvalid);
            if (!parent.getPostId().equals(postId) || !parent.isListed() || parent.getDeletedAt() != null
                    || blocks.hiddenFrom(userId).contains(parent.getAuthorId())) {
                throw parentInvalid();
            }
            PostComment effective = parent;
            if (parent.getDepth() >= MAX_DEPTH) {
                // en fazla 3 seviye: ebeveynin kardesi olarak ekle
                effective = comments.findById(parent.getParentId()).orElseThrow(this::parentInvalid);
            }
            c.setParentId(effective.getId());
            c.setRootId(effective.getRootId());
            c.setDepth((short) (effective.getDepth() + 1));
            c.setReplyToUserId(parent.getAuthorId());
            counterParentId = effective.getId();
            notifyParentAuthor = effective.getAuthorId();
            notifyReplyTo = parent.getAuthorId();
        }
        c = comments.saveAndFlush(c);
        if (parentId == null) {
            c.setRootId(c.getId());
            comments.saveAndFlush(c);
        }
        textEvent(postId, c.getId(), userId, text);
        counters.incrementComments(postId, 1);
        if (counterParentId != null) {
            comments.addReplies(counterParentId, 1);
        }
        final Long cid = c.getId();
        final Long pa = notifyParentAuthor;
        final Long rt = notifyReplyTo;
        final boolean reply = parentId != null;
        afterCommit(() -> {
            PostNotifierPort n = notifier.getIfAvailable();
            if (n == null) {
                return;
            }
            if (reply) {
                n.onReply(userId, postId, cid, pa, rt);
            } else {
                n.onComment(userId, postId, post.getAuthorId(), cid);
            }
        });
        PostComment saved = comments.findById(cid).orElseThrow();
        return views(userId, false, post.getAuthorId(), List.of(saved), false).get(0);
    }

    @Transactional
    public CommentView update(Long userId, Long commentId, String rawText, boolean admin) {
        String text = normalize(rawText);
        PostComment c = comments.findById(commentId).orElseThrow(this::notFound);
        if (c.getDeletedAt() != null || c.getHiddenAt() != null) {
            throw notFound();
        }
        Post post = em.find(Post.class, c.getPostId());
        if (post == null || !post.isVisible()) {
            throw notFound();
        }
        if (!c.getAuthorId().equals(userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "COMMENT_FORBIDDEN", "Bu yorumu düzenleme yetkiniz yok.");
        }
        guard.assertChanged(ContentGuard.Entity.POST, "text", userId, c.getBody(), text);
        c.setBody(text);
        c.setEditedAt(Instant.now());
        comments.save(c);
        textEvent(post.getId(), c.getId(), userId, text);
        return views(userId, admin, post.getAuthorId(), List.of(c), false).get(0);
    }

    @Transactional
    public void delete(Long userId, Long commentId, boolean admin) {
        PostComment c = comments.findById(commentId).orElseThrow(this::notFound);
        if (c.getDeletedAt() != null) {
            throw notFound();
        }
        Post post = em.find(Post.class, c.getPostId());
        Long postAuthor = post == null ? null : post.getAuthorId();
        boolean allowed = admin || c.getAuthorId().equals(userId) || userId.equals(postAuthor);
        if (!allowed) {
            throw new ApiException(HttpStatus.FORBIDDEN, "COMMENT_FORBIDDEN", "Bu yorumu silme yetkiniz yok.");
        }
        remove(c, userId);
    }

    /** Hesap silme (E cagirir): yazarin tum yorumlari "silindi" olur / yanitsizsa kalkar, sayaclar duser. */
    @Transactional
    public int purgeUser(Long userId) {
        List<Long> ids = comments.liveByAuthor(userId).stream().map(PostComment::getId).toList();
        int n = 0;
        for (Long id : ids) { // derin olan once: alt yanitlar kalkinca ust yorum da yanitsiz kalabilir
            PostComment c = comments.findById(id).orElse(null);
            if (c != null && c.getDeletedAt() == null) {
                remove(c, userId);
                n++;
            }
        }
        return n;
    }

    /** Yorumu siler; yaniti varsa "silindi" kaydi kalir. */
    private void remove(PostComment c, Long actor) {
        Long id = c.getId();
        Long postId = c.getPostId();
        Long parentId = c.getParentId();
        boolean leaf = c.getReplyCount() <= 0;
        c.setDeletedAt(Instant.now());
        c.setDeletedBy(actor);
        c.setBody(null);
        comments.saveAndFlush(c);
        counters.incrementComments(postId, -1);
        if (leaf) {
            detachFromParents(parentId);
        }
        log.debug("comment {} deleted by {} leaf={}", id, actor, leaf);
    }

    /** Yaprak yorum kalkinca ebeveynin reply_count'u duser; ebeveyn "silindi" ve yanitsiz kaldiysa zincir yukari. */
    private void detachFromParents(Long parentId) {
        Long p = parentId;
        while (p != null) {
            comments.addReplies(p, -1);
            PostComment parent = comments.findById(p).orElse(null);
            if (parent != null && parent.getDeletedAt() != null && parent.getReplyCount() <= 0) {
                p = parent.getParentId();
            } else {
                break;
            }
        }
    }

    // ---------------------------------------------------------------- okuma

    @Transactional(readOnly = true)
    public CommentPage list(Long viewerId, Long postId, String sort, String cursor, int size, boolean admin) {
        Post post = visiblePost(viewerId, postId);
        int n = clamp(size);
        Set<Long> hidden = hiddenSet(viewerId);
        boolean top = "top".equalsIgnoreCase(sort);
        PageRequest page = PageRequest.of(0, n + 1);
        String[] cur = parseCursor(cursor, top ? 4 : 3);
        List<PostComment> rows;
        if (top) {
            rows = cur == null ? comments.rootsTop(postId, hidden, page)
                    : comments.rootsTopAfter(postId, hidden, Integer.parseInt(cur[1]), Instant.parse(cur[2]),
                            Long.parseLong(cur[3]), page);
        } else {
            rows = cur == null ? comments.rootsNew(postId, hidden, page)
                    : comments.rootsNewAfter(postId, hidden, Instant.parse(cur[1]), Long.parseLong(cur[2]), page);
        }
        boolean more = rows.size() > n;
        List<PostComment> pageRows = more ? new ArrayList<>(rows.subList(0, n)) : rows;
        String next = more ? cursorOf(pageRows.get(pageRows.size() - 1), top) : null;
        return new CommentPage(views(viewerId, admin, post.getAuthorId(), pageRows, true), next, post.getCommentCount());
    }

    @Transactional(readOnly = true)
    public ReplyPage replies(Long viewerId, Long commentId, String cursor, int size, boolean admin) {
        PostComment parent = comments.findById(commentId).orElseThrow(this::notFound);
        if (!parent.isListed()) {
            throw notFound();
        }
        Post post = visiblePost(viewerId, parent.getPostId());
        int n = clamp(size);
        Set<Long> hidden = hiddenSet(viewerId);
        PageRequest page = PageRequest.of(0, n + 1);
        String[] cur = parseCursor(cursor, 3);
        List<PostComment> rows = cur == null ? comments.replies(commentId, hidden, page)
                : comments.repliesAfter(commentId, hidden, Instant.parse(cur[1]), Long.parseLong(cur[2]), page);
        boolean more = rows.size() > n;
        List<PostComment> pageRows = more ? new ArrayList<>(rows.subList(0, n)) : rows;
        String next = more ? cursorOf(pageRows.get(pageRows.size() - 1), false) : null;
        return new ReplyPage(views(viewerId, admin, post.getAuthorId(), pageRows, false), next);
    }

    // ---------------------------------------------------------------- yardimcilar

    private List<CommentView> views(Long viewerId, boolean admin, Long postAuthorId, List<PostComment> rows,
            boolean withPreview) {
        Map<Long, List<PostComment>> previews = new HashMap<>();
        if (withPreview && !rows.isEmpty()) {
            List<Long> rootIds = rows.stream().map(PostComment::getId).toList();
            List<Long> ids = comments.previewIds(rootIds, hiddenSet(viewerId), PREVIEW);
            Map<Long, PostComment> byId = new HashMap<>();
            comments.findAllById(ids).forEach(c -> byId.put(c.getId(), c));
            for (Long id : ids) { // previewIds sirali (parent, created_at, id)
                PostComment c = byId.get(id);
                if (c != null) {
                    previews.computeIfAbsent(c.getParentId(), k -> new ArrayList<>()).add(c);
                }
            }
        }
        Set<Long> userIds = new LinkedHashSet<>();
        for (PostComment c : rows) {
            collect(c, userIds);
            for (PostComment r : previews.getOrDefault(c.getId(), List.of())) {
                collect(r, userIds);
            }
        }
        Map<Long, User> userMap = new HashMap<>();
        users.findAllById(userIds).forEach(u -> userMap.put(u.getId(), u));
        Map<Long, PublicProfile> prof = new HashMap<>();
        for (PublicProfile p : profiles.mapAll(viewerId, new ArrayList<>(userMap.values()))) {
            prof.put(p.id(), p);
        }
        Map<Long, List<edu.bingol.backend.post.PostDtos.MentionView>> mentions = new HashMap<>();
        if (extras != null) {
            List<Long> cids = new ArrayList<>();
            for (PostComment c : rows) {
                cids.add(c.getId());
                previews.getOrDefault(c.getId(), List.of()).forEach(r -> cids.add(r.getId()));
            }
            extras.orderedStream().forEach(l -> mentions.putAll(l.commentMentions(viewerId, cids)));
        }
        List<CommentView> out = new ArrayList<>();
        for (PostComment c : rows) {
            List<CommentView> pv = null;
            if (withPreview) {
                pv = previews.getOrDefault(c.getId(), List.of()).stream()
                        .map(r -> toView(r, viewerId, admin, postAuthorId, prof, userMap, null, mentions)).toList();
            }
            out.add(toView(c, viewerId, admin, postAuthorId, prof, userMap, pv, mentions));
        }
        return out;
    }

    private static void collect(PostComment c, Set<Long> ids) {
        ids.add(c.getAuthorId());
        if (c.getReplyToUserId() != null) {
            ids.add(c.getReplyToUserId());
        }
    }

    private CommentView toView(PostComment c, Long viewerId, boolean admin, Long postAuthorId,
            Map<Long, PublicProfile> prof, Map<Long, User> userMap, List<CommentView> preview,
            Map<Long, List<edu.bingol.backend.post.PostDtos.MentionView>> mentions) {
        boolean deleted = c.getDeletedAt() != null;
        boolean mine = c.getAuthorId().equals(viewerId);
        AuthorView author = null;
        if (!deleted) {
            PublicProfile p = prof.get(c.getAuthorId());
            User u = userMap.get(c.getAuthorId());
            author = new AuthorView(c.getAuthorId(), p != null ? p.displayName() : u != null ? u.getDisplayName() : null,
                    p != null ? p.avatarUrl() : null);
        }
        ReplyToView rt = null;
        if (c.getReplyToUserId() != null) {
            User u = userMap.get(c.getReplyToUserId());
            rt = new ReplyToView(c.getReplyToUserId(), u != null ? u.getDisplayName() : null);
        }
        boolean canDelete = !deleted && (admin || mine || viewerId.equals(postAuthorId));
        return new CommentView(c.getId(), c.getPostId(), c.getParentId(), c.getRootId(), c.getDepth(), author, rt,
                deleted ? null : c.getBody(), deleted, c.getReplyCount(), mine, mine && !deleted, canDelete,
                c.getCreatedAt(), c.getEditedAt(), preview, deleted ? List.of() : mentions.getOrDefault(c.getId(), List.of()));
    }

    private Post visiblePost(Long viewerId, Long postId) {
        Post p = em.find(Post.class, postId);
        if (p == null || !p.isVisible() || blocks.hiddenFrom(viewerId).contains(p.getAuthorId())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
        return p;
    }

    private Set<Long> hiddenSet(Long viewerId) {
        Set<Long> h = blocks.hiddenFrom(viewerId);
        return h == null || h.isEmpty() ? NONE : h;
    }

    private String normalize(String raw) {
        String t = raw == null ? "" : raw.strip();
        if (t.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "COMMENT_EMPTY", "Yorum boş olamaz.");
        }
        if (t.length() > MAX_LEN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "COMMENT_TOO_LONG",
                    "Yorum en fazla {0} karakter olabilir.", String.valueOf(MAX_LEN));
        }
        return t;
    }

    private ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
    }

    private ApiException parentInvalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "COMMENT_PARENT_INVALID", "Yanıtlanan yorum geçerli değil.");
    }

    private static int clamp(int size) {
        return Math.min(Math.max(size, 1), MAX_PAGE);
    }

    private static String cursorOf(PostComment c, boolean top) {
        return top ? "t|" + c.getReplyCount() + "|" + c.getCreatedAt() + "|" + c.getId()
                : "n|" + c.getCreatedAt() + "|" + c.getId();
    }

    private static ApiException badCursor() {
        return new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
    }

    /** Bozuk/uyumsuz imlec 400 POST_CURSOR_INVALID. */
    private static String[] parseCursor(String cursor, int parts) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        String[] p = cursor.split("\\|");
        if (p.length != parts) {
            throw badCursor();
        }
        try {
            if (parts == 4) {
                Integer.parseInt(p[1]);
                Instant.parse(p[2]);
                Long.parseLong(p[3]);
            } else {
                Instant.parse(p[1]);
                Long.parseLong(p[2]);
            }
        } catch (RuntimeException e) {
            throw badCursor();
        }
        return p;
    }

    private static void afterCommit(Runnable r) {
        Runnable safe = () -> {
            try {
                r.run();
            } catch (RuntimeException e) {
                log.warn("comment notification failed: {}", e.toString());
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    safe.run();
                }
            });
        } else {
            safe.run();
        }
    }
}
