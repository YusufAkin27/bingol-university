package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.AbstractMockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Akademisyen alani MockMvc entegrasyon testlerinin ortak tabani (H2 + tam baglam, Redis sahte). Kullanici/jeton
 * olusturma deseni RbacMvcTest/MultiSessionFlowTest ile aynidir: kimlik dogrudan SecurityContext'e verilir.
 */
@SpringBootTest
abstract class AcademicianMvcBase {

    static final ObjectMapper OM = new ObjectMapper();
    static final String FACULTY = "Mühendislik Fakültesi";
    static final String DEPT = "Bilgisayar Mühendisliği";

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired NotificationRepository notifRepo;
    @Autowired AcCourseRepository courseRepo;
    @Autowired AcSessionRepository sessionRepo;
    @Autowired AcEnrollmentRepository enrollRepo;
    @Autowired AcAttendanceRepository attendRepo;
    @Autowired AcademicianRepository academicianRepo;
    @Autowired LessonCodeService lessonCodes;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void baseSetUp() {
        reset(limiter);
        doNothing().when(limiter).check(anyString(), anyInt(), any(Duration.class));
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    // ---- kullanicilar ----

    static String rnd() {
        return UUID.randomUUID().toString().substring(0, 8);
    }

    /** Ogrenci: rakamli (ogrenci numarali) kurumsal adres, dogrulanmis, sinifi var. */
    User student(String name) {
        User u = new User();
        u.setEmail((100_000_000L + ThreadLocalRandom.current().nextLong(899_999_999L)) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(Role.USER);
        u.setStatus(UserStatus.ACTIVE);
        u.setFaculty(FACULTY);
        u.setDepartment(DEPT);
        u.setClassYear((short) 2);
        return users.save(u);
    }

    User plainUser(String email, String name) {
        User u = new User();
        u.setEmail(email);
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(Role.USER);
        u.setStatus(UserStatus.ACTIVE);
        return users.save(u);
    }

    User admin() {
        User u = plainUser("yonetici." + rnd() + "@bingol.edu.tr", "Yonetici");
        u.setRole(Role.ADMIN);
        u.setAdminProfile(AdminProfile.FULL);
        return users.save(u);
    }

    /** Ad-soyad kalibli kurumsal adresle basvurur: otomatik ONAYLI akademisyen. */
    User lecturer(String name) {
        User u = plainUser("hoca." + rnd() + "@bingol.edu.tr", name);
        JsonNode r = call(u, post("/api/academician/apply").contentType("application/json")
                .content("{\"title\":\"Dr.\",\"firstName\":\"Ali\",\"lastName\":\"Veli\"}"), 200);
        assertEquals("APPROVED", r.get("status").asText());
        return u;
    }

    // ---- HTTP ----

    MockHttpServletResponse raw(User u, AbstractMockHttpServletRequestBuilder<?> b) throws Exception {
        String role = u.getRole() == Role.ADMIN ? "ROLE_ADMIN" : "ROLE_USER";
        var token = new UsernamePasswordAuthenticationToken(u.getId(), null, List.of(new SimpleGrantedAuthority(role)));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    /** Istegi yapar, durumu dogrular, govdeyi JSON olarak doner (bos govde: null). */
    JsonNode call(User u, AbstractMockHttpServletRequestBuilder<?> b, int expected) {
        try {
            MockHttpServletResponse r = raw(u, b);
            String body = r.getContentAsString(StandardCharsets.UTF_8);
            assertEquals(expected, r.getStatus(), body);
            return body.isBlank() || !(body.startsWith("{") || body.startsWith("[")) ? null : OM.readTree(body);
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    /** Hata kodunu dogrular. */
    void expectError(User u, AbstractMockHttpServletRequestBuilder<?> b, int status, String code) {
        JsonNode j = call(u, b, status);
        assertEquals(code, j.get("code").asText(), String.valueOf(j));
    }

    static ObjectNode obj() {
        return OM.createObjectNode();
    }

    static MockHttpServletRequestBuilder postJson(String url, Object body) {
        return post(url).contentType("application/json").content(body == null ? "{}" : body.toString());
    }

    static MockHttpServletRequestBuilder putJson(String url, Object body) {
        return put(url).contentType("application/json").content(body.toString());
    }

    // ---- ders / oturum yardimcilari ----

    long course(User l) {
        ObjectNode b = obj().put("name", "Veri Yapıları").put("term", "2026 Güz").put("faculty", FACULTY)
                .put("department", DEPT).put("code", "BM201");
        return call(l, postJson("/api/academician/courses", b), 201).get("id").asLong();
    }

    void enrol(User l, long courseId, User... students) {
        var ids = OM.createArrayNode();
        for (User s : students) {
            ids.add(s.getId());
        }
        call(l, postJson("/api/academician/courses/" + courseId + "/enrollments", obj().set("studentIds", ids)), 200);
    }

    long openSession(User l, long courseId) {
        return call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj()), 201).get("id").asLong();
    }

    JsonNode live(User l, long sessionId) {
        return call(l, get("/api/academician/sessions/" + sessionId + "/live"), 200);
    }

    String code(User l, long sessionId) {
        return live(l, sessionId).get("codes").get(0).get("code").asText();
    }

    MockHttpServletRequestBuilder scanReq(String code) {
        return postJson("/api/attendance/scan", obj().put("code", code));
    }

    JsonNode scan(User s, String code) {
        return call(s, scanReq(code), 200);
    }

    List<Notification> notificationsOf(User u) {
        return notifRepo.findTop500ByUserIdOrderByIdDesc(u.getId());
    }

    /** Ogrenciye giden ders bildirimlerinin hedefi: targetType=ACADEMIC_COURSE, targetId=<dersId> (mobil yonlendirme sozlesmesi). */
    void assertCourseTarget(User u, String title, long courseId) {
        List<Notification> hits = notificationsOf(u).stream().filter(n -> title.equals(n.getTitle())).toList();
        assertEquals(true, !hits.isEmpty(), "bildirim yok: " + title);
        for (Notification n : hits) {
            try {
                JsonNode d = OM.readTree(n.getData());
                assertEquals("ACADEMIC_COURSE", d.get("targetType").asText(), title);
                assertEquals(String.valueOf(courseId), d.get("targetId").asText(), title);
                assertEquals("ACADEMIC_COURSE", d.get("target").asText(), title);
                assertEquals(String.valueOf(courseId), d.get("value").asText(), title);
            } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
                throw new AssertionError(e);
            }
        }
    }

    long countTitle(User u, String title) {
        return notificationsOf(u).stream().filter(n -> title.equals(n.getTitle())).count();
    }
}
