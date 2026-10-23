package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

class CorsConfigTest {

    private static CorsConfiguration forPath(List<String> origins, String path) {
        UrlBasedCorsConfigurationSource src = CorsConfig.source(origins);
        MockHttpServletRequest req = new MockHttpServletRequest("GET", path);
        req.setServletPath(path);
        return src.getCorsConfiguration(req);
    }

    @Test
    void appliesOnlyToApiAndFiles() {
        List<String> o = List.of("http://localhost:5173");
        assertNotNull(forPath(o, "/api/app/info"));
        assertNotNull(forPath(o, "/api/admin/users"));
        assertNotNull(forPath(o, "/files/avatars/a.png"));
        assertNull(forPath(o, "/actuator/health"));
        assertNull(forPath(o, "/ws"));
    }

    @Test
    void originsMethodsAndHeadersFromContract() {
        CorsConfiguration c = forPath(List.of("http://localhost:5173", "http://localhost:3000"), "/api/x");

        assertEquals(List.of("http://localhost:5173", "http://localhost:3000"), c.getAllowedOrigins());
        assertEquals(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"), c.getAllowedMethods());
        assertEquals(List.of("Authorization", "Content-Type", "Accept-Language"), c.getAllowedHeaders());
        assertEquals(false, c.getAllowCredentials());
        assertEquals("http://localhost:5173", c.checkOrigin("http://localhost:5173"));
        assertNull(c.checkOrigin("https://evil.example"));
    }

    @Test
    void emptyOriginListAllowsNothing() {
        assertNull(forPath(List.of(), "/api/x").checkOrigin("http://localhost:5173"));
    }

    @Test
    void propertiesParseCommaSeparatedList() {
        assertEquals(List.of("a", "b"), new CorsProperties(List.of(" a", "b ", "")).origins());
        assertTrue(new CorsProperties(null).origins().isEmpty());
    }
}
