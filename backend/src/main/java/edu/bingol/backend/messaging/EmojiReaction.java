package edu.bingol.backend.messaging;

import java.util.regex.Pattern;

/** A single emoji grapheme, including flags, keycaps, skin tones and ZWJ families. */
final class EmojiReaction {
    private static final Pattern GRAPHEME = Pattern.compile("\\A\\X\\z");

    private EmojiReaction() {}

    static boolean valid(String value) {
        if (value == null || value.isBlank() || value.length() > 16 || !GRAPHEME.matcher(value).matches()) {
            return false;
        }
        return value.codePoints().anyMatch(c -> (c >= 0x1F000 && c <= 0x1FAFF)
                || (c >= 0x2600 && c <= 0x27BF) || (c >= 0x2300 && c <= 0x23FF)
                || (c >= 0x2B00 && c <= 0x2BFF) || (c >= 0x2190 && c <= 0x21FF)
                || c == 0xA9 || c == 0xAE || c == 0x203C || c == 0x2049 || c == 0x2122
                || c == 0x2139 || c == 0x3030 || c == 0x303D || c == 0x3297 || c == 0x3299 || c == 0x20E3);
    }
}
