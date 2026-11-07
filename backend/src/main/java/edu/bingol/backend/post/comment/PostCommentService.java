package edu.bingol.backend.post.comment;

import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.comment.CommentDtos.CommentAuthor;
import edu.bingol.backend.post.comment.CommentDtos.CommentPage;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.CreateCommentRequest;
import edu.bingol.backend.post.comment.CommentDtos.LikeState;
import edu.bingol.backend.post.comment.CommentDtos.ReplyTo;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Gonderi/reel yorumlari (KS-BE2): ust duzey yorum + tek seviye yanit, yorum begenisi, silme. Gorunurluk gonderinin
 * gorunurlugunu izler (PostService.requireVisible: gizli hesap, engel, silinmis/gizli gonderi = 404); yorum yazari
 * aktif ve bakanla arada engel yok. Metin en cok 300 karakter, ContentGuard (uygunsuz ifade) uygulanir. Sayaclar atomik.
 */
@Service
public class PostCommentService {

    private static final Logger log = LoggerFactory.getLogger(PostCommentService.class);

    static final int DEFAULT_SIZE = 20;
    static final int MAX_SIZE = 50;
    static final int DEFAULT_REPLY_SIZE = 10;

    private final PostCommentRepository comments;
    private final PostCommentLikeRepository likes;
    private final PostService posts;
    private final PostRepository postRepo;
    private final UserRepository users;
    private final UserBlockRepository blocks;
    private final PublicProfileMapper profiles;
    private final ContentGuard guard;
    private final CommentNotifier notifier;
    private final CommentCounters counters;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public PostCommentService(PostCommentRepository comments, PostCommentLikeRepository likes, PostService posts,
                              PostRepository postRepo, UserRepository users, UserBlockRepository blocks, PublicProfileMapper profiles,
                              ContentGuard guard, CommentNotifier notifier, CommentCounters counters,
                              JdbcTemplate jdbc, PlatformTransactionManager tm) {
        this.comments = comments;
        this.likes = likes;
        this.posts = posts;
        this.postRepo = postRepo;
        this.users = users;
        this.blocks = blocks;
        this.profiles = profiles;
        this.guard = guard;
        this.notifier = notifier;
        this.counters = counters;
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
    }

    // ---------------------------------------------------------------- yazma

    /** Yorum ya da yanit ekler. parentId = yanitlanan yorum (yanita yanit ust duzey yoruma yassilanir). */
    @Transactional
    public CommentView create(Long uid, Long postId, CreateCommentRequest req) {
        Post post = visiblePost(postId, uid);
        String text = normalize(req.text());
        checkText(text);
        guard.assertClean(ContentGuard.Entity.COMMENT, "text", uid, text);
        PostComment root = null;
        if (req.parentId() != null) {
            // parentId yalniz ayni gonderideki gorunur UST DUZEY yorum olabilir (yanita yanit yok)
            try {
                root = visibleComment(req.parentId(), uid);
            } catch (ApiException e) {
                throw parentInvalid();
            }
            if (!root.getPostId().equals(postId) || root.isReply()) {
                throw parentInvalid();
            }
        }
        PostComment c = new PostComment();
        c.setPostId(postId);
        c.setAuthorId(uid);
        c.setBody(text);
        if (root != null) {
            c.setParentId(root.getId());
            c.setReplyToId(root.getId());
        }
        c = comments.saveAndFlush(c);
        counters.addToPost(postId, 1);
        if (root != null) {
            counters.addReplies(root.getId(), 1);
        }
        final PostComment saved = c;
        // Bildirim COMMIT sonrasi degil ayni islemde en iyi cabayla gider; hata islemi bozmaz (notifier yutar)
        if (root == null) {
            notifier.onComment(uid, postId, post.getAuthorId(), saved.getId());
        } else {
            notifier.onReply(uid, postId, post.getAuthorId(), saved.getId(), root.getAuthorId());
        }
        return assemble(uid, post, List.of(saved)).get(0);
    }

