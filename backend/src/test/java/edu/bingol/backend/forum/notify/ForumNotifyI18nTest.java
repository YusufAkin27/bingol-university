package edu.bingol.backend.forum.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.i18n.Lang;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.ResourceBundleMessageSource;

/** Forum bildirim metinleri tr/en/ar eksiksiz; anahtarlar ForumNotifier'in urettigi adlarla eslesir. */
class ForumNotifyI18nTest {

    private static ResourceBundleMessageSource source() {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/forumn");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        return ms;
    }

    private static String msg(ResourceBundleMessageSource ms, String key, Lang lang, Object... args) {
        return ms.getMessage(key, args, "??" + key, lang.locale());
    }

    @Test
    void everyKindAndModerationActionHasTitleAndBodyInAllLanguages() {
        ResourceBundleMessageSource ms = source();
        List<String> bases = new ArrayList<>();
        for (String b : List.of("topicComment", "commentReply", "commentLike", "topicLike", "followedTopic")) {
            bases.add("notif.forum." + b);
        }
        for (String a : List.of("REMOVE", "RESTORE", "LOCK", "UNLOCK", "PIN", "UNPIN")) {
            bases.add("notif.forum.moderation.topic." + a);
        }
        for (String a : List.of("REMOVE", "RESTORE")) {
            bases.add("notif.forum.moderation.comment." + a);
        }
        bases.add("notif.forum.moderation.other");
        List<String> problems = new ArrayList<>();
        for (Lang lang : Lang.values()) {
            for (String base : bases) {
                for (String suffix : List.of(".title", ".body")) {
                    String v = msg(ms, base + suffix, lang, "A", "B", "C");
                    if (v.startsWith("??") || v.isBlank()) {
                        problems.add(lang + " " + base + suffix);
                    }
                }
                if (base.contains("moderation") && msg(ms, base + ".bodyReason", lang, "A", "B").startsWith("??")) {
                    problems.add(lang + " " + base + ".bodyReason");
                }
            }
            for (String k : List.of("notif.forum.anon", "notif.forum.anonPlain", "share.label.FORUM_TOPIC",
                    "share.label.FORUM_COMMENT", "share.forum.anonymous", "share.preview.FORUM_TOPIC",
                    "share.preview.FORUM_COMMENT", "error.FORUM_SEARCH_QUERY_TOO_SHORT", "error.FORUM_SEARCH_BAD_SORT")) {
                if (msg(ms, k, lang, "1").startsWith("??")) {
                    problems.add(lang + " " + k);
                }
            }
        }
        assertEquals(List.of(), problems);
    }

    @Test
    void anonymousNamesCarryTheNumberInTheRecipientLanguage() {
        ResourceBundleMessageSource ms = source();
        assertEquals("Anonim #7", msg(ms, "notif.forum.anon", Lang.TR, "7"));
        assertEquals("Anonymous #7", msg(ms, "notif.forum.anon", Lang.EN, "7"));
        assertTrue(msg(ms, "notif.forum.anon", Lang.AR, "7").contains("#7"));
        assertNotEquals(msg(ms, "notif.forum.anonPlain", Lang.TR), msg(ms, "notif.forum.anonPlain", Lang.EN));
        assertTrue(Locale.forLanguageTag("ar").getLanguage().equals("ar"));
    }

    @Test
    void kindsMapToDistinctLedgerCodes() {
        List<String> codes = new ArrayList<>();
        for (ForumNotifyKind k : ForumNotifyKind.values()) {
            assertTrue(k.ledgerKind().length() <= 24);
            assertTrue(!codes.contains(k.ledgerKind()), "tekrar eden defter kodu " + k);
            codes.add(k.ledgerKind());
        }
        assertEquals(6, ForumNotifyKind.values().length);
    }
}
