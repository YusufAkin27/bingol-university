package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Properties;
import org.junit.jupiter.api.Test;

/** T12 anahtarlarinin uc dilde de bulunmasi ve hedef turu uzunlugu (report.target_type VARCHAR(16)). */
class ModerationI18nTest {

    private static final List<String> FILES = List.of("messages.properties", "messages_en.properties", "messages_ar.properties");

    private static Properties load(String name) throws Exception {
        Properties p = new Properties();
        try (InputStream in = ModerationI18nTest.class.getResourceAsStream("/i18n/" + name);
             InputStreamReader r = new InputStreamReader(in, StandardCharsets.UTF_8)) {
            p.load(r);
        }
        return p;
    }

    @Test
    void allModerationKeysExistInThreeLanguages() throws Exception {
        List<String> keys = new java.util.ArrayList<>(List.of(
                "error.REPORTING_RESTRICTED", "error.REASON_CODE_INVALID", "error.APPEAL_TARGET_NOT_FOUND",
                "error.APPEAL_NOT_ALLOWED", "error.APPEAL_ALREADY_EXISTS", "error.APPEAL_NOT_FOUND",
                "error.TARGET_NOT_REVERSIBLE", "error.BLOCKLIST_HASH_INVALID", "error.BLOCKLIST_ENTRY_NOT_FOUND",
                "error.RECOMMENDATION_NOT_FOUND"));
        for (DecisionReason r : DecisionReason.values()) {
            keys.add(r.messageKey());
        }
        for (String k : List.of("autohidden", "removed", "restored", "reporter.actioned", "reporter.dismissed",
                "reporter.restricted", "appeal.accepted", "appeal.rejected", "admin.appeal", "admin.recommend")) {
            keys.add("notif.mod." + k + ".title");
            keys.add("notif.mod." + k + ".body");
        }
        for (String f : FILES) {
            Properties p = load(f);
            for (String k : keys) {
                assertTrue(p.containsKey(k), f + " eksik: " + k);
                assertFalse(p.getProperty(k).isBlank(), f + " bos: " + k);
            }
        }
    }

    @Test
    void noApostropheInParameterizedMessages() throws Exception {
        for (String f : FILES) {
            Properties p = load(f);
            for (String k : p.stringPropertyNames()) {
                if (k.startsWith("notif.mod.") || k.startsWith("mod.reason.")) {
                    assertFalse(p.getProperty(k).contains("'"), f + " kesme isareti: " + k);
                }
            }
        }
    }

    @Test
    void targetTypeNamesFitColumn() {
        for (ReportTargetType t : ReportTargetType.values()) {
            assertTrue(t.name().length() <= 16, t.name());
        }
    }
}
