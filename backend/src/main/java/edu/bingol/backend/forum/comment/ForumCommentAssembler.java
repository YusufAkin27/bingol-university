package edu.bingol.backend.forum.comment;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentView;
import edu.bingol.backend.forum.topic.dto.Author;
import edu.bingol.backend.forum.topic.spi.ForumAuthorResolver;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * Satir -> CommentView. Toplu (N+1 yok): yazarlar A'nin {@link ForumAuthorResolver}'i ile tek seferde (anonimlik,
 * takma ad ve gizlilik kurali TEK yerde), begeni/kaydet durumu birer sorgu. Anonim yorumda gercek kimlik (userId, ad,
 * avatar, bolum) HICBIR alanda donmez; `topicAuthor` anonim konuda yalniz YORUM DA ANONIMSE doner (kimlikli yorum
 * "Yazar" etiketi tasirsa anonim konu sahibi aciga cikardi).
 */
@Component
class ForumCommentAssembler {

    static final String MODERATE_PERMISSION = "forum.moderate";

    private final ForumCommentStore store;
    private final ForumAuthorResolver authors;

    ForumCommentAssembler(ForumCommentStore store, ForumAuthorResolver authors) {
        this.store = store;
        this.authors = authors;
    }

    /** Verilen satirlari (sirayi koruyarak) goruntuye cevirir. */
    List<CommentView> assemble(Long viewer, ForumCommentTopics.TopicInfo topic, List<ForumCommentRow> rows) {
        if (rows.isEmpty()) {
            return List.of();
        }
        List<Long> ids = rows.stream().map(ForumCommentRow::id).toList();
        List<ForumCommentRow> live = rows.stream().filter(ForumCommentRow::live).toList();
        List<Author> liveAuthors = authors.resolve(viewer, live.stream()
                .map(r -> new ForumAuthorResolver.Key(r.topicId(), r.userId(), r.anonymous())).toList());
        Set<Long> liked = viewer == null ? Set.of() : store.likedAmong(viewer, ids);
        Set<Long> saved = viewer == null ? Set.of() : store.savedAmong(viewer, ids);
        boolean canModerate = CurrentUser.hasAdminPermission(MODERATE_PERMISSION);

        List<CommentView> out = new ArrayList<>(rows.size());
        int li = 0;
        for (ForumCommentRow r : rows) {
            if (!r.live()) {
                // Yer tutucu: gorunur yazar/govde YOK
                out.add(new CommentView(r.id(), r.topicId(), r.parentId(), r.depth(), null, null, false, r.createdAt(),
                        null, 0, false, false, r.replyCount(), null, false, true, canModerate, false, null));
                continue;
            }
            Author author = liveAuthors.get(li++);
            boolean topicAuthor = r.userId() == topic.authorId() && (!topic.anonymous() || r.anonymous());
            out.add(new CommentView(r.id(), r.topicId(), r.parentId(), r.depth(), author, r.body(), r.anonymous(),
                    r.createdAt(), r.editedAt(), r.likeCount(), liked.contains(r.id()), saved.contains(r.id()),
                    r.replyCount(), null, viewer != null && r.userId() == viewer, false, canModerate, topicAuthor, null));
        }
        return out;
    }
}
