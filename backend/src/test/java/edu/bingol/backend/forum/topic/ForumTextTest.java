package edu.bingol.backend.forum.topic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** Metin temizligi (XSS/gorunmez karakter) ve kart onizlemesi. */
class ForumTextTest {

    @Test
    void lineStripsTagsControlAndBidiCharactersAndCollapsesSpaces() {
        assertEquals("a b", ForumText.line("  a \t\n  b  "));
        assertEquals("", ForumText.line("<script>alert(1)</script>"), "QA5-10: script blogu icerigiyle silinir");
        assertEquals("x", ForumText.line("<img src=x onerror=alert(1)>x"));
        assertEquals("abc", ForumText.line("a​b‮c\u0000"));
        assertEquals("3 < 5 ve 7 > 2", ForumText.line("3 < 5 ve 7 > 2"), "etiket olmayan ifadeler korunur");
        assertEquals("", ForumText.line(null));
        assertEquals("", ForumText.line("<b></b> ​"));
    }

    @Test
    void blockKeepsParagraphsButLimitsBlankLines() {
        assertEquals("bir\n\niki", ForumText.block("bir\r\n\r\n\r\n\r\niki"));
        assertEquals("bir\niki", ForumText.block("  bir  \n iki  "), "satir basi/sonu bosluklari kirpilir (QA5-10)");
        assertEquals("", ForumText.block("  \n\n "));
        assertFalse(ForumText.block("<iframe src=javascript:alert(1)></iframe>govde").contains("<"));
    }

    @Test
    void previewCutsAtWordBoundaryWithEllipsis() {
        assertEquals("kisa metin", ForumText.preview("kisa\nmetin", 280));
        String longText = "kelime ".repeat(100);
        String p = ForumText.preview(longText, 280);
        assertTrue(p.length() <= 280, "uzunluk " + p.length());
        assertTrue(p.endsWith("…"));
        assertFalse(p.contains("kelim…"), "kelime ortasindan kesilmez");
        assertEquals("", ForumText.preview(null, 10));
    }
}
