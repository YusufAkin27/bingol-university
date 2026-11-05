package edu.bingol.backend.forum.poll;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.poll.spi.CreatePollRequest;
import edu.bingol.backend.forum.poll.spi.PollView;
import edu.bingol.backend.forum.topic.spi.ForumTopicLookup;
import edu.bingol.backend.forum.topic.spi.TopicRef;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Forum konu anketi: olusturma dogrulamalari, oy/degistirme/geri alma, kapanis, yuzdeler, yaris, kimlik sizmamasi. */
@SpringBootTest
class ForumPollServiceTest {

    private static final AtomicLong TOPIC_SEQ = new AtomicLong(5000);

    @Autowired ForumPollServiceImpl service;
    @Autowired ForumPollVoteService voteService;
    @Autowired ForumPollRepository polls;
    @Autowired ForumPollOptionRepository options;
    @Autowired ForumPollVoteRepository votes;
    @Autowired ForumPollAccountPurger purger;
    @Autowired JdbcTemplate jdbc;
    @Autowired List<edu.bingol.backend.export.DataExporter> exporters;
    @MockitoBean ForumTopicLookup lookup;

    private long topic;

    @BeforeEach
    void setUp() {
        topic = TOPIC_SEQ.incrementAndGet();
        visible(topic, false, "ACTIVE");
    }

    // ---------- yardimcilar ----------

    private void visible(long topicId, boolean locked, String status) {
        when(lookup.visibleTopic(anyLong(), any())).thenReturn(Optional.empty());
        when(lookup.visibleTopic(org.mockito.ArgumentMatchers.eq(topicId), any()))
                .thenReturn(Optional.of(TopicRefs.of(topicId, locked, status)));
    }

    private PollView create(boolean allowChange, String... opts) {
        return service.createForTopic(topic, new CreatePollRequest("Soru?", List.of(opts), null, allowChange));
    }

