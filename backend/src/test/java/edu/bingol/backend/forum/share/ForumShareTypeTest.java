package edu.bingol.backend.forum.share;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.share.ShareType;
import org.junit.jupiter.api.Test;

class ForumShareTypeTest {

    @Test
    void forumTypesHaveLinkCodesAndParseByNameOrCode() {
        assertEquals("f", ShareType.FORUM_TOPIC.code());
        assertEquals("fc", ShareType.FORUM_COMMENT.code());
        assertEquals(ShareType.FORUM_TOPIC, ShareType.ofCode("f"));
        assertEquals(ShareType.FORUM_COMMENT, ShareType.ofCode("fc"));
        assertEquals(ShareType.FORUM_COMMENT, ShareType.parse("forum_comment"));
        assertNull(ShareType.ofCode("ff"));
        assertTrue(ShareType.FORUM_TOPIC.isForum() && ShareType.FORUM_COMMENT.isForum());
        assertFalse(ShareType.POST.isForum());
        // message.share_type VARCHAR(16) (V1441)
        for (ShareType t : ShareType.values()) {
            assertTrue(t.name().length() <= 16, t.name());
        }
    }

    @Test
    void clipIsCodePointSafeAndCollapsesWhitespace() {
        assertEquals("a b", ShareTexts.clip("  a \n  b ", 10));
        assertEquals("abc…", ShareTexts.clip("abcdef", 4));
        assertEquals("", ShareTexts.clip(null, 5));
        String emoji = "😀".repeat(10);
        String clipped = ShareTexts.clip(emoji, 5);
        assertEquals(5, clipped.codePointCount(0, clipped.length()));
    }
}