    /**
     * Yorum silme: yorumun yazari, gonderinin sahibi ya da (CONTENT_HIDE izinli) yonetici. Ust duzey yorumun silinmesi
     * yanitlarini da kaldirir. Metin temizlenir (KVKK), satir iz olarak kalir.
     */
    @Transactional
    public void delete(Long actorId, Long commentId, boolean adminOverride) {
        PostComment c = comments.findById(commentId).filter(x -> x.getDeletedAt() == null).orElseThrow(PostCommentService::notFound);
        Post post = postRepo.findById(c.getPostId()).orElseThrow(PostCommentService::notFound);
        boolean allowed = adminOverride || c.getAuthorId().equals(actorId) || post.getAuthorId().equals(actorId);
        if (!allowed) {
            visibleComment(commentId, actorId); // goremiyorsa 404, goruyorsa 403
            throw new ApiException(HttpStatus.FORBIDDEN, "COMMENT_FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        boolean wasVisible = c.getHiddenAt() == null;
        // Ust duzey yorum silinince yanitlari KALIR: yanit varsa listede tombstone (deleted:true) olarak durur,
        // yoksa listeden kalkar (TOP_LEVEL replyCount > 0 kosulu). Gonderi sayaci yalniz bu yorumu dusurur.
        if (c.isReply() && wasVisible) {
            counters.addReplies(c.getParentId(), -1);
        }
        jdbc.update("UPDATE post_comment SET deleted_at = CURRENT_TIMESTAMP, deleted_by = ?, body = '' "
                + "WHERE id = ? AND deleted_at IS NULL", actorId, commentId);
        if (wasVisible) {
            counters.addToPost(c.getPostId(), -1);
        }
    }

    // ---------------------------------------------------------------- okuma

    /** Ust duzey yorumlar. sort: top (begeni, sonra yeni; varsayilan) | new. */
    @Transactional(readOnly = true)
    public CommentPage list(Long viewer, Long postId, String sort, String cursor, int size) {
        Post post = visiblePost(postId, viewer);
        boolean top = parseSort(sort);
        int n = size <= 0 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        PageRequest page = PageRequest.of(0, n + 1);
        List<PostComment> rows;
        if (top) {
            long[] c = decodeTop(cursor);
            rows = c == null ? comments.topFirst(postId, viewer, page)
                    : comments.topAfter(postId, viewer, (int) c[0], c[1], page);
        } else {
            Long c = decodeNew(cursor, 'N');
            rows = c == null ? comments.newestFirst(postId, viewer, page) : comments.newestAfter(postId, viewer, c, page);
        }
        boolean more = rows.size() > n;
        List<PostComment> items = more ? rows.subList(0, n) : rows;
        String next = null;
        if (more) {
            PostComment last = items.get(items.size() - 1);
            next = top ? enc("T|" + last.getLikeCount() + "|" + last.getId()) : enc("N|" + last.getId());
        }
        return new CommentPage(assemble(viewer, post, items), next, post.getCommentCount());
    }

    /** Bir yorumun yanitlari (eskiden yeniye). */
    @Transactional(readOnly = true)
    public CommentPage replies(Long viewer, Long commentId, String cursor, int size) {
        PostComment parent = comments.findById(commentId).filter(x -> x.getDeletedAt() != null && x.getReplyCount() > 0
                && x.getHiddenAt() == null && !x.isReply()).orElse(null); // tombstone: yanitlari hala okunur
        if (parent == null) {
            parent = visibleComment(commentId, viewer);
        }
        if (parent.isReply()) {
            throw notFound(); // yanitlarin yaniti yoktur (yassilanir)
        }
        Post post = visiblePost(parent.getPostId(), viewer);
        int n = size <= 0 ? DEFAULT_REPLY_SIZE : Math.min(size, MAX_SIZE);
        PageRequest page = PageRequest.of(0, n + 1);
        Long c = decodeNew(cursor, 'R');
        List<PostComment> rows = c == null ? comments.repliesFirst(commentId, viewer, page)
                : comments.repliesAfter(commentId, viewer, c, page);
        boolean more = rows.size() > n;
        List<PostComment> items = more ? rows.subList(0, n) : rows;
        String next = more ? enc("R|" + items.get(items.size() - 1).getId()) : null;
        return new CommentPage(assemble(viewer, post, items), next, parent.getReplyCount());
    }

    @Transactional(readOnly = true)
    public CommentView get(Long viewer, Long commentId) {
        PostComment c = visibleComment(commentId, viewer);
        Post post = visiblePost(c.getPostId(), viewer);
        return assemble(viewer, post, List.of(c)).get(0);
    }

    // ---------------------------------------------------------------- begeni

    /** Idempotent begeni; yorum gorunur degilse 404. */
    public LikeState like(Long userId, Long commentId) {
        PostComment target = visibleComment(commentId, userId);
        boolean[] added = {false};
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                tx.executeWithoutResult(st -> added[0] = insertLike(userId, commentId));
                break;
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (likeExists(userId, commentId)) {
                    break; // es zamanli cift PUT: satiri ilk istek ekledi, sayaci o artirdi
                }
                if (attempt == 2) {
                    throw e;
                }
            }
        }
        if (added[0]) {
            notifier.onLike(userId, target.getPostId(), commentId, target.getAuthorId());
        }
        return new LikeState(true, counters.likeCount(commentId));
    }

