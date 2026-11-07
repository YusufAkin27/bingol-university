package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.forum.comment.spi.ForumCommentCreateGuard;
import edu.bingol.backend.forum.moderation.spi.ForumSpamGuard;
import org.springframework.stereotype.Component;

/**
 * B'nin yorum olusturma kancasini D'nin tekrar-icerik korumasina baglar: ayni kullanici ayni metni 10 dk icinde
 * ikinci kez gonderirse 429 {@code FORUM_DUPLICATE_CONTENT}. Kisa metinlerde anahtara konu eklenir (bkz. {@link ForumSpamGuard}).
 */
@Component
class ForumCommentSpamGuard implements ForumCommentCreateGuard {

    private final ForumSpamGuard spam;

    ForumCommentSpamGuard(ForumSpamGuard spam) {
        this.spam = spam;
    }

    @Override
    public void beforeCreate(Long userId, Long topicId, String body) {
        spam.assertNotDuplicate(userId, ForumSpamGuard.SCOPE_COMMENT, topicId, body);
    }

    @Override
    public void onCreateFailed(Long userId, Long topicId, String body) {
        spam.forget(userId, ForumSpamGuard.SCOPE_COMMENT, topicId, body);
    }
}
