package edu.bingol.backend.forum.comment;

import edu.bingol.backend.forum.profile.ForumProfileComments;
import java.util.Collection;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * E'nin profil/kaydedilenler yorum satirlari kosum noktasi ({@link ForumProfileComments}) icin B tarafi adaptoru:
 * gorunurluk kurali ({@link ForumCommentService#viewsFor}) yorum modulunde tek yerde kalir.
 */
@Component
class ForumProfileCommentsAdapter implements ForumProfileComments {

    private final ForumCommentService comments;

    ForumProfileCommentsAdapter(ForumCommentService comments) {
        this.comments = comments;
    }

    @Override
    public Map<Long, Object> views(Collection<Long> commentIds, Long viewerId) {
        return Map.copyOf(comments.viewsFor(commentIds, viewerId));
    }
}
