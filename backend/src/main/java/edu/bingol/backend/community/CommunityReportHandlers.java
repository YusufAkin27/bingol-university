package edu.bingol.backend.community;

import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Moderasyon SPI: COMMUNITY ve POST rapor hedefleri. */
public final class CommunityReportHandlers {

    private CommunityReportHandlers() {}

    /** COMMUNITY: "gizle" = durumu HIDDEN yap (kesfetten ve detaydan kalkar). */
    @Component
    public static class CommunityHandler implements ReportTargetHandler {

        private final CommunityRepository communities;

        public CommunityHandler(CommunityRepository communities) {
            this.communities = communities;
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

    /** POST: "gizle" = yazi yumusak silinir. */
    @Component
    public static class PostHandler implements ReportTargetHandler {

        private final CommunityPostRepository posts;

        public PostHandler(CommunityPostRepository posts) {
            this.posts = posts;
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
            });
        }
    }
}
