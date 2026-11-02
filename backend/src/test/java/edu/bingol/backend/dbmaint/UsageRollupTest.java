package edu.bingol.backend.dbmaint;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Gun secimi ve SQL'in guvenlik ozellikleri. Toplulastirma sorgularinin kendisi PostgreSQL'e ozeldir:
 * scripts/smoke-usage-stats.sh dogrular.
 */
class UsageRollupTest {

    private static final LocalDate TODAY = LocalDate.parse("2026-11-02");

    @Test
    void firstRunBackfillsRawRetentionWindow() {
        List<LocalDate> days = UsageRollup.daysToRoll(TODAY, null, 2);
        assertEquals(TODAY.minusDays(UsageRollup.MAX_CATCHUP_DAYS), days.get(0));
        assertEquals(TODAY.minusDays(1), days.get(days.size() - 1));
    }

    @Test
    void recomputesLastNDaysEvenWhenComplete() {
        List<LocalDate> days = UsageRollup.daysToRoll(TODAY, TODAY.minusDays(1), 2);
        assertEquals(List.of(TODAY.minusDays(2), TODAY.minusDays(1)), days);
    }

    @Test
    void rollsMissingDaysAfterLastComplete() {
        List<LocalDate> days = UsageRollup.daysToRoll(TODAY, TODAY.minusDays(5), 0);
        assertEquals(4, days.size());
        assertEquals(TODAY.minusDays(4), days.get(0));
    }

    @Test
    void neverIncludesToday() {
        assertFalse(UsageRollup.daysToRoll(TODAY, TODAY.minusDays(1), 30).contains(TODAY));
    }

    @Test
    void outputTablesNeverCarryUserIdentity() {
        UsageRollup.statements().forEach((name, sql) -> {
            if (!name.equals("temp")) {
                java.util.regex.Matcher m = java.util.regex.Pattern
                        .compile("INSERT INTO (analytics_\\w+) \\(([^)]*)\\)").matcher(sql);
                assertTrue(m.find(), name);
                assertFalse(java.util.Arrays.stream(m.group(2).split(",")).map(String::trim).anyMatch(c -> c.equals("user_id") || c.equals("email")),
                        name + ": hedef tabloda kullanici kimligi sutunu olmamali");
            }
        });
        assertTrue(UsageRollup.statements().get("segment").contains("kind = 'platform' OR users >= :k"));
        assertTrue(UsageRollup.statements().get("temp").contains("ON COMMIT DROP"));
    }
}
