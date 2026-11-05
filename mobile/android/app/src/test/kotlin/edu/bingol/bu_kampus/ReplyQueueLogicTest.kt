package edu.bingol.bu_kampus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Satir ici yanit kuyrugu: geri cekilme, clientId tekrari, sonuc isleme (saf). */
class ReplyQueueLogicTest {
    private fun entry(id: String = "c1", text: String = "merhaba", created: Long = 1000L) =
        ReplyEntry(id, "conv:4", "4", "9", text, "7", "{}", created)

    @Test fun backoffIsEscalatingAndCapped() {
        assertEquals(15_000L, ReplyQueueLogic.backoffMs(1))
        assertEquals(60_000L, ReplyQueueLogic.backoffMs(2))
        assertEquals(5 * 60_000L, ReplyQueueLogic.backoffMs(3))
        assertEquals(30 * 60_000L, ReplyQueueLogic.backoffMs(4))
        assertEquals(2 * 60 * 60_000L, ReplyQueueLogic.backoffMs(5))
        assertEquals(2 * 60 * 60_000L, ReplyQueueLogic.backoffMs(50))
        assertEquals(15_000L, ReplyQueueLogic.backoffMs(0))
    }

    @Test fun enqueueIgnoresDuplicateClientId() {
        val one = ReplyQueueLogic.enqueue(emptyList(), entry(), 1000L)
        val two = ReplyQueueLogic.enqueue(one, entry(text = "baska"), 1100L)
        assertEquals(1, two.size)
        assertEquals("merhaba", two.single().text)
    }

    @Test fun enqueueRejectsBlankAndOversizedText() {
        assertTrue(ReplyQueueLogic.enqueue(emptyList(), entry(text = "   "), 1000L).isEmpty())
        assertTrue(ReplyQueueLogic.enqueue(emptyList(), entry(text = "x".repeat(ReplyQueueLogic.MAX_TEXT + 1)), 1000L).isEmpty())
        assertEquals("kisa", ReplyQueueLogic.enqueue(emptyList(), entry(text = "  kisa  "), 1000L).single().text)
    }

    @Test fun enqueueCapsQueueAndDropsExpired() {
        var q: List<ReplyEntry> = emptyList()
        for (i in 1..(ReplyQueueLogic.MAX_ENTRIES + 5)) q = ReplyQueueLogic.enqueue(q, entry("c$i", created = 1000L + i), 2000L)
        assertEquals(ReplyQueueLogic.MAX_ENTRIES, q.size)
        val later = 1000L + ReplyQueueLogic.EXPIRE_MS + 100
        val fresh = ReplyQueueLogic.enqueue(q, entry("new", created = later), later)
        assertEquals(listOf("new"), fresh.map { it.clientId })
    }

    @Test fun retryBacksOffThenFailsAfterMaxAttempts() {
        var q = listOf(entry())
        var now = 5000L
        for (attempt in 1 until ReplyQueueLogic.MAX_ATTEMPTS) {
            q = ReplyQueueLogic.apply(q, "c1", ReplyOutcome.RETRY, now)
            assertEquals(ReplyState.PENDING, q.single().state)
            assertEquals(now + ReplyQueueLogic.backoffMs(attempt), q.single().nextAtMs)
            assertEquals(attempt, q.single().attempts)
            now += 10
        }
        q = ReplyQueueLogic.apply(q, "c1", ReplyOutcome.RETRY, now)
        assertEquals(ReplyState.FAILED, q.single().state)
        assertEquals(ReplyQueueLogic.MAX_ATTEMPTS, q.single().attempts)
    }

    @Test fun okRemovesAndFailIsTerminal() {
        val q = listOf(entry("a"), entry("b"))
        val ok = ReplyQueueLogic.apply(q, "a", ReplyOutcome.OK, 2000L)
        assertEquals(listOf("b"), ok.map { it.clientId })
        val failed = ReplyQueueLogic.apply(q, "b", ReplyOutcome.FAIL, 2000L)
        assertEquals(ReplyState.FAILED, failed.first { it.clientId == "b" }.state)
        assertEquals(ReplyState.PENDING, failed.first { it.clientId == "a" }.state)
    }

    @Test fun dueHonoursNextAtStateAndExpiry() {
        val now = 100_000L
        val ready = entry("ready", created = 50_000L)
        val waiting = entry("waiting", created = 50_000L).copy(nextAtMs = now + 1)
        val failed = entry("failed", created = 50_000L).copy(state = ReplyState.FAILED)
        val expired = entry("expired", created = now - ReplyQueueLogic.EXPIRE_MS - 1).copy(nextAtMs = 0)
        val due = ReplyQueueLogic.due(listOf(waiting, failed, ready, expired), now)
        assertEquals(listOf("ready"), due.map { it.clientId })
    }

    @Test fun nextWakeIsEarliestPending() {
        assertNull(ReplyQueueLogic.nextWake(emptyList()))
        val q = listOf(entry("a").copy(nextAtMs = 500), entry("b").copy(nextAtMs = 200), entry("c").copy(nextAtMs = 1, state = ReplyState.FAILED))
        assertEquals(200L, ReplyQueueLogic.nextWake(q))
    }

    @Test fun retryKeepsSameClientIdForIdempotency() {
        val q = ReplyQueueLogic.apply(listOf(entry("stable")), "stable", ReplyOutcome.RETRY, 2000L)
        assertEquals("stable", q.single().clientId)
    }
}