    public LikeState unlike(Long userId, Long commentId) {
        visibleComment(commentId, userId);
        tx.executeWithoutResult(st -> {
            if (likes.deleteLike(commentId, userId) > 0) {
                counters.addLikes(commentId, -1);
            }
        });
        return new LikeState(false, counters.likeCount(commentId));
    }

    private boolean insertLike(Long userId, Long commentId) {
        int n = jdbc.update("INSERT INTO post_comment_like (comment_id, user_id, created_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM post_comment_like WHERE comment_id = ? AND user_id = ?)",
                commentId, userId, commentId, userId);
        if (n > 0) {
            counters.addLikes(commentId, 1);
        }
        return n > 0;
    }

    private boolean likeExists(Long userId, Long commentId) {
        Integer c = jdbc.queryForObject("SELECT COUNT(*) FROM post_comment_like WHERE comment_id = ? AND user_id = ?",
                Integer.class, commentId, userId);
        return c != null && c > 0;
    }

    // ---------------------------------------------------------------- gorunurluk + birlestirme

    /** Gonderi bakana gorunurse; degilse 404 COMMENT_NOT_FOUND (gizli/silinmis/engelli/gizli hesap gonderisi). */
    private Post visiblePost(Long postId, Long viewer) {
        try {
            return posts.requireVisible(postId, viewer);
        } catch (ApiException e) {
            if ("POST_NOT_FOUND".equals(e.code())) {
                throw notFound();
            }
            throw e;
        }
    }

    /** Yorum bakana gorunur mu: silinmemis, gizlenmemis, yazar aktif, arada engel yok (kendi yorumu her zaman). */
    PostComment visibleComment(Long commentId, Long viewer) {
        PostComment c = comments.findById(commentId).filter(PostComment::isVisible).orElseThrow(PostCommentService::notFound);
        if (!c.getAuthorId().equals(viewer)) {
            boolean active = users.findById(c.getAuthorId()).map(u -> u.getStatus() == UserStatus.ACTIVE).orElse(false);
            if (!active || blocks.existsBetween(viewer, c.getAuthorId())) {
                throw notFound();
            }
        }
        if (c.isReply()) {
            // ust yorum silinmis olabilir (tombstone); gizliyse yanit da gorunmez
            comments.findById(c.getParentId()).filter(x -> x.getHiddenAt() == null).orElseThrow(PostCommentService::notFound);
        }
        return c;
    }

