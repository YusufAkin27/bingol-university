package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import org.junit.jupiter.api.Test;

/** Kampus haritasi uclarinin HTTP onbellek ilkesi (private max-age; yetkili istekte PublicCacheInterceptor "private" yazar). */
class PublicCacheInterceptorCampusTest {

    @Test
    void campusPaths() {
        assertEquals(300, PublicCacheInterceptor.policyFor("/api/campus/map").maxAge());
        assertEquals(60, PublicCacheInterceptor.policyFor("/api/campus/places").maxAge());
        assertEquals(300, PublicCacheInterceptor.policyFor("/api/campus/places/12").maxAge());
        assertNull(PublicCacheInterceptor.policyFor("/api/campus/places/abc"));
        assertNull(PublicCacheInterceptor.policyFor("/api/admin/campus/places"));
    }
}
