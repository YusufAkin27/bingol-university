package edu.bingol.backend.forum.moderation;

import org.springframework.stereotype.Component;

/** GECICI: B yorum durum servisi yayinlaninca ona baglanir. */
@Component
class ForumCommentStatesImpl implements ForumCommentStates {

    @Override
    public void remove(Long commentId, String reason) {
        throw new IllegalStateException("Forum yorum durum servisi (B) bagli degil");
    }

    @Override
    public void restore(Long commentId) {
        throw new IllegalStateException("Forum yorum durum servisi (B) bagli degil");
    }
}
