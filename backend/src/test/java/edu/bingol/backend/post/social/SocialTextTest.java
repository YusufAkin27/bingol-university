package edu.bingol.backend.post.social;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** @etiket ve #etiket ayristiricilari: Turkce i/ı kurali, sinirlar, kotuye kullanim. */
class SocialTextTest {

    @Test
    void mentionsAreParsedDistinctAndInOrder() {
        String t = "Selam @[Ayşe Yılmaz](uid:12) ve @[Ali Veli](uid:7), tekrar @[Ayşe Yılmaz](uid:12)";
        assertEquals(List.of(12L, 7L), SocialText.mentionedIds(t));
        assertEquals(3, SocialText.countMentions(t));
    }

    @Test
    void malformedMentionsAreIgnored() {
        assertTrue(SocialText.mentionedIds("@[Ad](uid:abc) @Ad(uid:3) @[](uid:3) @[Ad](uid:)").isEmpty());
        assertTrue(SocialText.mentionedIds(null).isEmpty());
        // satir sonu iceren ad etiket sayilmaz
        assertTrue(SocialText.mentionedIds("@[A\nB](uid:5)").isEmpty());
    }

    @Test
    void mentionListIsCappedAtTen() {
        StringBuilder b = new StringBuilder();
        for (int i = 1; i <= 15; i++) {
            b.append("@[K").append(i).append("](uid:").append(i).append(") ");
        }
        assertEquals(10, SocialText.mentionedIds(b.toString()).size());
        assertEquals(15, SocialText.countMentions(b.toString()));
    }

    @Test
    void hashtagsUseTurkishLowercaseAndFold() {
        Map<String, String> m = SocialText.hashtags("Bugün #Ataturk ve #ATATÜRK ve #IŞIK #İstanbul");
        // Ataturk / ATATÜRK ayni anahtar (atatürk -> aksansiz ataturk); ilk gorulen gorunur ad
        assertEquals("ataturk", m.keySet().iterator().next());
        assertEquals("ataturk", m.get("ataturk"));
        assertEquals("ışık", m.get("isik"));
        assertEquals("istanbul", m.get("istanbul"));
        assertEquals(3, m.size());
    }

    @Test
    void turkishDottedAndDotlessI() {
        assertEquals("ı", SocialText.display("I"));
        assertEquals("i", SocialText.display("İ"));
        assertEquals("isik", SocialText.fold("IŞIK"));
        assertEquals("isik", SocialText.fold("#ışık"));
        assertEquals("gocmen", SocialText.fold("GÖÇMEN"));
    }

    @Test
    void hashtagBoundaries() {
        assertTrue(SocialText.hashtags("#a #1 #22 sade").keySet().stream().noneMatch(k -> k.length() < 2));
        assertTrue(SocialText.hashtags("#a").isEmpty(), "tek harf etiket degil");
        assertTrue(SocialText.hashtags("#12345").isEmpty(), "yalniz rakam etiket degil");
        assertEquals(1, SocialText.hashtags("#ab").size());
        assertEquals(1, SocialText.hashtags("#" + "a".repeat(40)).size());
        assertTrue(SocialText.hashtags("#" + "a".repeat(41)).isEmpty(), "41 karakter reddedilir");
    }

    @Test
    void hashtagNotInsideUrlsEmailsOrWords() {
        assertTrue(SocialText.hashtags("https://x.com/a#bolum mail@x.com#abc kelime#abc").isEmpty());
        assertTrue(SocialText.hashtags("##çift").isEmpty());
        assertEquals(1, SocialText.hashtags("(#bahar) ").size());
    }

    @Test
    void hashtagsCappedAtTenAndMentionNamesIgnored() {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < 15; i++) {
            b.append("#tag").append((char) ('a' + i)).append(' ');
        }
        assertEquals(10, SocialText.hashtags(b.toString()).size());
        // etiket gorunen adi icindeki # etiket sayilmaz
        assertTrue(SocialText.hashtags("@[Ali #kral](uid:3)").isEmpty());
    }

    @Test
    void validTagChecks() {
        assertTrue(SocialText.validTag("bahar"));
        assertTrue(SocialText.validTag("#Çınar_2"));
        assertFalse(SocialText.validTag("a"));
        assertFalse(SocialText.validTag("a b"));
        assertFalse(SocialText.validTag("x".repeat(41)));
        assertFalse(SocialText.validTag(null));
    }

    @Test
    void stripMentionsRemovesFormat() {
        assertFalse(SocialText.stripMentions("a @[B](uid:1) c").contains("uid"));
    }
}
