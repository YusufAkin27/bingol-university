package edu.bingol.backend.catalog;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentMatchers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class CatalogControllerTest {

    private final ClientIp clientIp = mock(ClientIp.class);
    private final MockMvc mvc;

    CatalogControllerTest() {
        when(clientIp.of(ArgumentMatchers.any())).thenReturn("1.2.3.4");
        mvc = MockMvcBuilders.standaloneSetup(
                new CatalogController(new CatalogService(), mock(RateLimiter.class), clientIp)).build();
    }

    @Test
    void academicReturnsWholeCatalogWithPublicCache() throws Exception {
        mvc.perform(get("/api/catalog/academic"))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "max-age=86400, public"))
                .andExpect(jsonPath("$.version").value(2))
                .andExpect(jsonPath("$.faculties[0].id").value("muhendislik"))
                .andExpect(jsonPath("$.faculties[0].departments[0].name").value("Bilgisayar Mühendisliği"))
                .andExpect(jsonPath("$.faculties[0].name").value("Mühendislik Fakültesi"))
                .andExpect(jsonPath("$.faculties[0].nameEn").value("Faculty of Engineering"))
                .andExpect(jsonPath("$.faculties[0].nameAr").value("كلية الهندسة"))
                .andExpect(jsonPath("$.faculties[0].departments[0].nameEn").value("Computer Engineering"))
                .andExpect(jsonPath("$.faculties[0].departments[0].nameAr").value("هندسة الحاسوب"))
                .andExpect(jsonPath("$.grades[0].id").value("PREP"))
                .andExpect(jsonPath("$.grades[0].nameEn").value("Prep year"))
                .andExpect(jsonPath("$.grades[1].nameAr").value("السنة 1"));
    }

    @Test
    void departmentSearchFindsAccentInsensitive() throws Exception {
        String json = mvc.perform(get("/api/catalog/departments").param("q", "muh").param("limit", "30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(30))
                .andExpect(jsonPath("$[0].faculty").exists())
                .andExpect(jsonPath("$[0].department").exists())
                .andExpect(jsonPath("$[0].departmentEn").exists())
                .andExpect(jsonPath("$[0].departmentAr").exists())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        assertTrue(json.contains("Mühendisli"));
        mvc.perform(get("/api/catalog/departments").param("q", "muh").param("limit", "999"))
                .andExpect(jsonPath("$.length()").value(30));
        mvc.perform(get("/api/catalog/departments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }
}
