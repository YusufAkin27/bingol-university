package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.jayway.jsonpath.JsonPath;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Sunucu/Docker olmadan OpenAPI belgesini uretir ve yapisini dogrular (MockMvc, H2 baglami).
 * Belge target/openapi.json'a yazilir; -Dopenapi.out=../docs/openapi.json verilirse oraya da yazilir
 * (kanonik docs/openapi.json icin canli sunucudan `node scripts/openapi-gen.js` tercih edilir; bu test CI icindir).
 */
@SpringBootTest
class OpenApiDocTest {

    @Autowired
    WebApplicationContext ctx;

    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    private String fetch(String path) throws Exception {
        return mvc.perform(get(path).with(httpBasic("admin", "test-admin-pw")))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    @Test
    void docsAreAdminOnlyAndSwaggerUiIsOffByDefault() throws Exception {
        assertEquals(401, mvc.perform(get("/v3/api-docs")).andReturn().getResponse().getStatus());
        assertEquals(200, mvc.perform(get("/v3/api-docs").with(httpBasic("admin", "test-admin-pw")))
                .andReturn().getResponse().getStatus());
        // uretim varsayilani: arayuz kapali (dev profilinde acilir)
        assertEquals(404, mvc.perform(get("/swagger-ui.html").with(httpBasic("admin", "test-admin-pw")))
                .andReturn().getResponse().getStatus());
    }

    @Test
    void documentHasSecurityGroupsAndContracts() throws Exception {
        String json = fetch("/v3/api-docs");
        assertNotNull(JsonPath.read(json, "$.components.securitySchemes.bearerAuth"));
        assertEquals("bearer", JsonPath.read(json, "$.components.securitySchemes.bearerAuth.scheme"));
        assertNotNull(JsonPath.read(json, "$.components.schemas.ApiError"));

        // herkese acik uc kimliksiz, kimlikli uc Bearer ister, yonetici uc 403 belgeler
        assertEquals(0, ((List<?>) JsonPath.read(json, "$.paths['/api/auth/login'].post.security")).size());
        assertEquals("bearerAuth", ((Map<?, ?>) ((List<?>) JsonPath.read(json, "$.paths['/api/users/me'].get.security"))
                .get(0)).keySet().iterator().next());
        assertNotNull(JsonPath.read(json, "$.paths['/api/admin/users'].get.responses['403']"));

        // dosya yuklemeleri multipart; ResponseEntity ile secilen durum kodlari belgeli
        assertNotNull(JsonPath.read(json, "$.paths['/api/users/me/avatar'].post.requestBody.content['multipart/form-data']"));
        assertNotNull(JsonPath.read(json, "$.paths['/api/conversations'].post.responses['201']"));
        assertNotNull(JsonPath.read(json, "$.paths['/api/events'].post.responses['202']"));

        // ayni adli ic DTO'lar carpismaz (MemberView topluluk/mesajlasma)
        Map<String, Object> schemas = JsonPath.read(json, "$.components.schemas");
        assertTrue(schemas.containsKey("CommunityDtosMemberView") && schemas.containsKey("MessagingDtosMemberView"),
                "carpisan MemberView sema adlari ayrismali: " + schemas.keySet());

        // zorunlu olmayan alanlar null olabilir
        List<?> t = JsonPath.read(json, "$.components.schemas.ProfileView.properties.bio.type");
        assertTrue(t.contains("null"));

        Path out = Path.of("target", "openapi.json");
        Files.createDirectories(out.getParent());
        Files.writeString(out, json, StandardCharsets.UTF_8);
        String extra = System.getProperty("openapi.out");
        if (extra != null && !extra.isBlank()) {
            Files.writeString(Path.of(extra), json, StandardCharsets.UTF_8);
        }
    }

    @Test
    void groupsSplitPublicAuthenticatedAdmin() throws Exception {
        String pub = fetch("/v3/api-docs/1-public");
        String usr = fetch("/v3/api-docs/2-authenticated");
        String adm = fetch("/v3/api-docs/3-admin");
        assertNotNull(JsonPath.read(pub, "$.paths['/api/news']"));
        assertFalse(((Map<?, ?>) JsonPath.read(pub, "$.paths")).containsKey("/api/users/me"));
        assertNotNull(JsonPath.read(usr, "$.paths['/api/users/me']"));
        assertFalse(((Map<?, ?>) JsonPath.read(usr, "$.paths")).containsKey("/api/admin/users"));
        assertNotNull(JsonPath.read(adm, "$.paths['/api/admin/users']"));
    }
}
