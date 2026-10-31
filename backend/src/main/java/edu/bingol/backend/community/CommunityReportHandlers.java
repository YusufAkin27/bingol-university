package edu.bingol.backend.community;

import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.time.Instant;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyon SPI: COMMUNITY, POST, ANNOUNCEMENT ve COMMUNITY_COVER rapor hedefleri. {@code exists(viewerId, id)}
 * raporlayanin hedefi GOREBILDIGINI denetler (T-057): gizli/onay bekleyen kulup, ozel kulup yazisi (uye degil),
 * engel iliskisi olan sahip -> olmayanla ayni 404.
 */
public final class CommunityReportHandlers {

    private CommunityReportHandlers() {}

    /** Kulup herkese gorunur (ACTIVE) ve sahibiyle engel iliskisi yok. */
    private static boolean clubVisible(Community c, Long viewerId, BlockService blocks) {
        return c.getStatus() == Community.Status.ACTIVE
                && (viewerId == null || c.getOwnerId().equals(viewerId) || !blocks.isBlocked(viewerId, c.getOwnerId()));
    }

    /** Kulup yazisi/duyurusu: kulup ACTIVE, OZEL kulupse raporlayan aktif uye, yazar engel iliskisinde degil. */
    private static boolean clubPostVisible(CommunityPost p, Long viewerId, CommunityRepository communities,
                                           CommunityMemberRepository members, BlockService blocks) {
        if (p.isDeleted() || p.getHiddenAt() != null) {
            return false;
        }
        Community c = communities.findById(p.getCommunityId()).orElse(null);
        if (c == null || c.getStatus() != Community.Status.ACTIVE) {
            return false;
        }
        if (c.getVisibility() == Community.Visibility.PRIVATE && viewerId != null && !c.getOwnerId().equals(viewerId)
                && members.findByCommunityIdAndUserId(c.getId(), viewerId).filter(CommunityMember::isActive).isEmpty()) {
            return false;
        }
        return viewerId == null || p.getAuthorId().equals(viewerId) || !blocks.isBlocked(viewerId, p.getAuthorId());
    }

    /** COMMUNITY: "gizle" = durumu HIDDEN yap (kesfetten ve detaydan kalkar). */
    @Component
    public static class CommunityHandler implements ReportTargetHandler {

        private final CommunityRepository communities;
        private final BlockService blocks;

        public CommunityHandler(CommunityRepository communities, BlockService blocks) {
            this.communities = communities;
            this.blocks = blocks;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.COMMUNITY;
        }

        @Override
        public boolean exists(Long targetId) {
            return communities.findById(targetId).filter(c -> c.getStatus() != Community.Status.HIDDEN).isPresent();
        }

        @Override
        public boolean exists(Long viewerId, Long targetId) {
            return communities.findById(targetId).filter(c -> clubVisible(c, viewerId, blocks)).isPresent();
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            return communities.findById(targetId).map(Community::getOwnerId);
        }

        @Override
        @Transactional
        public void hide(Long targetId) {
            communities.findById(targetId).ifPresent(c -> {
                c.setStatus(Community.Status.HIDDEN);
                communities.save(c);
            });
        }
    }

    /**
     * COMMUNITY_COVER: hedef kimligi = kulup kimligi. "Gizle" = kapak gorseli kaldirilir (kulup yerinde kalir);
     * geri alinamaz, yalniz yonetici karariyla.
     */
    @Component
    public static class CommunityCoverHandler implements ReportTargetHandler {

        private final CommunityRepository communities;
        private final BlockService blocks;
        private final MediaService media;

        public CommunityCoverHandler(CommunityRepository communities, BlockService blocks, MediaService media) {
            this.communities = communities;
            this.blocks = blocks;
            this.media = media;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.COMMUNITY_COVER;
        }

        @Override
        public boolean exists(Long targetId) {
            return communities.findById(targetId)
                    .filter(c -> c.getStatus() == Community.Status.ACTIVE && c.getCoverUrl() != null).isPresent();
        }

