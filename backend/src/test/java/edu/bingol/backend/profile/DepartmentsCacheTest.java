package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

/** FIX-P08 / A07#8: GET /api/departments her cagrida app_user DISTINCT taramasi yapmaz; Cache-Control public. */
class DepartmentsCacheTest {

    private static ProfileService service(UserRepository users) {
        return new ProfileService(users, null, null, null, null, null, null, null, null, null, null, null, null);
    }

    @Test
    void departmentsAreCachedForFiveMinutes() {
        UserRepository users = mock(UserRepository.class);
        when(users.distinctDepartments()).thenReturn(List.of("Hukuk", "Tarih"));
        ProfileService s = service(users);
        AtomicLong now = new AtomicLong(1_000_000L);
        s.clockMs = now::get;

        assertEquals(List.of("Hukuk", "Tarih"), s.departments());
        now.addAndGet(60_000L);
        assertEquals(List.of("Hukuk", "Tarih"), s.departments());
        verify(users, times(1)).distinctDepartments();

        now.addAndGet(ProfileService.DEPARTMENTS_TTL_MS);
        when(users.distinctDepartments()).thenReturn(List.of("Hukuk", "Tarih", "Felsefe"));
        assertEquals(3, s.departments().size());
        verify(users, times(2)).distinctDepartments();
    }

    @Test
    void departmentsAreServedWithPublicCacheControl() {
        ProfileService profiles = mock(ProfileService.class);
        when(profiles.departments()).thenReturn(List.of("Hukuk"));
        ResponseEntity<List<String>> res = new ProfileController(profiles, mock(RateLimiter.class)).departments();

        assertEquals(List.of("Hukuk"), res.getBody());
        assertEquals("public, max-age=300, stale-while-revalidate=600", res.getHeaders().getFirst("Cache-Control"));
    }
}
