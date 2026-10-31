package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.common.ApiException;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

/** P09: yeni yazma uclari sebep ister / yikici sayilir; genisletilmis kullanici suzgeci guvenli SQL uretir. */
class UserExtrasGuardPolicyTest {

    @Test
    void newWritesRequireReasons() {
        assertEquals(5, AdminGuardPolicy.reasonMin("PATCH", "/api/admin/users/7/profile"));
        assertEquals(5, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/users/7/push-devices/3"));
        assertEquals(5, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/users/7/sessions/aaaaaaaaaaaaaaaa"));
        assertEquals(20, AdminGuardPolicy.reasonMin("POST", "/api/admin/users/7/export"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/users/bulk")); // mevcut BULK kurali
    }

    @Test
    void newWritesAreDestructiveAndReadsAreNot() {
        assertTrue(AdminGuardPolicy.destructive("PATCH", "/api/admin/users/7/profile"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/users/7/push-devices/3"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/users/7/export"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/users/bulk"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/users/7/sessions"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/users/7/push-devices"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/users/7/notifications"));
        assertFalse(AdminGuardPolicy.destructive("GET", "/api/admin/users/7/notifications"));
    }

    @Test
    void existingRulesAreUntouched() {
        assertEquals(5, AdminGuardPolicy.reasonMin("PATCH", "/api/admin/users/7/role"));
        assertEquals(5, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/users/7"));
        // T-013: oturum kapatma/sifirlama/dogrulama artik gerekce ister (5) ve yikici sayilir
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/users/7/revoke-sessions"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/users/7/revoke-sessions"));
        assertEquals(0, AdminGuardPolicy.reasonMin("PATCH", "/api/admin/users/7/other"));
    }

    @Test
    void dateRangesAreBoundNotConcatenated() {
        UserFilter f = new UserFilter(null, null, null, null, null, null, null, null,
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), LocalDate.of(2026, 2, 1), null);
        UserFilter.Where w = f.where();
        assertEquals("created_at >= :createdFrom AND created_at < :createdTo AND last_seen_at >= :seenFrom", w.sql());
        // bitis gunu DAHIL: ertesi gun 00:00 (Istanbul) dislayici sinir
        assertEquals(java.time.LocalDate.of(2026, 2, 1).atStartOfDay(java.time.ZoneId.of("Europe/Istanbul")).toOffsetDateTime(),
                w.params().getValue("createdTo"));
        assertFalse(w.sql().contains("2026"));
    }

    @Test
    void reversedRangeIs400AndNewSortFieldsAreWhitelisted() {
        UserFilter bad = new UserFilter(null, null, null, null, null, null, null, null,
                LocalDate.of(2026, 3, 2), LocalDate.of(2026, 3, 1), null, null);
        assertEquals(400, assertThrows(ApiException.class, bad::where).status().value());

        assertEquals("lower(faculty) ASC NULLS LAST, id ASC", UserFilter.orderBy("faculty,asc"));
        assertEquals("role DESC NULLS LAST, id DESC", UserFilter.orderBy("role,desc"));
        assertEquals(400, assertThrows(ApiException.class, () -> UserFilter.orderBy("password_hash,asc")).status().value());
        assertEquals(400, assertThrows(ApiException.class, () -> UserFilter.orderBy("id; DROP TABLE x,asc")).status().value());
        // e-posta ile siralama kasitli olarak kapali (UserFilterTest)
        assertEquals(400, assertThrows(ApiException.class, () -> UserFilter.orderBy("email,asc")).status().value());
    }
}
