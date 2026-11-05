package edu.bingol.backend.forum.poll;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.poll.spi.PollView;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/** HTTP eslemesi: yollar, govde, hiz siniri cagrisi, kimligin cevapta olmamasi. */
class ForumPollControllerTest {

    private final ForumPollVoteService votes = mock(ForumPollVoteService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        mvc = MockMvcBuilders.standaloneSetup(new ForumPollController(votes, limiter)).build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private static PollView sample() {
        return new PollView(1L, "Soru", List.of(new PollView.Option(10L, "A", 2, 66.7), new PollView.Option(11L, "B", 1, 33.3)),
                3, 10L, null, false, true, true);
    }

    @Test
    void putVoteReturnsPollAndRateLimits() throws Exception {
        when(votes.vote(5L, 7L, 10L)).thenReturn(sample());
        mvc.perform(put("/api/forum/topics/5/poll/vote").contentType(MediaType.APPLICATION_JSON).content("{\"optionId\":10}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.myOptionId").value(10))
                .andExpect(jsonPath("$.options[0].percent").value(66.7))
                .andExpect(jsonPath("$.totalVotes").value(3))
                .andExpect(jsonPath("$.userId").doesNotExist())
                .andExpect(jsonPath("$.voters").doesNotExist());
        verify(limiter).check(eq("forum:poll:vote:7"), eq(60), eq(Duration.ofMinutes(1)));
    }

    @Test
    void putVoteWithoutOptionIsBadRequest() {
        Exception e = org.junit.jupiter.api.Assertions.assertThrows(Exception.class,
                () -> mvc.perform(put("/api/forum/topics/5/poll/vote").contentType(MediaType.APPLICATION_JSON).content("{}")));
        Throwable c = e.getCause() != null ? e.getCause() : e;
        org.junit.jupiter.api.Assertions.assertTrue(c instanceof ApiException a && a.code().equals("FORUM_POLL_OPTION_REQUIRED"), c.toString());
        verify(votes, never()).vote(eq(5L), eq(7L), eq(null));
    }

    @Test
    void deleteVoteAndGetMapToService() throws Exception {
        when(votes.retract(5L, 7L)).thenReturn(sample());
        when(votes.get(5L, 7L)).thenReturn(sample());
        mvc.perform(delete("/api/forum/topics/5/poll/vote")).andExpect(status().isOk());
        mvc.perform(get("/api/forum/topics/5/poll")).andExpect(status().isOk()).andExpect(jsonPath("$.closed").value(false));
        verify(limiter).check(eq("forum:poll:vote:7"), eq(60), eq(Duration.ofMinutes(1)));
    }
}
