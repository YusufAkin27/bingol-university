package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** P13: mail bastirma/kuyruk yazma uclari sebep ister ve yikici sayilir; okumalar ve kota istemez. */
class MailOpsGuardPolicyTest {

    private static final int MIN = AdminGuardPolicy.DEFAULT_MIN_REASON;

    @Test
    void suppressionAndQueueWritesRequireReasonAndAreDestructive() {
        for (String[] r : new String[][] {
                {"POST", "/api/admin/mail/suppressions"},
                {"DELETE", "/api/admin/mail/suppressions/12"},
                {"POST", "/api/admin/mail/outbox/9/retry"},
                {"POST", "/api/admin/mail/outbox/9/cancel"},
                {"POST", "/api/admin/mail/outbox/bulk"}}) {
            assertEquals(MIN, AdminGuardPolicy.reasonMin(r[0], r[1]), r[0] + " " + r[1]);
            assertTrue(AdminGuardPolicy.destructive(r[0], r[1]), r[0] + " " + r[1]);
        }
    }

    @Test
    void readsAndExistingMailAdminKeepTheirRules() {
        for (String[] r : new String[][] {
                {"GET", "/api/admin/mail/suppressions"},
                {"GET", "/api/admin/mail/suppressions/12"},
                {"GET", "/api/admin/mail/suppressions/export.csv"},
                {"GET", "/api/admin/mail/outbox"},
                {"GET", "/api/admin/mail/outbox/9"},
                {"GET", "/api/admin/mail/quota"},
                {"POST", "/api/admin/mail/templates"},
                {"POST", "/api/admin/mail/campaigns/3/pause"}}) {
            assertEquals(0, AdminGuardPolicy.reasonMin(r[0], r[1]), r[0] + " " + r[1]);
            assertFalse(AdminGuardPolicy.destructive(r[0], r[1]), r[0] + " " + r[1]);
        }
    }
}
