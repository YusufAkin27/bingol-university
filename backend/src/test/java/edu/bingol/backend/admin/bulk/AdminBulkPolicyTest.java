package edu.bingol.backend.admin.bulk;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

/** P15: yikici toplu uclar sebep ister ve "yikici" sayilir; okuma (CSV, durum) istemez; maskeleme/dogrulama yardimcilari. */
class AdminBulkPolicyTest {

    @Test
    void bulkWritesNeedReasonAndAreDestructive() {
        for (String p : List.of("/api/admin/news/bulk", "/api/admin/academic/bulk", "/api/admin/menu/bulk-delete",
                "/api/admin/pending-registrations/bulk-cancel", "/api/admin/sources/sync")) {
            assertEquals(AdminGuardPolicy.DEFAULT_MIN_REASON, AdminGuardPolicy.reasonMin("POST", p), p);
            assertTrue(AdminGuardPolicy.destructive("POST", p), p);
        }
    }

    @Test
    void readsAndSingleItemEndpointsAreUnchanged() {
        for (String p : List.of("/api/admin/news/export.csv", "/api/admin/academic/export.csv", "/api/admin/menu/export.csv",
                "/api/admin/pending-registrations/export.csv", "/api/admin/sources/status")) {
            assertEquals(0, AdminGuardPolicy.reasonMin("GET", p), p);
            assertFalse(AdminGuardPolicy.destructive("GET", p), p);
        }
        // mevcut tekil uclar degismedi (haber gizleme/duzenleme hariç: T-013 ile gerekce ister)
        assertEquals(5, AdminGuardPolicy.reasonMin("PATCH", "/api/admin/news/5"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/sync"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/sources/status"));
    }

    @Test
    void masksEmailsAndNames() {
        assertEquals("226***@bingol.edu.tr", BulkSupport.maskEmail("226051015@bingol.edu.tr"));
        assertEquals("a***@bingol.edu.tr", BulkSupport.maskEmail("ali@bingol.edu.tr"));
        assertEquals("", BulkSupport.maskEmail(null));
        assertEquals("A*** V***", BulkSupport.maskName("Ali  Veli"));
        assertEquals("", BulkSupport.maskName(" "));
    }

    @Test
    void distinctDedupesAndEnforcesBounds() {
        assertEquals(List.of(1L, 2L), BulkSupport.distinct(java.util.Arrays.asList(1L, 2L, 1L, null), 5));
        assertEquals("BULK_EMPTY", assertThrows(ApiException.class, () -> BulkSupport.distinct(List.of(), 5)).code());
        assertEquals("BULK_EMPTY", assertThrows(ApiException.class, () -> BulkSupport.distinct(List.of(" "), 5)).code());
        assertEquals("BULK_LIMIT_EXCEEDED",
                assertThrows(ApiException.class, () -> BulkSupport.distinct(List.of(1, 2, 3), 2)).code());
    }

    @Test
    void reasonNeedsFiveCharacters() {
        assertEquals("yeterli sebep", BulkSupport.reason("  yeterli sebep "));
        assertEquals("REASON_REQUIRED", assertThrows(ApiException.class, () -> BulkSupport.reason("abcd")).code());
        assertEquals("REASON_REQUIRED", assertThrows(ApiException.class, () -> BulkSupport.reason(null)).code());
    }
}
