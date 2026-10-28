package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** P11/P12: hangi yeni yazma uclari sebep ister / yikici sayilir (AdminGuardPolicy tablosu). */
class ModSupportGuardPolicyTest {

    private static final int MIN = AdminGuardPolicy.DEFAULT_MIN_REASON;

    @Test
    void destructiveModerationAndSupportWritesRequireReason() {
        assertEquals(MIN, AdminGuardPolicy.reasonMin("POST", "/api/admin/moderation/strikes/5/forgive"));
        assertEquals(MIN, AdminGuardPolicy.reasonMin("POST", "/api/admin/moderation/hidden/POST/9/restore"));
        assertEquals(MIN, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/moderation/reason-templates/3"));
        assertEquals(MIN, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/support/tickets/4"));
        assertEquals(MIN, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/support/feedback/4"));
        assertEquals(MIN, AdminGuardPolicy.reasonMin("POST", "/api/admin/support/feedback/merge"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/support/tickets/4"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/moderation/strikes/5/forgive"));
    }

    @Test
    void routineWritesAndReadsDoNotRequireReason() {
        for (String[] r : new String[][] {
                {"POST", "/api/admin/support/tickets/4/reopen"},
                {"PATCH", "/api/admin/support/tickets/4"},
                {"POST", "/api/admin/support/tickets/4/notes"},
                {"POST", "/api/admin/support/tickets/4/reply"},
                {"PUT", "/api/admin/faq/order"},
                {"POST", "/api/admin/moderation/reason-templates"},
                {"PUT", "/api/admin/moderation/reason-templates/3"},
                {"GET", "/api/admin/moderation/strikes"},
                {"GET", "/api/admin/support/tickets/export.csv"},
                {"GET", "/api/admin/reports/export.csv"}}) {
            assertEquals(0, AdminGuardPolicy.reasonMin(r[0], r[1]), r[0] + " " + r[1]);
            assertFalse(AdminGuardPolicy.destructive(r[0], r[1]), r[0] + " " + r[1]);
        }
    }
}
