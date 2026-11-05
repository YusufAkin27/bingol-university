package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** `recordDelivered` / `recordRead` gercek depo uzerinde: ilk zaman yazilir, sonraki olay uzerine yazmaz. */
@SpringBootTest
class MessageReceiptTimesTest {

    @Autowired MessageRepository messages;

    Message save(long conv, long sender, boolean suppressed) {
        Message m = new Message();
        m.setConversationId(conv);
        m.setSenderId(sender);
        m.setClientId(UUID.randomUUID().toString());
        m.setBody("x");
        m.setSuppressed(suppressed);
        return messages.saveAndFlush(m);
    }

    @Test
    void firstTimeWinsAndLaterAcksDoNotOverwrite() {
        long conv = 9_000_001L;
        Message mine = save(conv, 1L, false);
        Message other = save(conv, 2L, false); // alicinin kendi mesaji: etkilenmez
        Instant t1 = Instant.parse("2026-11-05T10:00:01Z");
        Instant t2 = Instant.parse("2026-11-05T10:00:09Z");

        assertEquals(1, messages.recordDelivered(conv, 2L, mine.getId() - 1, other.getId(), t1));
        assertEquals(0, messages.recordDelivered(conv, 2L, mine.getId() - 1, other.getId(), t2));
        assertEquals(1, messages.recordRead(conv, 2L, mine.getId() - 1, other.getId(), t2));
        assertEquals(0, messages.recordRead(conv, 2L, mine.getId() - 1, other.getId(), t1));

        Message back = messages.findById(mine.getId()).orElseThrow();
        assertEquals(t1, back.getDeliveredAt().truncatedTo(ChronoUnit.SECONDS));
        assertEquals(t2, back.getReadAt().truncatedTo(ChronoUnit.SECONDS));
        Message own = messages.findById(other.getId()).orElseThrow();
        assertNull(own.getDeliveredAt());
        assertNull(own.getReadAt());
    }

    @Test
    void shadowBlockedMessageNeverGetsTimes() {
        long conv = 9_000_002L;
        Message hidden = save(conv, 1L, true);
        Instant t = Instant.parse("2026-11-05T10:00:01Z");
        assertEquals(0, messages.recordDelivered(conv, 2L, 0, hidden.getId(), t));
        assertEquals(0, messages.recordRead(conv, 2L, 0, hidden.getId(), t));
        assertNull(messages.findById(hidden.getId()).orElseThrow().getReadAt());
    }

    @Test
    void rangeIsExclusiveOfAlreadyAckedAndInclusiveOfUpperBound() {
        long conv = 9_000_003L;
        Message a = save(conv, 1L, false);
        Message b = save(conv, 1L, false);
        Instant t = Instant.parse("2026-11-05T10:00:01Z");
        assertEquals(1, messages.recordRead(conv, 2L, a.getId(), b.getId(), t)); // (a, b]
        assertNull(messages.findById(a.getId()).orElseThrow().getReadAt());
        assertEquals(t, messages.findById(b.getId()).orElseThrow().getReadAt().truncatedTo(ChronoUnit.SECONDS));
    }
}
