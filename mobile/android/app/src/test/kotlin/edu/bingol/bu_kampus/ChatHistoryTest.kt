package edu.bingol.bu_kampus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** MessagingStyle birikimi ve gorulmus kimlik mantigi (saf; android gerektirmez). */
class ChatHistoryTest {
    private fun msg(id: String, text: String = "m$id", at: Long = id.hashCode().toLong(), self: Boolean = false, sender: String = "ali") =
        ChatMsg(id, sender, sender, text, at, self)

    @Test fun accumulatesInOrderAndCountsTotal() {
        var state: ChatState? = null
        for (i in 1..3) state = ChatHistoryLogic.record(state, msg("$i"), 1000L + i).first
        assertEquals(listOf("1", "2", "3"), state!!.messages.map { it.id })
        assertEquals(3, state.total)
    }

    @Test fun keepsOnlyLastEightButTotalKeepsCounting() {
        var state: ChatState? = null
        for (i in 1..12) state = ChatHistoryLogic.record(state, msg("$i"), 1000L + i).first
        assertEquals(ChatHistoryLogic.LIMIT, state!!.messages.size)
        assertEquals("5", state.messages.first().id)
        assertEquals("12", state.messages.last().id)
        assertEquals(12, state.total)
    }

    @Test fun sameMessageIdIsIdempotent() {
        val first = ChatHistoryLogic.record(null, msg("7"), 1000L)
        assertTrue(first.second)
        val again = ChatHistoryLogic.record(first.first, msg("7", text = "degisti"), 2000L)
        assertFalse(again.second)
        assertEquals(first.first, again.first)
        assertEquals(1, again.first.messages.size)
        assertEquals(1, again.first.total)
    }

    @Test fun ownReplyIsNotCountedAsUnread() {
        var state = ChatHistoryLogic.record(null, msg("1"), 1000L).first
        state = ChatHistoryLogic.record(state, msg("r:x", self = true), 1100L).first
        assertEquals(1, state.total)
        assertEquals(2, state.messages.size)
        assertTrue(state.messages.last().self)
    }

    @Test fun resetStartsFreshWhenNotificationGone() {
        val old = ChatHistoryLogic.record(null, msg("1"), 1000L).first
        val fresh = ChatHistoryLogic.record(old, msg("2"), 1500L, reset = true).first
        assertEquals(listOf("2"), fresh.messages.map { it.id })
        assertEquals(1, fresh.total)
    }

    @Test fun staleStateRestartsAfterTwentyFourHours() {
        val old = ChatHistoryLogic.record(null, msg("1"), 1000L).first
        val later = 1000L + ChatHistoryLogic.STALE_MS + 1
        val fresh = ChatHistoryLogic.record(old, msg("2"), later).first
        assertEquals(listOf("2"), fresh.messages.map { it.id })
    }

    @Test fun staleStateAllowsReuseOfOldId() {
        val old = ChatHistoryLogic.record(null, msg("1"), 1000L).first
        val later = 1000L + ChatHistoryLogic.STALE_MS + 1
        val again = ChatHistoryLogic.record(old, msg("1"), later)
        assertTrue(again.second)
    }

    @Test fun textIsBounded() {
        val long = "x".repeat(ChatHistoryLogic.MAX_TEXT + 100)
        val state = ChatHistoryLogic.record(null, msg("1", text = long), 1000L).first
        assertEquals(ChatHistoryLogic.MAX_TEXT, state.messages.single().text.length)
    }

    @Test fun conversationsAreSeparate() {
        var a: ChatState? = null
        var b: ChatState? = null
        a = ChatHistoryLogic.record(a, msg("1"), 1000L).first
        b = ChatHistoryLogic.record(b, msg("1", sender = "veli"), 1000L).first
        a = ChatHistoryLogic.record(a, msg("2"), 1001L).first
        assertEquals(2, a.messages.size)
        assertEquals(1, b.messages.size)
    }

    @Test fun pruneDropsStaleAndCapsConversationCount() {
        val now = 10_000_000_000L
        val all = HashMap<String, ChatState>()
        for (i in 1..25) all["conv:$i"] = ChatState(1, listOf(msg("$i")), now - i)
        all["old"] = ChatState(1, listOf(msg("o")), now - ChatHistoryLogic.STALE_MS - 5)
        val pruned = ChatHistoryLogic.prune(all, now)
        assertEquals(ChatHistoryLogic.MAX_CONVERSATIONS, pruned.size)
        assertFalse(pruned.containsKey("old"))
        assertTrue(pruned.containsKey("conv:1"))
        assertFalse(pruned.containsKey("conv:25"))
    }

    @Test fun seenIdsAreIdempotentAndBounded() {
        var list: List<String> = emptyList()
        val r1 = SeenIds.add(list, "a"); list = r1.first
        assertTrue(r1.second)
        val r2 = SeenIds.add(list, "a")
        assertFalse(r2.second)
        for (i in 1..(SeenIds.CAP + 10)) list = SeenIds.add(list, "id$i").first
        assertEquals(SeenIds.CAP, list.size)
        assertFalse(list.contains("a"))
        assertTrue(SeenIds.add(list, "").second) // bos kimlik her zaman yeni
    }
}
