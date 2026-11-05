package edu.bingol.backend.forum.comment;

import edu.bingol.backend.forum.comment.spi.ForumCommentLookup;
import edu.bingol.backend.forum.comment.spi.ForumCommentStateService;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/** D'nin moderasyon alani icin durum gecisleri + salt okunur arama SPI'i (B uygular). */
@Service
class ForumCommentStateServiceImpl implements ForumCommentStateService, ForumCommentLookup {

    private final ForumCommentStore store;
    private final ForumCommentLifecycle lifecycle;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    ForumCommentStateServiceImpl(ForumCommentStore store, ForumCommentLifecycle lifecycle, JdbcTemplate jdbc,
                                 PlatformTransactionManager tm) {
        this.store = store;
        this.lifecycle = lifecycle;
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
    }

    @Override
    public void remove(Long commentId, String reason) {
        tx.executeWithoutResult(st -> lifecycle.remove(
                store.findForUpdate(commentId).orElseThrow(ForumCommentService::notFound), reason));
    }

    @Override
    public void restore(Long commentId) {
        tx.executeWithoutResult(st -> lifecycle.restore(
                store.findForUpdate(commentId).orElseThrow(ForumCommentService::notFound)));
    }

    @Override
    public Optional<CommentRef> find(Long commentId) {
        if (commentId == null) {
            return Optional.empty();
        }
        return store.find(commentId).map(r -> {
            Long parentAuthor = null;
            if (r.parentId() != null) {
                var ids = jdbc.queryForList("SELECT user_id FROM forum_comment WHERE id = ?", Long.class, r.parentId());
                parentAuthor = ids.isEmpty() ? null : ids.get(0);
            }
            return new CommentRef(r.id(), r.topicId(), r.userId(), r.parentId(), parentAuthor, r.depth(), r.anonymous(),
                    r.removed(), r.deleted());
        });
    }
}
