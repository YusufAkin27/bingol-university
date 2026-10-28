package edu.bingol.backend.notification.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminGuardPolicy;
import org.junit.jupiter.api.Test;

/** P14: iptal ve toplu islemler sebep ister ve yikici sayilir; yeniden deneme ve okumalar sebepsizdir. */
class PushAdminGuardPolicyTest {

    @Test
    void cancelAndBulkNeedReasonAndAreDestructive() {
        for (String path : new String[] {"/api/admin/push/outbox/12/cancel", "/api/admin/push/outbox/bulk"}) {
            assertEquals(AdminGuardPolicy.DEFAULT_MIN_REASON, AdminGuardPolicy.reasonMin("POST", path), path);
            assertTrue(AdminGuardPolicy.destructive("POST", path), path);
        }
    }

    @Test
    void retryAndReadsDoNotNeedReason() {
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/push/outbox/12/retry"));
        assertFalse(AdminGuardPolicy.destructive("POST", "/api/admin/push/outbox/12/retry"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/push/outbox/12/cancel"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/push/outbox"));
    }

    @Test
    void masking() {
        assertEquals("12345678...", PushMask.tokenRef("12345678abcdef"));
        assertNull(PushMask.tokenRef(null));
        assertNull(PushMask.tokenRef("abc"));
        assertEquals("1***5", PushMask.userRef(12345L));
        assertEquals("***", PushMask.userRef(12L));
        assertNull(PushMask.userRef(null));
    }
}
