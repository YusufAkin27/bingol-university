package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class TextsTest {

    @Test
    void slugifyTransliteratesTurkishAndCollapsesSeparators() {
        assertEquals("yazilim-kulubu", Texts.slugify("Yazılım  Kulübü!"));
        assertEquals("cigdem-sogut-gunes", Texts.slugify("Çiğdem Söğüt Güneş"));
        assertEquals("istanbul", Texts.slugify("İSTANBUL"));
    }

    @Test
    void slugifyFallsBackWhenNothingUsable() {
        assertEquals("topluluk", Texts.slugify("!!!"));
    }

    @Test
    void slugifyTruncatesLongNames() {
        assertEquals(60, Texts.slugify("a".repeat(200)).length());
    }

    @Test
    void likePatternEscapesWildcards() {
        assertEquals("%50!%!_x%", Texts.likePattern("50%_x"));
        assertEquals("", Texts.likePattern("  "));
        assertEquals("", Texts.likePattern(null));
    }
}
