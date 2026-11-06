package edu.bingol.backend.forum.comment;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import edu.bingol.backend.forum.topic.ForumText;
import org.junit.jupiter.api.Test;

/** QA5-10: konu, yorum ve gerekce metni TEK temizleyiciden gecer; ayni girdi her yerde ayni sonucu verir. */
class ForumTextUnifiedTest {

    private static final String[] SAMPLES = {
            "Merhaba  <b>dunya</b>\r\n\r\n\r\n\r\nson",
            "a < b ve c > d",
            "<script>alert(1)</script>temiz",
            "<scr<script>ipt>x</scr</script>ipt>",
            "gizli\u200Bmetin\u202Ebidi\u00ADx",
            "javascript:alert(1)",
            "  bosluklu\t satir \n  ikinci  ",
            "<!-- yorum -->gorunen",
            "e\u0301 (NFC)",
    };

    @Test
    void commentAndTopicBodiesAgreeWithSanitizer() {
        for (String s : SAMPLES) {
            String expected = ForumTextSanitizer.multiLine(s);
            assertThat(ForumText.block(s)).as(s).isEqualTo(expected);
            String c = ForumCommentText.clean(s);
            assertThat(c == null ? "" : c).as(s).isEqualTo(expected);
            assertThat(ForumText.line(s)).as(s).isEqualTo(ForumTextSanitizer.singleLine(s));
        }
    }

    @Test
    void behaviourPreservedForCommonCases() {
        assertThat(ForumText.block("Merhaba <b>dunya</b>")).isEqualTo("Merhaba dunya");
        assertThat(ForumText.block("a < b")).isEqualTo("a < b");
        assertThat(ForumText.line("bir\niki")).isEqualTo("bir iki");
        assertThat(ForumText.block("x\n\n\n\ny")).isEqualTo("x\n\ny");
        assertThat(ForumText.block("<script>alert(1)</script>temiz")).isEqualTo("temiz");
        assertThat(ForumText.block("javascript:alert(1)")).isEqualTo("javascript:alert(1)"); // duz metin kalir
        assertThat(ForumCommentText.clean("   ")).isNull();
        assertThat(ForumCommentText.clean("<b></b>")).isNull();
        // ZWNJ/ZWJ emoji ve Arap/Fars yazisi icin korunur (yalniz iki yani ASCII ise silinir)
        assertThat(ForumText.block("\u0645\u06CC\u200C\u062E\u0648\u0627\u0647\u0645")).contains("\u200C");
    }
}