        @Override
        public boolean exists(Long viewerId, Long targetId) {
            return communities.findById(targetId)
                    .filter(c -> c.getCoverUrl() != null && clubVisible(c, viewerId, blocks)).isPresent();
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            return communities.findById(targetId).map(Community::getOwnerId);
        }

        @Override
        @Transactional
        public void hide(Long targetId) {
            communities.findById(targetId).ifPresent(c -> {
                String cover = c.getCoverUrl();
                if (cover == null) {
                    return;
                }
                c.setCoverUrl(null);
                c.setUpdatedAt(Instant.now());
                communities.save(c);
                media.release(cover);
            });
        }
    }

    /** POST: "gizle" = yazi yumusak silinir. */
    @Component
    public static class PostHandler implements ReportTargetHandler {

        private final CommunityPostRepository posts;
        private final CommunityRepository communities;
        private final CommunityMemberRepository members;
        private final BlockService blocks;

        public PostHandler(CommunityPostRepository posts, CommunityRepository communities,
                           CommunityMemberRepository members, BlockService blocks) {
            this.posts = posts;
            this.communities = communities;
            this.members = members;
            this.blocks = blocks;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.POST;
        }

        @Override
        public boolean exists(Long targetId) {
            return posts.findById(targetId).filter(p -> !p.isDeleted()).isPresent();
        }

        @Override
        public boolean exists(Long viewerId, Long targetId) {
            return posts.findById(targetId)
                    .filter(p -> clubPostVisible(p, viewerId, communities, members, blocks)).isPresent();
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            return posts.findById(targetId).map(CommunityPost::getAuthorId);
        }

        @Override
        @Transactional
        public void hide(Long targetId) {
            posts.findById(targetId).ifPresent(p -> {
                p.setDeleted(true);
                p.setPinned(false);
                posts.save(p);
                if (postMedia != null) {
                    postMedia.release(java.util.List.of(p));
                }
            });
        }

        private CommunityPostMedia postMedia;

        @org.springframework.beans.factory.annotation.Autowired(required = false)
        void setPostMedia(CommunityPostMedia postMedia) {
            this.postMedia = postMedia;
        }
    }

    /**
     * ANNOUNCEMENT: kulup duyurusu (community_post.announcement = true; hedef kimligi = yazi kimligi). "Gizle" =
     * yazi yumusak silinir (POST ile ayni). Duyuru uye listesine push gonderdiginden ayri raporlanabilir olmalidir.
     */
    @Component
    public static class AnnouncementHandler implements ReportTargetHandler {

        private final CommunityPostRepository posts;
        private final CommunityRepository communities;
        private final CommunityMemberRepository members;
        private final BlockService blocks;

        public AnnouncementHandler(CommunityPostRepository posts, CommunityRepository communities,
                                   CommunityMemberRepository members, BlockService blocks) {
            this.posts = posts;
            this.communities = communities;
            this.members = members;
            this.blocks = blocks;
        }

        @Override
        public ReportTargetType type() {
            return ReportTargetType.ANNOUNCEMENT;
        }

        @Override
        public boolean exists(Long targetId) {
            return posts.findById(targetId).filter(p -> p.isAnnouncement() && !p.isDeleted()).isPresent();
        }

        @Override
        public boolean exists(Long viewerId, Long targetId) {
            return posts.findById(targetId).filter(CommunityPost::isAnnouncement)
                    .filter(p -> clubPostVisible(p, viewerId, communities, members, blocks)).isPresent();
        }

        @Override
        public Optional<Long> ownerId(Long targetId) {
            return posts.findById(targetId).filter(CommunityPost::isAnnouncement).map(CommunityPost::getAuthorId);
        }

        @Override
        @Transactional
        public void hide(Long targetId) {
            posts.findById(targetId).filter(CommunityPost::isAnnouncement).ifPresent(p -> {
                p.setDeleted(true);
                p.setPinned(false);
                posts.save(p);
            });
        }
    }
}
