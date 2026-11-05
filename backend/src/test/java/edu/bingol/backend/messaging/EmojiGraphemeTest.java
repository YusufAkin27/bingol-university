package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** Tepki dogrulayicisi: gecerli HERHANGI bir tek emoji kabul; harf/rakam/URL/bosluk/coklu emoji red. */
class EmojiGraphemeTest {

    @Test
    void acceptsSimpleAndSymbolEmojis() {
        for (String e : new String[] {"👍", "😂", "🔥", "💩", "🥹", "🫶", "❤", "❤️", "⭐", "⌚", "‼️", "©", "✅", "☺️", "🅰️", "🀄"}) {
            assertTrue(EmojiGrapheme.isSingleEmoji(e), e);
        }
    }

    @Test
    void acceptsSkinToneZwjFlagAndKeycap() {
        assertTrue(EmojiGrapheme.isSingleEmoji("👍🏽"), "ten rengi");
        assertTrue(EmojiGrapheme.isSingleEmoji("👨‍👩‍👧‍👦"), "ZWJ aile");
        assertTrue(EmojiGrapheme.isSingleEmoji("👩🏽‍❤️‍💋‍👨🏻"), "ten rengili ZWJ cift");
        assertTrue(EmojiGrapheme.isSingleEmoji("🏳️‍🌈"), "ZWJ bayrak");
        assertTrue(EmojiGrapheme.isSingleEmoji("🇹🇷"), "bayrak (bolgesel gosterge cifti)");
        assertTrue(EmojiGrapheme.isSingleEmoji("1️⃣"), "keycap FE0F ile");
        assertTrue(EmojiGrapheme.isSingleEmoji("#⃣"), "keycap FE0F'siz");
        assertTrue(EmojiGrapheme.isSingleEmoji("🏴󠁧󠁢󠁥󠁮󠁧󠁿"),
                "etiketli bayrak (Ingiltere)");
    }

    @Test
    void rejectsNonEmojiInput() {
        for (String s : new String[] {"a", "A", "12", "1", "#", "*", "", " ", "\n", "-", "!", "?", "http://x", "https://a.b/c",
                "ab", "😀a", "a😀", "😀 ", " 😀", "\u0000", "‍", "️", "👍‍", "‍👍", "🏽", "🇹", "🇹🇷🇹",
                "😀😀", "👍👍🏽", "❤️❤️", "é", "ş", "ع", "<script>"}) {
            assertFalse(EmojiGrapheme.isSingleEmoji(s), "red bekleniyordu: [" + s + "]");
        }
        assertFalse(EmojiGrapheme.isSingleEmoji(null));
    }

    @Test
    void rejectsTooLong() {
        assertFalse(EmojiGrapheme.isSingleEmoji("👍".repeat(9)), "cok emoji");
        // ZWJ ile bagli ama 16 UTF-16 birimini asan dizi
        assertFalse(EmojiGrapheme.isSingleEmoji("👨‍👩‍👧‍👦‍👦‍👦"));
        assertFalse(EmojiGrapheme.isSingleEmoji("x".repeat(200)));
    }
}
