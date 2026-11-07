package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReceiptEvent;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/** Okuma zamani (readAt): yalniz gonderen + okunmus mesaj; olayda okundu anini tasir. */
class MessageReadAtViewTest {

    static final Instant READ = Instant.parse("2026-11-07T10:00:00Z");

    static Message msg() {
        Message m = new Message();
        m.setId(5L);
        m.setSenderId(1L);
        m.setReadAt(READ);
        return m;
    }

    @Test
    void senderSeesReadAtWhenRead() {
        assertEquals("2026-11-07T10:00:00Z", MessageViewAssembler.readAtOf(1L, msg(), ReceiptService.READ));
    }

    @Test
    void recipientNeverSeesReadAt() {
        assertNull(MessageViewAssembler.readAtOf(2L, msg(), ReceiptService.READ));
    }

    @Test
    void nullWhenNotRead() {
        assertNull(MessageViewAssembler.readAtOf(1L, msg(), ReceiptService.DELIVERED));
        Message unread = msg();
        unread.setReadAt(null);
        assertNull(MessageViewAssembler.readAtOf(1L, unread, ReceiptService.READ));
    }

    @Test
    void nullWhenStatusUntracked() {
        assertNull(MessageViewAssembler.readAtOf(1L, msg(), null));
    }

    @Test
    void viewCarriesReadAtAndStaysCompatible() {
        MessageView v = MessageView.of(msg()).withReadAt("x");
        assertEquals("x", v.readAt());
        assertNull(MessageView.of(msg()).withStatus("READ").readAt());
        assertEquals("x", v.withStatus("READ").withSenderName("a").readAt());
    }

    @Test
    void receiptEventReadAtOnlyForRead() {
        assertEquals("T", new ReceiptEvent("receipt", 1L, "read", 5L, 2L, "T", "READ").readAt());
        assertNull(new ReceiptEvent("receipt", 1L, "delivered", 5L, 2L, "T", "DELIVERED").readAt());
    }
}
