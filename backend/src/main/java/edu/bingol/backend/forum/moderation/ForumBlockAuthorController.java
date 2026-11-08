package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.moderation.ForumContentLookup.CommentRow;
import edu.bingol.backend.forum.moderation.ForumContentLookup.TopicRow;
import edu.bingol.backend.moderation.BlockService;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * "Yazari engelle" (konu/yorum uzerinden). ANONIM olmayan icerikte sunucu yazari cozer ve global
 * {@link BlockService} engelini ekler. ANONIM icerikte global engel YAZILMAZ (GET /api/users/me/blocks yazari ifsa
 * ederdi; yazarin bizi engellemis olmasi da 404 ile oracle olurdu): istek idempotent no-op olarak ayni genel
 * {@code {blocked:true}} yanitini doner (anonim yazar sessize alma da listede gorunecegi icin kullanilmaz).
 * Gorunmeyen icerik (silinmis/kaldirilmis) olmayanla ayni 404 verir.
 */
@RestController
@RequestMapping("/api/forum")
public class ForumBlockAuthorController {

    private final ForumContentLookup content;
    private final BlockService blocks;
    private final RateLimiter limiter;

    public ForumBlockAuthorController(ForumContentLookup content, BlockService blocks, RateLimiter limiter) {
        this.content = content;
        this.blocks = blocks;
        this.limiter = limiter;
    }

    @PostMapping("/topics/{id}/block-author")
    public Map<String, Boolean> blockTopicAuthor(@PathVariable Long id) {
        Long me = CurrentUser.id();
        limiter.check("fblockauthor:" + me, 60, Duration.ofHours(1));
        TopicRow t = content.topic(id).filter(TopicRow::active).orElseThrow(ForumBlockAuthorController::notFound);
        return blockVisibleAuthor(me, t.userId(), t.anonymous());
    }

    @PostMapping("/comments/{id}/block-author")
    public Map<String, Boolean> blockCommentAuthor(@PathVariable Long id) {
        Long me = CurrentUser.id();
        limiter.check("fblockauthor:" + me, 60, Duration.ofHours(1));
        CommentRow c = content.comment(id).filter(CommentRow::active).orElseThrow(ForumBlockAuthorController::notFound);
        // yorum, aktif bir konunun altinda olmali (kaldirilmis konunun yorumu da gorunmez)
        content.topic(c.topicId()).filter(TopicRow::active).orElseThrow(ForumBlockAuthorController::notFound);
        return blockVisibleAuthor(me, c.userId(), c.anonymous());
    }

    private Map<String, Boolean> blockVisibleAuthor(Long me, Long author, boolean anonymous) {
        if (me.equals(author)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_CANNOT_BLOCK_SELF", "Kendinizi engelleyemezsiniz.");
        }
        if (anonymous) {
            return Map.of("blocked", true); // kimlik/engel durumu hicbir sekilde yansimaz
        }
        // yazar hesabi pasifse ya da bizi engellemisse icerigi zaten goremeyiz: olmayanla ayni 404
        if (!content.userActive(author) || blocks.hasBlocked(author, me)) {
            throw notFound();
        }
        blocks.block(me, author);
        return Map.of("blocked", true);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_MOD_TARGET_NOT_FOUND", "İçerik bulunamadı.");
    }
}
