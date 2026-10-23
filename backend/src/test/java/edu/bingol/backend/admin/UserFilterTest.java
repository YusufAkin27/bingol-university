package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import org.junit.jupiter.api.Test;

class UserFilterTest {

    private static UserFilter q(String q) {
        return new UserFilter(q, null, null, null, null, null, null, null);
    }

    @Test
    void likeWildcardsAreEscaped() {
        assertEquals("100\\%\\_\\\\x", UserFilter.escapeLike("100%_\\x"));
        UserFilter.Where w = q("50%_off").where();
        assertEquals("%50\\%\\_off%", w.params().getValue("q"));
    }

    @Test
    void searchTextNeverAppearsInSql() {
        UserFilter.Where w = q("x'; DROP TABLE app_user; --").where();
        assertFalse(w.sql().contains("DROP"));
        assertTrue(w.sql().contains(":q"));
    }

    @Test
    void emptyFilterMatchesEverything() {
        assertEquals("TRUE", q(null).where().sql());
        assertEquals("TRUE", q("   ").where().sql());
    }

    @Test
    void allFiltersAreBound() {
        UserFilter f = new UserFilter("ali", UserStatus.SUSPENDED, Role.ADMIN, "Muh", "Bil", (short) 3, "ar", true);
        UserFilter.Where w = f.where();
        assertEquals("SUSPENDED", w.params().getValue("status"));
        assertEquals("ADMIN", w.params().getValue("role"));
        assertEquals((short) 3, w.params().getValue("classYear"));
        assertEquals(true, w.params().getValue("verified"));
        assertEquals(8, w.sql().split(" AND ").length);
    }

    @Test
    void defaultSortIsNewestFirst() {
        assertEquals("created_at DESC NULLS LAST, id DESC", UserFilter.orderBy(null));
    }

    @Test
    void whitelistedSortFields() {
        assertEquals("last_seen_at ASC NULLS LAST, id ASC", UserFilter.orderBy("lastSeenAt,asc"));
        assertEquals("lower(display_name) DESC NULLS LAST, id DESC", UserFilter.orderBy("displayName,DESC"));
        assertEquals("created_at DESC NULLS LAST, id DESC", UserFilter.orderBy("createdAt"));
    }

    @Test
    void unknownSortFieldOrDirectionRejected() {
        for (String bad : new String[] {"password_hash,asc", "createdAt; DROP TABLE app_user,asc", "createdAt,sideways",
                "email,asc", "createdAt,asc,extra", "(select 1),asc"}) {
            ApiException e = assertThrows(ApiException.class, () -> UserFilter.orderBy(bad), bad);
            assertEquals(400, e.status().value());
        }
    }
}
