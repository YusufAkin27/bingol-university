package edu.bingol.backend.forum.poll;

import java.io.Serializable;
import java.util.Objects;

/** forum_poll_vote bileske anahtari: (anket, kullanici). */
public class ForumPollVoteId implements Serializable {

    private Long pollId;
    private Long userId;

    public ForumPollVoteId() {}

    public ForumPollVoteId(Long pollId, Long userId) {
        this.pollId = pollId;
        this.userId = userId;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof ForumPollVoteId other && Objects.equals(pollId, other.pollId) && Objects.equals(userId, other.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(pollId, userId);
    }
}
