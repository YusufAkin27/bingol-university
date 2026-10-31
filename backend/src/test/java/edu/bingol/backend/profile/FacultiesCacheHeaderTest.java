package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimiter;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

/** T-075 (A7-10): GET /api/faculties herkese ayni cevap: public Cache-Control ile tarayici/CDN onbellegine acik. */
class FacultiesCacheHeaderTest {

    @Test
    void facultiesAreServedWithPublicCacheControl() {
        ProfileService profiles = mock(ProfileService.class);
        when(profiles.faculties()).thenReturn(List.of("Fen-Edebiyat", "Muhendislik"));
        ResponseEntity<List<String>> res = new ProfileController(profiles, mock(RateLimiter.class)).faculties();

        assertEquals(200, res.getStatusCode().value());
        assertEquals(List.of("Fen-Edebiyat", "Muhendislik"), res.getBody());
        String cc = res.getHeaders().getFirst("Cache-Control");
        assertEquals("public, max-age=300, stale-while-revalidate=600", cc);
    }
}
