package edu.bingol.backend.forum.poll.spi;

import java.time.Instant;
import java.util.List;

/**
 * Anket gorunumu (API: {@code Poll}). Sonuclar herkese her zaman gorunur; oy verenler kimlikle listelenmez.
 *
 * @param myOptionId bakanin secimi (oy vermediyse null)
 * @param canVote    anket acik ve (oy yok ya da degistirme acik) ise true
 */
public record PollView(Long id, String question, List<Option> options, int totalVotes, Long myOptionId,
                       Instant endsAt, boolean closed, boolean allowChangeVote, boolean canVote) {

    /** @param percent 0-100, 1 ondalik */
    public record Option(Long id, String text, int voteCount, double percent) {}
}
