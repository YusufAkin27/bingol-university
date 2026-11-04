package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class EmojiReactionTest {
    @Test void acceptsSingleExtendedEmoji() {
        for (String emoji : new String[]{"🔥", "❤️", "❤", "👍🏽", "🇹🇷", "👨‍👩‍👧‍👦", "1️⃣", "🏳️‍🌈"}) {
            assertTrue(EmojiReaction.valid(emoji), emoji);
        }
    }
    @Test void rejectsTextMultipleEmojiAndMalformedInput() {
        for (String value : new String[]{"", "abc", "🔥🔥", "1", "<script>", "🔥 hello", "\u200D"}) {
            assertFalse(EmojiReaction.valid(value), value);
        }
        assertFalse(EmojiReaction.valid(null));
    }
}
