package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class MessageTextTest {

    @Test
    void keepsPlainTextAsIs() {
        assertEquals("a < b & c <script>alert(1)</script>", MessageText.clean("a < b & c <script>alert(1)</script>"));
        assertEquals("Merhaba Bingöl 👋", MessageText.clean("  Merhaba Bingöl 👋 \n"));
    }

    @Test
    void stripsControlBidiAndZeroWidthCharacters() {
        assertEquals("abc", MessageText.clean("a\u0000b‮c​﻿"));
        assertEquals("a\tb\nc", MessageText.clean("a\tb\r\nc"));
    }

    @Test
    void collapsesBlankLinesAndDropsLoneSurrogates() {
        assertEquals("a\n\nb", MessageText.clean("a\n\n\n\n\nb"));
        assertEquals("ab", MessageText.clean("a\uD800b"));
    }

    @Test
    void nullAndBlankBecomeEmpty() {
        assertEquals("", MessageText.clean(null));
        assertEquals("", MessageText.clean(" ​ \n"));
    }
}
