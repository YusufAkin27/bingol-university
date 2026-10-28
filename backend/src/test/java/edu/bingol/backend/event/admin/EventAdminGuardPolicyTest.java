package edu.bingol.backend.event.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminGuardPolicy;
import org.junit.jupiter.api.Test;

/** P07: yeni yikici etkinlik uclari AdminGuardPolicy tablosunda (sebep zorunlu + saatlik siki sinir). */
class EventAdminGuardPolicyTest {

    @Test
    void destructiveEventOpsRequireReasonAndGetHourlyLimit() {
        String[][] destructive = {
                {"POST", "/api/admin/events/5/applications/9/accept"},
                {"POST", "/api/admin/events/5/applications/9/reject"},
                {"POST", "/api/admin/events/5/certificates/9/revoke"},
                {"DELETE", "/api/admin/events/5/feedback/3"},
                {"DELETE", "/api/admin/events/5/announcements/3"},
                {"DELETE", "/api/admin/events/5/organizers/9"},
                {"POST", "/api/admin/events/bulk"}};
        for (String[] d : destructive) {
            assertEquals(AdminGuardPolicy.DEFAULT_MIN_REASON, AdminGuardPolicy.reasonMin(d[0], d[1]), d[0] + " " + d[1]);
            assertTrue(AdminGuardPolicy.destructive(d[0], d[1]), d[0] + " " + d[1]);
        }
    }

    @Test
    void readsAndSafeWritesAreNotInTheTable() {
        // okumalar sebep istemez, yikici sayilmaz
        for (String p : new String[] {"/api/admin/events/5/applications", "/api/admin/events/5/attendance",
                "/api/admin/events/5/certificates", "/api/admin/events/5/feedback", "/api/admin/events/5/organizers",
                "/api/admin/events/5/attendance.csv", "/api/admin/events/export.csv"}) {
            assertEquals(0, AdminGuardPolicy.reasonMin("GET", p), p);
            assertFalse(AdminGuardPolicy.destructive("GET", p), p);
        }
        // yoklama duzeltmesi ve sertifika geri alma saatlik sinira girmez (sebep @AdminReasonRequired ile istenir)
        assertFalse(AdminGuardPolicy.destructive("PUT", "/api/admin/events/5/attendance/9"));
        assertFalse(AdminGuardPolicy.destructive("POST", "/api/admin/events/5/certificates/9/restore"));
        // mevcut moderasyon uclari degismedi
        assertFalse(AdminGuardPolicy.destructive("POST", "/api/admin/events/5/hide"));
    }
}
