package edu.bingol.backend.poll;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.poll.PollDtos.VoteRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * T-069 (A2-06): tek ankete oy veren herkes ayni {@code poll.voter_count} satirinda cakisir. Sicak satir kilidi
 * UPDATE'ten commit'e kadar tutuldugu icin anket UPDATE'i islemin SON ifadesi olmali (once secenek sayaclari);
 * secmen sayisi degismeyen oy degisikliginde anket satirina hic dokunulmamali.
 */
class PollVoteCounterOrderTest {

    private static final Instant NOW = Instant.parse("2026-10-31T10:00:00Z");

    private final PollRepository polls = mock(PollRepository.class);
    private final PollOptionRepository options = mock(PollOptionRepository.class);
    private final PollBallotRepository ballots = mock(PollBallotRepository.class);
    private final PollVoteRepository votes = mock(PollVoteRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final PollAccess access = mock(PollAccess.class);
    private final PollViewAssembler assembler = mock(PollViewAssembler.class);
    private PollVoteService svc;
    private Poll poll;
    private final Actor voter = new Actor(7L, false);

    @BeforeEach
    void setUp() {
        PlatformTransactionManager tm = mock(PlatformTransactionManager.class);
        svc = new PollVoteService(polls, options, ballots, votes, users, access, assembler,
                Clock.fixed(NOW, ZoneOffset.UTC), tm);
        poll = new Poll();
        poll.setId(1L);
        poll.setTitle("A");
        poll.setType(Poll.Type.SINGLE);
        poll.setStatus(Poll.Status.OPEN);
        poll.setOpensAt(NOW.minusSeconds(60));
        poll.setAllowChangeVote(true);
        when(polls.findById(1L)).thenReturn(Optional.of(poll));
        when(options.findByPollIdOrderByPositionAsc(1L)).thenReturn(List.of(opt(11L, 1), opt(12L, 2), opt(13L, 3)));
        when(access.memberCommunityIds(7L)).thenReturn(Set.of());
        when(users.findById(7L)).thenReturn(Optional.of(new User()));
        when(access.eligible(any(), any(), any())).thenReturn(true);
    }

    private static PollOption opt(long id, int pos) {
        PollOption o = new PollOption(1L, pos, "o" + pos);
        o.setId(id);
        return o;
    }

    @Test
    void newVoterUpdatesOptionsFirstAndPollRowLast() {
        when(ballots.lockByPollIdAndUserId(1L, 7L)).thenReturn(Optional.empty());
        when(polls.addVotersIfOpen(eq(1L), eq(1), any())).thenReturn(1);

        svc.vote(voter, 1L, new VoteRequest(List.of(12L), null));

        InOrder order = inOrder(options, polls);
        order.verify(options).addCounts(12L, 1, 0);
        order.verify(polls).addVotersIfOpen(eq(1L), eq(1), any());
        verify(polls, never()).countOpenAt(anyLong(), any());
    }

    @Test
    void voteChangeNeverTouchesHotPollRowButStillChecksOpenLocklessly() {
        PollBallot existing = new PollBallot(1L, 7L);
        when(ballots.lockByPollIdAndUserId(1L, 7L)).thenReturn(Optional.of(existing));
        when(votes.findByPollIdAndUserIdOrderByChoiceRankAsc(1L, 7L)).thenReturn(List.of(new PollVote(1L, 11L, 7L, 1)));
        when(polls.countOpenAt(eq(1L), any())).thenReturn(1L);

        svc.vote(voter, 1L, new VoteRequest(List.of(12L), null));

        verify(polls, never()).addVotersIfOpen(anyLong(), anyInt(), any());
        InOrder order = inOrder(options, polls);
        order.verify(options).addCounts(11L, -1, 0);
        order.verify(options).addCounts(12L, 1, 0);
        order.verify(polls).countOpenAt(eq(1L), any());
    }

    @Test
    void pollClosedBetweenReadAndWriteRollsBackWithPollClosed() {
        when(ballots.lockByPollIdAndUserId(1L, 7L)).thenReturn(Optional.empty());
        when(polls.addVotersIfOpen(eq(1L), eq(1), any())).thenReturn(0);
        Poll closed = new Poll();
        closed.setId(1L);
        closed.setStatus(Poll.Status.CLOSED);
        when(polls.findById(1L)).thenReturn(Optional.of(poll), Optional.of(closed));

        ApiException e = assertThrows(ApiException.class,
                () -> svc.vote(voter, 1L, new VoteRequest(List.of(12L), null)));
        assertEquals("POLL_CLOSED", e.code());
    }
}