    private static ApiException api(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private long optionId(PollView v, int index) {
        return v.options().get(index).id();
    }

    private int count(long optionId) {
        return options.findById(optionId).orElseThrow().getVoteCount();
    }

    // ---------- olusturma ----------

    @Test
    void createsPollWithTrimmedOptionsAndZeroResults() {
        PollView v = service.createForTopic(topic, new CreatePollRequest("  Hangisi?  ", List.of(" Evet ", "Hayır"), null, true));
        assertEquals("Hangisi?", v.question());
        assertEquals(List.of("Evet", "Hayır"), v.options().stream().map(PollView.Option::text).toList());
        assertEquals(0, v.totalVotes());
        v.options().forEach(o -> assertEquals(0.0, o.percent()));
        assertNull(v.myOptionId());
        assertFalse(v.closed());
        assertTrue(v.allowChangeVote());
        assertEquals(v.id(), service.pollFor(topic, 1L).id());
    }

    @Test
    void questionIsOptional() {
        PollView v = service.createForTopic(topic, new CreatePollRequest("   ", List.of("a", "b"), null, false));
        assertNull(v.question());
    }

    @Test
    void rejectsWrongOptionCounts() {
        assertEquals("FORUM_POLL_OPTIONS_INVALID", api(() -> create(false, "tek")).code());
        assertEquals("FORUM_POLL_OPTIONS_INVALID", api(() -> create(false, "1", "2", "3", "4", "5", "6", "7")).code());
        assertEquals("FORUM_POLL_OPTIONS_INVALID", api(() -> create(false)).code());
        assertTrue(polls.findByTopicId(topic).isEmpty());
        // 6 seçenek sınırı kabul edilir
        assertEquals(6, create(false, "1", "2", "3", "4", "5", "6").options().size());
    }

    @Test
    void rejectsBlankDuplicateAndTooLongOptions() {
        assertEquals("FORUM_POLL_OPTIONS_INVALID", api(() -> create(false, "a", "   ")).code());
        assertEquals("FORUM_POLL_OPTIONS_INVALID", api(() -> create(false, "a", "<b></b>")).code());
        assertEquals("FORUM_POLL_DUPLICATE_OPTION", api(() -> create(false, "Evet", " evet ")).code());
        assertEquals("FORUM_POLL_OPTION_TOO_LONG", api(() -> create(false, "a", "x".repeat(81))).code());
        assertEquals(2, create(false, "a", "x".repeat(80)).options().size());
    }

    @Test
    void rejectsLongQuestion() {
        ApiException e = api(() -> service.createForTopic(topic, new CreatePollRequest("q".repeat(201), List.of("a", "b"), null, false)));
        assertEquals("FORUM_POLL_QUESTION_TOO_LONG", e.code());
        assertEquals(200, service.createForTopic(topic, new CreatePollRequest("q".repeat(200), List.of("a", "b"), null, false)).question().length());
    }

    @Test
    void validatesEndsAtWindow() {
        Instant now = Instant.now();
        assertEquals("FORUM_POLL_ENDS_INVALID", api(() -> service.createForTopic(topic,
                new CreatePollRequest(null, List.of("a", "b"), now.minusSeconds(5), false))).code());
        assertEquals("FORUM_POLL_ENDS_INVALID", api(() -> service.createForTopic(topic,
                new CreatePollRequest(null, List.of("a", "b"), now.plus(Duration.ofDays(31)), false))).code());
        PollView ok = service.createForTopic(topic,
                new CreatePollRequest(null, List.of("a", "b"), now.plus(Duration.ofDays(29)), false));
        assertNotNull(ok.endsAt());
        assertFalse(ok.closed());
    }

    @Test
    void stripsHtmlFromTexts() {
        PollView v = service.createForTopic(topic, new CreatePollRequest("<script>alert(1)</script>Soru",
                List.of("<b>Kalın</b> seçenek", "ikinci\u0000‮"), null, false));
        assertEquals("alert(1) Soru", v.question());
        assertEquals("Kalın seçenek", v.options().get(0).text());
        assertEquals("ikinci", v.options().get(1).text());
    }

    @Test
    void secondPollForSameTopicConflicts() {
        create(false, "a", "b");
        assertEquals("FORUM_POLL_EXISTS", api(() -> create(false, "c", "d")).code());
    }

    // ---------- oy ----------

    @Test
    void voteCountsAndPercentagesWithOneDecimal() {
        PollView p = create(false, "A", "B", "C");
        voteService.vote(topic, 1L, optionId(p, 0));
        voteService.vote(topic, 2L, optionId(p, 0));
        PollView last = voteService.vote(topic, 3L, optionId(p, 1));
        assertEquals(3, last.totalVotes());
        assertEquals(66.7, last.options().get(0).percent());
        assertEquals(33.3, last.options().get(1).percent());
        assertEquals(0.0, last.options().get(2).percent());
        assertEquals(optionId(p, 1), last.myOptionId());
        // başkası kendi oyunu görür, sonuçlar herkese açık
        PollView other = service.pollFor(topic, 2L);
        assertEquals(optionId(p, 0), other.myOptionId());
        assertEquals(3, other.totalVotes());
        assertNull(service.pollFor(topic, 99L).myOptionId());
    }

    @Test
    void percentHelper() {
        assertEquals(0.0, ForumPollServiceImpl.percent(0, 0));
        assertEquals(0.0, ForumPollServiceImpl.percent(0, 5));
        assertEquals(100.0, ForumPollServiceImpl.percent(5, 5));
        assertEquals(33.3, ForumPollServiceImpl.percent(1, 3));
        assertEquals(66.7, ForumPollServiceImpl.percent(2, 3));
        assertEquals(14.3, ForumPollServiceImpl.percent(1, 7));
    }

    @Test
    void sameOptionTwiceIsIdempotent() {
        PollView p = create(false, "A", "B");
        voteService.vote(topic, 1L, optionId(p, 0));
        PollView again = voteService.vote(topic, 1L, optionId(p, 0));
        assertEquals(1, again.totalVotes());
        assertEquals(1, count(optionId(p, 0)));
    }

    @Test
    void secondDifferentVoteRejectedWhenChangeDisabled() {
        PollView p = create(false, "A", "B");
        voteService.vote(topic, 1L, optionId(p, 0));
        assertEquals("FORUM_POLL_ALREADY_VOTED", api(() -> voteService.vote(topic, 1L, optionId(p, 1))).code());
        assertEquals(1, count(optionId(p, 0)));
        assertEquals(0, count(optionId(p, 1)));
        assertEquals("FORUM_POLL_CHANGE_NOT_ALLOWED", api(() -> voteService.retract(topic, 1L)).code());
        assertEquals(1, count(optionId(p, 0)));
    }

    @Test
    void changeMovesTheCountAtomically() {
        PollView p = create(true, "A", "B", "C");
        voteService.vote(topic, 1L, optionId(p, 0));
        PollView v = voteService.vote(topic, 1L, optionId(p, 2));
        assertEquals(1, v.totalVotes());
        assertEquals(0, count(optionId(p, 0)));
        assertEquals(1, count(optionId(p, 2)));
        assertEquals(optionId(p, 2), v.myOptionId());
        assertTrue(v.canVote());
    }

    @Test
    void retractRemovesVoteAndCounter() {
        PollView p = create(true, "A", "B");
        voteService.vote(topic, 1L, optionId(p, 1));
        PollView v = voteService.retract(topic, 1L);
        assertEquals(0, v.totalVotes());
        assertNull(v.myOptionId());
        assertEquals(0, count(optionId(p, 1)));
        // oy yokken geri alma idempotent
        assertEquals(0, voteService.retract(topic, 1L).totalVotes());
        // geri alındıktan sonra yeniden oy verilebilir
        assertEquals(1, voteService.vote(topic, 1L, optionId(p, 0)).totalVotes());
    }

    @Test
    void closedPollRejectsVotesAndRetractionButShowsResults() {
        PollView p = service.createForTopic(topic, new CreatePollRequest(null, List.of("A", "B"),
                Instant.now().plus(Duration.ofDays(1)), true));
        voteService.vote(topic, 1L, optionId(p, 0));
        jdbc.update("UPDATE forum_poll SET ends_at = ? WHERE id = ?", java.sql.Timestamp.from(Instant.now().minusSeconds(60)), p.id());
        assertEquals("FORUM_POLL_CLOSED", api(() -> voteService.vote(topic, 2L, optionId(p, 1))).code());
        assertEquals("FORUM_POLL_CLOSED", api(() -> voteService.vote(topic, 1L, optionId(p, 1))).code());
        assertEquals("FORUM_POLL_CLOSED", api(() -> voteService.retract(topic, 1L)).code());
        PollView v = service.pollFor(topic, 3L);
        assertTrue(v.closed());
        assertFalse(v.canVote());
        assertEquals(1, v.totalVotes());
        assertEquals(100.0, v.options().get(0).percent());
    }

    @Test
    void lockedRemovedAndInvisibleTopicsRejectVotes() {
        PollView p = create(true, "A", "B");
        visible(topic, true, "ACTIVE");
        assertEquals("FORUM_POLL_CLOSED", api(() -> voteService.vote(topic, 1L, optionId(p, 0))).code());
        visible(topic, false, "REMOVED");
        assertEquals("FORUM_POLL_NOT_FOUND", api(() -> voteService.vote(topic, 1L, optionId(p, 0))).code());
        when(lookup.visibleTopic(anyLong(), any())).thenReturn(Optional.empty());
        assertEquals("FORUM_POLL_NOT_FOUND", api(() -> voteService.vote(topic, 1L, optionId(p, 0))).code());
        assertEquals("FORUM_POLL_NOT_FOUND", api(() -> voteService.get(topic, 1L)).code());
        assertEquals(0, count(optionId(p, 0)));
    }

    @Test
    void topicWithoutPollAndForeignOptionAreNotFound() {
        assertEquals("FORUM_POLL_NOT_FOUND", api(() -> voteService.vote(topic, 1L, 1L)).code());
        PollView mine = create(false, "A", "B");
        long other = TOPIC_SEQ.incrementAndGet();
        visible(other, false, "ACTIVE");
        PollView foreign = service.createForTopic(other, new CreatePollRequest(null, List.of("X", "Y"), null, false));
        visible(topic, false, "ACTIVE");
        assertEquals("FORUM_POLL_OPTION_NOT_FOUND", api(() -> voteService.vote(topic, 1L, optionId(foreign, 0))).code());
        assertEquals("FORUM_POLL_OPTION_NOT_FOUND", api(() -> voteService.vote(topic, 1L, 987654321L)).code());
        assertEquals("FORUM_POLL_OPTION_NOT_FOUND", api(() -> voteService.vote(topic, 1L, null)).code());
        assertEquals(0, count(optionId(mine, 0)));
        assertEquals(0, count(optionId(foreign, 0)));
    }

    @Test
    void viewNeverExposesVoterIdentity() throws Exception {
        PollView p = create(false, "A", "B");
        voteService.vote(topic, 4242L, optionId(p, 0));
        String json = new com.fasterxml.jackson.databind.ObjectMapper()
                .findAndRegisterModules().writeValueAsString(service.pollFor(topic, 7L));
        assertFalse(json.contains("4242"), json);
        assertFalse(json.toLowerCase().contains("userid"), json);
        assertFalse(json.toLowerCase().contains("voters"), json);
        // başka kullanıcının bakışında myOptionId boş
        assertTrue(json.contains("\"myOptionId\":null"), json);
    }

    // ---------- yaris ----------

    @Test
    void concurrentFirstVotesOfSameUserCountOnce() throws Exception {
        PollView p = create(false, "A", "B");
        long o = optionId(p, 0);
        runConcurrently(12, i -> {
            try {
                voteService.vote(topic, 77L, o);
            } catch (ApiException e) {
                assertEquals("FORUM_POLL_BUSY", e.code());
            }
        });
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM forum_poll_vote WHERE poll_id = ? AND user_id = 77", Integer.class, p.id()));
        assertEquals(1, count(o));
    }

    @Test
    void concurrentDifferentOptionsFromSameUserLeaveOneVoteWhenChangeDisabled() throws Exception {
        PollView p = create(false, "A", "B", "C");
        List<Long> ids = List.of(optionId(p, 0), optionId(p, 1), optionId(p, 2));
        runConcurrently(9, i -> {
            try {
                voteService.vote(topic, 78L, ids.get(i % 3));
            } catch (ApiException e) {
                assertTrue(List.of("FORUM_POLL_ALREADY_VOTED", "FORUM_POLL_BUSY").contains(e.code()), e.code());
            }
        });
        assertCountersMatchVoteRows(p);
        assertEquals(1, service.pollFor(topic, 1L).totalVotes());
    }

    @Test
    void concurrentChangesKeepCountersConsistent() throws Exception {
        PollView p = create(true, "A", "B", "C");
        List<Long> ids = List.of(optionId(p, 0), optionId(p, 1), optionId(p, 2));
        voteService.vote(topic, 79L, ids.get(0));
        runConcurrently(18, i -> {
            try {
                if (i % 6 == 5) {
                    voteService.retract(topic, 79L);
                } else {
                    voteService.vote(topic, 79L, ids.get(i % 3));
                }
            } catch (ApiException e) {
                assertEquals("FORUM_POLL_BUSY", e.code());
            }
        });
        assertCountersMatchVoteRows(p);
        long total = service.pollFor(topic, 1L).totalVotes();
        assertTrue(total == 0 || total == 1, "toplam " + total);
    }

    @Test
    void manyUsersVotingConcurrentlySumUp() throws Exception {
        PollView p = create(false, "A", "B");
        List<Long> ids = List.of(optionId(p, 0), optionId(p, 1));
        int n = 24;
        runConcurrently(n, i -> voteService.vote(topic, 1000L + i, ids.get(i % 2)));
        PollView v = service.pollFor(topic, 1L);
        assertEquals(n, v.totalVotes());
        assertEquals(12, v.options().get(0).voteCount());
        assertEquals(12, v.options().get(1).voteCount());
        assertCountersMatchVoteRows(p);
    }

    private void assertCountersMatchVoteRows(PollView p) {
        for (PollView.Option o : service.pollFor(topic, 1L).options()) {
            int rows = jdbc.queryForObject("SELECT COUNT(*) FROM forum_poll_vote WHERE option_id = ?", Integer.class, o.id());
            assertEquals(rows, o.voteCount(), "secenek " + o.id() + " sayaci oy satirlariyla uyusmali");
        }
    }

    private interface Task {
        void run(int i) throws Exception;
    }

    private void runConcurrently(int threads, Task task) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        try {
            CountDownLatch go = new CountDownLatch(1);
            List<Future<?>> fs = new ArrayList<>();
            for (int i = 0; i < threads; i++) {
                int idx = i;
                fs.add(pool.submit(() -> {
                    go.await();
                    task.run(idx);
                    return null;
                }));
            }
            go.countDown();
            for (Future<?> f : fs) {
                f.get(60, TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }
    }

    // ---------- hesap silme + disa aktarim ----------

    @Test
    void accountPurgeDeletesVotesAndDecrementsCounters() {
        PollView p = create(false, "A", "B");
        voteService.vote(topic, 31L, optionId(p, 0));
        voteService.vote(topic, 32L, optionId(p, 0));
        voteService.vote(topic, 33L, optionId(p, 1));
        assertEquals(1, purger.purge(31L));
        assertEquals(1, count(optionId(p, 0)));
        assertEquals(1, count(optionId(p, 1)));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM forum_poll_vote WHERE user_id = 31", Integer.class));
        assertEquals(0, purger.purge(31L)); // ikinci kez: etkisiz
        assertEquals(1, count(optionId(p, 0)));
        assertCountersMatchVoteRows(p);
    }

    @Test
    void accountDeletedEventTriggersPurge() {
        PollView p = create(false, "A", "B");
        voteService.vote(topic, 41L, optionId(p, 1));
        purger.onAccountDeleted(new edu.bingol.backend.profile.UserAccountDeletedEvent(41L, List.of()));
        assertEquals(0, count(optionId(p, 1)));
        assertNull(service.pollFor(topic, 41L).myOptionId());
    }

    @Test
    @SuppressWarnings("unchecked")
    void exporterListsOnlyOwnVotes() {
        PollView p = create(false, "A", "B");
        voteService.vote(topic, 51L, optionId(p, 1));
        voteService.vote(topic, 52L, optionId(p, 0));
        Object out = exporters.stream().filter(e -> "forumPollVotes".equals(e.section())).findFirst().orElseThrow().export(51L);
        List<Map<String, Object>> rows = (List<Map<String, Object>>) ((Map<String, Object>) out).get("votes");
        assertEquals(1, rows.size());
        assertEquals("B", rows.get(0).get("optionText"));
        assertEquals(topic, ((Number) rows.get(0).get("topicId")).longValue());
    }
}
