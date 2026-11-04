package edu.bingol.backend.post.reel;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostViewAssembler;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Bir kullanicinin Reels'leri (profil Reels sekmesi): yalniz video gonderiler, yeni once, imlecli. */
@Service
public class UserReelsService {

    static final int DEFAULT_SIZE = 12;
    static final int MAX_SIZE = 20;

    private final ReelRepository reels;
    private final PostViewAssembler assembler;

    /** Gizli hesap kapisi (setter: yoksa tum hesaplar herkese acik sayilir). */
    private PrivateAccountGate gate;

    public UserReelsService(ReelRepository reels, PostViewAssembler assembler) {
        this.reels = reels;
        this.assembler = assembler;
    }

    @Autowired(required = false)
    void setGate(PrivateAccountGate gate) {
        this.gate = gate;
    }

    /**
     * Gizli hesap ve bakan kabul edilmis takipci/sahibi degilse bos liste + locked=true (403 degil; /users/{id}/posts ile ayni);
     * engel iliskisinde / pasif yazarda bos liste.
     */
    @Transactional(readOnly = true)
    public FeedPage byAuthor(Long viewer, Long authorId, String cursor, int size) {
        int n = size <= 0 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        if (gate != null && !gate.canSeeContent(viewer, authorId)) {
            return FeedPage.lockedPage();
        }
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Post> rows = c == null
                ? reels.byAuthorFirst(authorId, viewer, PageRequest.of(0, n + 1))
                : reels.byAuthorAfter(authorId, viewer, c.at(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<Post> items = more ? rows.subList(0, n) : rows;
        String next = more ? PostCursor.latest(items.get(items.size() - 1).getCreatedAt(), items.get(items.size() - 1).getId()) : null;
        FeedPage out = new FeedPage(assembler.assemble(viewer, items), next);
        return gate == null ? out : new FeedPage(out.items(), out.nextCursor(), out.hint(), Boolean.FALSE);
    }
}
