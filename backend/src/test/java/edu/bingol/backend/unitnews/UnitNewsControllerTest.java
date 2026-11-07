package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.filter.ShallowEtagHeaderFilter;

/**
 * /api/news/unit HTTP katmani: anonim 401, baska kapsamdaki duyuru 404, kisisel yanit icin
 * {@code Cache-Control: private, no-store} ve ETag'in uretilmemesi (A9).
 */
@SpringBootTest
class UnitNewsControllerTest {

    @Autowired WebApplicationContext ctx;
    @Autowired UnitSourceRepository sources;
    @Autowired UnitDepartmentRepository depts;
    @Autowired UnitAnnouncementRepository anns;
    @Autowired UserRepository users;
    MockMvc mvc;
    long annId;

    @BeforeEach
    void seed() {
        anns.deleteAll();
        depts.deleteAll();
        sources.deleteAll();
        UnitSource s = new UnitSource();
        s.setCode("mmf");
        s.setName("Mühendislik ve Mimarlık Fakültesi");
        s.setKind(UnitSource.Kind.FACULTY);
        s.setBaseUrl("https://mmf.bingol.edu.tr");
        s.setFacultyKeys("muhendislik fakultesi");
        sources.saveAndFlush(s);
        UnitDepartment d = new UnitDepartment();
        d.setSourceCode("mmf");
        d.setSlug("bilgisayar-muhendisligi");
        d.setName("Bilgisayar Mühendisliği");
        d.setNameKey(UnitKeys.deptKey("Bilgisayar Mühendisliği"));
        depts.saveAndFlush(d);
        UnitAnnouncement a = new UnitAnnouncement();
        a.setSourceCode("mmf");
        a.setTitle("Genel duyuru");
        a.setUrl("https://mmf.bingol.edu.tr/duyurular/" + UUID.randomUUID() + "/");
        a.setPublishedDate(LocalDate.now());
        a.setSummary("Genel duyuru");
        a.setBody("Metin");
        annId = anns.saveAndFlush(a).getId();
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(new ShallowEtagHeaderFilter()).apply(springSecurity()).build();
    }

    private User user(String faculty, String department) {
        User u = new User();
        u.setEmail("uc" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Ogr");
        u.setEmailVerified(true);
        u.setFaculty(faculty);
        u.setDepartment(department);
        u.setGrade("2");
        return users.saveAndFlush(u);
    }

    private static UsernamePasswordAuthenticationToken as(User u) {
        return new UsernamePasswordAuthenticationToken(u.getId(), null, List.of());
    }

    @Test
    void anonymousRequestsAreRejectedForBothEndpoints() throws Exception {
        assertEquals(401, mvc.perform(get("/api/news/unit")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/api/news/unit/" + annId)).andReturn().getResponse().getStatus());
    }

    @Test
    void feedAndDetailArePrivateNoStoreAndCarryNoEtag() throws Exception {
        User u = user("Mühendislik Fakültesi", "Bilgisayar Mühendisliği");

        MockHttpServletResponse feed = mvc.perform(get("/api/news/unit").with(authentication(as(u)))).andReturn().getResponse();
        assertEquals(200, feed.getStatus());
        assertEquals("private, no-store", feed.getHeader("Cache-Control"));
        assertNull(feed.getHeader("ETag"), "kisisel yanit ETag'lenmez");
        assertTrue(feed.getContentAsString().contains("Genel duyuru"));

        MockHttpServletResponse detail = mvc.perform(get("/api/news/unit/" + annId).with(authentication(as(u)))).andReturn().getResponse();
        assertEquals(200, detail.getStatus());
        assertEquals("private, no-store", detail.getHeader("Cache-Control"));
        assertNull(detail.getHeader("ETag"));
    }

    @Test
    void anAnnouncementOutsideTheUsersScopeIsNotFoundAndAUserWithoutMatchGetsAnEmptyList() throws Exception {
        User stranger = user("Fen-Edebiyat Fakültesi", "Tarih Bölümü");

        MockHttpServletResponse detail = mvc.perform(get("/api/news/unit/" + annId).with(authentication(as(stranger)))).andReturn().getResponse();
        assertEquals(404, detail.getStatus());
        assertTrue(detail.getContentAsString().contains("UNIT_NEWS_NOT_FOUND"));

        MockHttpServletResponse feed = mvc.perform(get("/api/news/unit").with(authentication(as(stranger)))).andReturn().getResponse();
        assertEquals(200, feed.getStatus());
        assertEquals("[]", feed.getContentAsString().strip());
        assertFalse(feed.getContentAsString().contains("Genel duyuru"));
    }
}