    /** Toplu CommentView: yazar profili (gizlilik+engel), begeni durumu, yanitlanan kisi (N+1'siz). */
    List<CommentView> assemble(Long viewer, Post post, List<PostComment> rows) {
        if (rows.isEmpty()) {
            return List.of();
        }
        List<Long> ids = rows.stream().map(PostComment::getId).toList();
        // Silinmis (tombstone) satirlarin yazari yuklenmez/gosterilmez
        Set<Long> authorIds = rows.stream().filter(PostComment::isVisible).map(PostComment::getAuthorId)
                .collect(Collectors.toCollection(HashSet::new));
        List<User> authors = users.findAllById(authorIds);
        Map<Long, PublicProfile> byId = profiles.mapAll(viewer, authors).stream()
                .collect(Collectors.toMap(PublicProfile::id, Function.identity(), (a, b) -> a));
        Map<Long, String> usernames = new HashMap<>();
        for (User u : authors) {
            usernames.put(u.getId(), u.getUsername());
        }
        Set<Long> liked = new HashSet<>(comments.likedAmong(viewer, ids));
        boolean admin = CurrentUser.hasAdminPermission(PermissionMatrix.CONTENT_HIDE);
        boolean postOwner = post.getAuthorId().equals(viewer);
        List<CommentView> out = new ArrayList<>(rows.size());
        for (PostComment c : rows) {
            if (!c.isVisible()) {
                // tombstone: govde/yazar yok, etkilesim yok
                out.add(new CommentView(c.getId(), c.getPostId(), c.getParentId(), null, null, 0, false,
                        c.getReplyCount(), c.getCreatedAt(), false, false, false, null, null, true));
                continue;
            }
            PublicProfile a = byId.get(c.getAuthorId());
            CommentAuthor author = a == null ? new CommentAuthor(c.getAuthorId(), "", null, null, c.getAuthorId(), null)
                    : new CommentAuthor(a.id(), a.displayName(), a.avatarUrl(), a.department(), a.id(),
                            usernames.get(a.id()));
            boolean mine = c.getAuthorId().equals(viewer);
            out.add(new CommentView(c.getId(), c.getPostId(), c.getParentId(), author, c.getBody(), c.getLikeCount(),
                    liked.contains(c.getId()), c.getReplyCount(), c.getCreatedAt(), mine,
                    c.getAuthorId().equals(post.getAuthorId()), mine || postOwner || admin, null, c.getBody(), false));
        }
        return out;
    }

    // ---------------------------------------------------------------- metin + imlec

    /** Bas/son bosluk, CRLF, kontrol karakterleri ve 3+ ardisik satir sonu temizlenir; bos = null. */
    static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        String t = raw.replace("\r\n", "\n").replace('\r', '\n').replaceAll("[\\p{Cc}&&[^\\n]]", "");
        t = t.replaceAll("^[\\s\\p{Z}]+|[\\s\\p{Z}]+$", "").replaceAll("\\n{3,}", "\n\n");
        return t.isEmpty() ? null : t;
    }

    static void checkText(String text) {
        if (text == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "COMMENT_EMPTY", "Yorum boş olamaz.");
        }
        if (text.codePointCount(0, text.length()) > CommentDtos.MAX_CHARS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COMMENT_TOO_LONG",
                    "Yorum en çok " + CommentDtos.MAX_CHARS + " karakter olabilir.", String.valueOf(CommentDtos.MAX_CHARS));
        }
    }

    private static boolean parseSort(String sort) {
        if (sort == null || sort.isBlank() || "top".equalsIgnoreCase(sort)) {
            return true;
        }
        if ("new".equalsIgnoreCase(sort)) {
            return false;
        }
        throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sıralama.");
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
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    /** top imleci: {begeni, id}; bos imlec null. */
    private static long[] decodeTop(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        String[] p = decode(cursor, 'T', 3);
        try {
            return new long[] {Long.parseLong(p[1]), Long.parseLong(p[2])};
        } catch (NumberFormatException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    private static Long decodeNew(String cursor, char kind) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        String[] p = decode(cursor, kind, 2);
        try {
            return Long.parseLong(p[1]);
        } catch (NumberFormatException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }

    private static ApiException parentInvalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "COMMENT_PARENT_INVALID",
                "Yanıtlanacak yorum geçersiz.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
    }

}
