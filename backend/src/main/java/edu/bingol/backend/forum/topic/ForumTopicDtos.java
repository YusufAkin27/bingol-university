package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.poll.spi.CreatePollRequest;
import java.util.List;

/** Konu uclarinin istek/yanit govdeleri (sozlesme A). Dogrulama servistedir (FORUM_ hata kodlari). */
public final class ForumTopicDtos {

    private ForumTopicDtos() {}

    /** @param imageIds yuklenmis forum gorselleri (en cok 4); @param poll istege bagli anket */
    public record CreateTopicRequest(String title, String body, Long categoryId, boolean anonymous,
                                     List<Long> imageIds, CreatePollRequest poll) {}

    /** PATCH: null alan degismez. */
    public record UpdateTopicRequest(String title, String body, Long categoryId) {}

    public record LikeState(boolean liked, int likeCount) {}

    public record SaveState(boolean saved) {}

    public record FollowState(boolean following) {}

    public record NotificationsRequest(Boolean enabled) {}

    public record NotificationsState(boolean enabled) {}
}
