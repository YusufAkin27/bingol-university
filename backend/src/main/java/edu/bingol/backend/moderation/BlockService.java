package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.follow.FollowRequestService;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kullanici engelleme. Diger moduller (mesajlasma, arama, topluluk) {@link #isBlocked} ile kontrol eder. */
@Service
public class BlockService {

    private final UserBlockRepository blocks;
    private final UserRepository users;

    public BlockService(UserBlockRepository blocks, UserRepository users) {
        this.blocks = blocks;
        this.users = users;
    }

    @Transactional
    public void block(Long blockerId, Long targetId) {
        if (blockerId.equals(targetId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_BLOCK_SELF", "Kendinizi engelleyemezsiniz.");
        }
        if (!users.existsById(targetId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (!blocks.existsByBlockerIdAndBlockedId(blockerId, targetId)) {
            blocks.save(new UserBlock(blockerId, targetId));
        }
        // FIX-P05 (A06#3, K15): engel, iki yonlu takibi ve bekleyen takip isteklerini de kaldirir (gizlilik: gizli
        // hesapta engel kalkinca eski takipci olarak kalma sorunu). Idempotent; zaten engelliyse tekrar temizler.
        dropFollowRelations(blockerId, targetId);
    }

    /** Takip/istek iliskisini ayni islemde siler. Bagimlilik dairesi olmasin diye tembel (ObjectProvider). */
    private void dropFollowRelations(Long a, Long b) {
        if (followProvider != null) {
            followProvider.ifAvailable(f -> f.dropBetween(a, b));
        }
        if (followRequestProvider != null) {
            followRequestProvider.ifAvailable(r -> r.dropBetween(a, b));
        }
    }

    private ObjectProvider<FollowService> followProvider;
    private ObjectProvider<FollowRequestService> followRequestProvider;

    @Autowired(required = false)
    void setFollowProviders(ObjectProvider<FollowService> follows, ObjectProvider<FollowRequestService> requests) {
        this.followProvider = follows;
        this.followRequestProvider = requests;
    }

    @Transactional
    public void unblock(Long blockerId, Long targetId) {
        UserBlock.Key key = new UserBlock.Key();
        key.setBlockerId(blockerId);
        key.setBlockedId(targetId);
        blocks.deleteById(key);
    }

    /** a ile b arasinda her iki yonde de engel var mi. */
    public boolean isBlocked(Long a, Long b) {
        return blocks.existsBetween(a, b);
    }

    /** Kullanicinin engelledigi + kendisini engelleyen kullanicilar (listelerden gizlemek icin). */
    public Set<Long> hiddenFrom(Long userId) {
        return Set.copyOf(blocks.relatedIds(userId));
    }

    public Slice<UserBlock> blockedPage(Long userId, Pageable pageable) {
        return blocks.findByBlockerIdOrderByCreatedAtDescBlockedIdDesc(userId, pageable);
    }

    /** a, b'yi engellemis mi (tek yon; PK aramasi). */
    public boolean hasBlocked(Long a, Long b) {
        return blocks.existsByBlockerIdAndBlockedId(a, b);
    }

    /** Engelledigim kullanici sayisi (PK onekli tek COUNT). */
    public long blockedCount(Long userId) {
        return blocks.countByBlockerId(userId);
    }

    public List<UserBlock> blockedBy(Long userId) {
        return blocks.findByBlockerIdOrderByCreatedAtDesc(userId);
    }
}
