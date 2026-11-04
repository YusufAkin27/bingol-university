package edu.bingol.backend.campus;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Kampus haritasi (H2, tam baglam): kullanici uclari (arama normallestirme, kategori suzgeci, 404, dil, kampus disi
 * kayit yok), yonetici uclari (RBAC, dogrulama sinirlari, yumusak silme + gerekce) ve onbellek gecersiz kilma.
 */
@SpringBootTest(properties = {"app.admin.require-reason=true",
        "spring.messages.basename=i18n/messages,i18n/campus,i18n/rbac"})
class CampusMapMvcTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired CampusPlaceRepository places;
    @Autowired CampusConfigRepository configs;
    @Autowired edu.bingol.backend.unitnews.UnitSourceRepository unitSources;
    @Autowired edu.bingol.backend.unitnews.UnitDepartmentRepository unitDepartments;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class))
                .apply(springSecurity()).build();
        places.deleteAll();
        configs.deleteAll();
    }

    // ---------------- yardimcilar ----------------

    private User admin(AdminProfile profile) {
        User u = new User();
        u.setEmail("campus." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("campus");
        u.setEmailVerified(true);
        u.setRole(Role.ADMIN);
        u.setStatus(UserStatus.ACTIVE);
        u.setAdminProfile(profile);
        return users.save(u);
    }

    private MockHttpServletResponse asAdmin(User u, MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(u.getId(), null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    private MockHttpServletResponse asUser(MockHttpServletRequestBuilder b) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(4242L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
        return mvc.perform(b.with(authentication(token))).andReturn().getResponse();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString(StandardCharsets.UTF_8));
    }

    private static String place(String name, String category, double lat, double lng, String extra) {
        return "{\"name\":\"" + name + "\",\"category\":\"" + category + "\",\"lat\":" + lat + ",\"lng\":" + lng + extra + "}";
    }

    private long create(User admin, String name, String category, String extra) throws Exception {
        MockHttpServletResponse r = asAdmin(admin, post("/api/admin/campus/places").contentType("application/json")
                .content(place(name, category, 38.8999, 40.4844, extra)));
        assertEquals(201, r.getStatus(), r.getContentAsString(StandardCharsets.UTF_8));
        return json(r).get("id").asLong();
    }

    private static final String VALID_CONFIG = """
            {"center":{"lat":38.9009,"lng":40.4853},"zoom":{"initial":16,"min":14,"max":19},
             "boundary":[[38.8958,40.4737],[38.8958,40.4968],[38.9060,40.4968],[38.9060,40.4737]],
             "tiles":{"urlTemplate":"https://tiles.example.com/{z}/{x}/{y}.png","attribution":"© Example","maxNativeZoom":18}}
            """;

    // ---------------- kullanici ----------------

    @Test
    void endpointsRequireLogin() throws Exception {
        assertEquals(401, mvc.perform(get("/api/campus/map")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/api/campus/places")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/api/campus/places/1")).andReturn().getResponse().getStatus());
    }

    @Test
    void mapReturnsConfigCategoriesAndCacheHeaders() throws Exception {
        MockHttpServletResponse r = asUser(get("/api/campus/map"));
        assertEquals(200, r.getStatus(), r.getContentAsString());
        // Cache-Control ilkesi PublicCacheInterceptorCampusTest'te; MockMvc'de Spring Security basligi once yazar
        JsonNode d = json(r);
        assertTrue(d.get("version").isNumber());
        assertEquals(16, d.get("zoom").get("initial").asInt());
        assertTrue(d.get("bounds").get("south").asDouble() < d.get("bounds").get("north").asDouble());
        assertTrue(d.get("boundary").isArray());
        assertEquals("https://tile.openstreetmap.org/{z}/{x}/{y}.png", d.get("tiles").get("urlTemplate").asText());
        assertEquals(19, d.get("tiles").get("maxNativeZoom").asInt());
        JsonNode cats = d.get("categories");
        assertEquals(13, cats.size());
        assertEquals("faculty", cats.get(0).get("key").asText());
        assertEquals("Fakülteler", cats.get(0).get("label").asText());
        assertEquals("school", cats.get(0).get("icon").asText());
        assertTrue(cats.get(0).get("color").asText().startsWith("#"));
        assertEquals("gate", cats.get(11).get("key").asText());
        assertEquals("Giriş kapıları ve otopark", cats.get(11).get("label").asText());
        assertEquals("Meslek Yüksekokulları", cats.get(3).get("label").asText());
        assertEquals("service", cats.get(9).get("key").asText());
    }

    @Test
    void categoryLabelsFollowRequestLanguage() throws Exception {
        JsonNode en = json(asUser(get("/api/campus/map").header("Accept-Language", "en")));
        assertEquals("Faculties", en.get("categories").get(0).get("label").asText());
        JsonNode ar = json(asUser(get("/api/campus/map").header("Accept-Language", "ar")));
        assertEquals("الكليات", ar.get("categories").get(0).get("label").asText());
        JsonNode tr = json(asUser(get("/api/campus/map")));
        assertEquals("Fakülteler", tr.get("categories").get(0).get("label").asText(), "dil basligi onbellegi karistirmaz");
    }

    @Test
    void searchIsTurkishInsensitivePrefixAndContainsAndCampusOnly() throws Exception {
        User full = admin(AdminProfile.FULL);
        create(full, "Mühendislik Fakültesi", "faculty", ",\"units\":[\"Bilgisayar Mühendisliği\"]");
        create(full, "Kütüphane", "library", "");
        create(full, "Merkezi Kafeterya", "dining", "");
        create(full, "Gizli Bina", "admin", ",\"active\":false");

        JsonNode mu = json(asUser(get("/api/campus/places?q=mü")));
        assertEquals(1, mu.get("items").size(), mu.toString());
        assertEquals("Mühendislik Fakültesi", mu.get("items").get(0).get("name").asText());
        assertEquals(1, json(asUser(get("/api/campus/places?q=MUH"))).get("items").size());
        assertEquals("Kütüphane", json(asUser(get("/api/campus/places?q=kutup"))).get("items").get(0).get("name").asText());
        assertEquals("Kütüphane", json(asUser(get("/api/campus/places?q=KÜTÜP"))).get("items").get(0).get("name").asText());
        // icerik (kelime ortasi) eslesmesi
        assertEquals("Merkezi Kafeterya", json(asUser(get("/api/campus/places?q=afet"))).get("items").get(0).get("name").asText());
        // birim adi da bulunur
        assertEquals("Mühendislik Fakültesi", json(asUser(get("/api/campus/places?q=bilgisayar"))).get("items").get(0).get("name").asText());
        // kampus disi / olmayan / pasif kayit yok
        assertEquals(0, json(asUser(get("/api/campus/places?q=Bingol%20Belediyesi"))).get("items").size());
        assertEquals(0, json(asUser(get("/api/campus/places?q=gizli"))).get("items").size(), "pasif yer gorunmez");
        // LIKE kacisi: % ve _ joker degil
        assertEquals(0, json(asUser(get("/api/campus/places?q=%25"))).get("items").size());
        assertEquals(0, json(asUser(get("/api/campus/places?q=_"))).get("items").size());
    }

    @Test
    void rankingPutsNamePrefixBeforeContains() throws Exception {
        User full = admin(AdminProfile.FULL);
        create(full, "Fen Mühendislik Ofisi", "admin", ",\"sortKey\":1");
        create(full, "Mühendislik Fakültesi", "faculty", ",\"sortKey\":2");
        JsonNode items = json(asUser(get("/api/campus/places?q=mü"))).get("items");
        assertEquals("Mühendislik Fakültesi", items.get(0).get("name").asText(), "ad oneki once");
        assertEquals("Fen Mühendislik Ofisi", items.get(1).get("name").asText());
    }

    @Test
    void categoryFilterLimitAndValidation() throws Exception {
        User full = admin(AdminProfile.FULL);
        for (int i = 0; i < 3; i++) {
            create(full, "Fakulte " + i, "faculty", ",\"sortKey\":" + i);
        }
        create(full, "Yemekhane", "dining", "");
        assertEquals(3, json(asUser(get("/api/campus/places?category=faculty"))).get("items").size());
        assertEquals(1, json(asUser(get("/api/campus/places?category=dining"))).get("items").size());
        assertEquals(4, json(asUser(get("/api/campus/places"))).get("items").size());
        assertEquals(2, json(asUser(get("/api/campus/places?limit=2"))).get("items").size());
        assertEquals(4, json(asUser(get("/api/campus/places?limit=9999"))).get("items").size(), "limit en cok 200");
        MockHttpServletResponse bad = asUser(get("/api/campus/places?category=bogus"));
        assertEquals(400, bad.getStatus());
        assertEquals("CAMPUS_CATEGORY_INVALID", json(bad).get("code").asText());
    }

    @Test
    void placeDetailAndNotFound() throws Exception {
        User full = admin(AdminProfile.FULL);
        long id = create(full, "Kütüphane", "library",
                ",\"summary\":\"Merkez\",\"units\":[\"Okuma Salonu\"],\"footprint\":[[38.8999,40.4844],[38.9,40.4845],[38.9001,40.4843]]");
        JsonNode p = json(asUser(get("/api/campus/places/" + id)));
        assertEquals("Kütüphane", p.get("name").asText());
        assertEquals("library", p.get("category").asText());
        assertEquals("Merkez", p.get("summary").asText());
        assertEquals("Okuma Salonu", p.get("units").get(0).asText());
        assertEquals(3, p.get("footprint").size());
        assertTrue(p.get("photoUrl").isNull());
        MockHttpServletResponse missing = asUser(get("/api/campus/places/99999999"));
        assertEquals(404, missing.getStatus());
        assertEquals("CAMPUS_PLACE_NOT_FOUND", json(missing).get("code").asText());
        // coklu dil hata metni
        JsonNode en = json(asUser(get("/api/campus/places/99999999").header("Accept-Language", "en")));
        assertEquals("Campus place not found.", en.get("message").asText());
    }

    @Test
    void remotePlaceAllowedOutsideBoundsAndFlaggedInApi() throws Exception {
        User full = admin(AdminProfile.FULL);
        MockHttpServletResponse r = asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("Genç Meslek Yüksekokulu", "vocational", 38.749475, 40.536118,
                        ",\"remote\":true,\"webUrl\":\"https://gencmyo.bingol.edu.tr\"")));
        assertEquals(201, r.getStatus(), r.getContentAsString(StandardCharsets.UTF_8));
        long id = json(r).get("id").asLong();
        JsonNode p = json(asUser(get("/api/campus/places/" + id)));
        assertTrue(p.get("remote").asBoolean());
        assertEquals("https://gencmyo.bingol.edu.tr", p.get("webUrl").asText());
        // uzak yer aramada da gelir
        assertEquals(1, json(asUser(get("/api/campus/places?q=genc"))).get("items").size());
        // uzak olmayan yer sinir disinda reddedilir
        MockHttpServletResponse bad = asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("Uzak", "vocational", 38.749475, 40.536118, "")));
        assertEquals("CAMPUS_OUT_OF_BOUNDS", json(bad).get("code").asText());
        // uzak olsa bile koordinat araligi denetlenir
        assertEquals("CAMPUS_COORD_INVALID", json(asAdmin(full, post("/api/admin/campus/places")
                .contentType("application/json").content(place("Uzak", "vocational", 95, 40.5, ",\"remote\":true")))).get("code").asText());
    }

    @Test
    void webUrlIsValidatedOnWrites() throws Exception {
        User full = admin(AdminProfile.FULL);
        for (String bad : List.of("http://mmf.bingol.edu.tr", "https://evil.example.com", "javascript:alert(1)")) {
            MockHttpServletResponse r = asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                    .content(place("Yer", "faculty", 38.8999, 40.4844, ",\"webUrl\":\"" + bad + "\"")));
            assertEquals(400, r.getStatus(), bad);
            assertEquals("CAMPUS_WEB_URL_INVALID", json(r).get("code").asText(), bad);
        }
        long id = create(full, "Yer", "faculty", ",\"webUrl\":\"https://www.bingol.edu.tr/tr/x\"");
        assertEquals("https://www.bingol.edu.tr/tr/x", json(asAdmin(full, get("/api/admin/campus/places/" + id))).get("webUrl").asText());
    }

    @Test
    void academicPlaceLinksToUnitSourceAndListsDepartmentsOnlyInDetail() throws Exception {
        var src = new edu.bingol.backend.unitnews.UnitSource();
        src.setCode("mmf");
        src.setName("Mühendislik Fakültesi");
        src.setKind(edu.bingol.backend.unitnews.UnitSource.Kind.FACULTY);
        src.setBaseUrl("https://mmf.bingol.edu.tr");
        unitSources.save(src);
        unitDepartments.deleteAll();
        for (String n : List.of("Bilgisayar Mühendisliği", "Elektrik-Elektronik Mühendisliği")) {
            var d = new edu.bingol.backend.unitnews.UnitDepartment();
            d.setSourceCode("mmf");
            d.setSlug(CampusText.normalize(n).replace(' ', '-'));
            d.setName(n);
            d.setNameKey(CampusText.normalize(n));
            unitDepartments.save(d);
        }
        User full = admin(AdminProfile.FULL);
        long fac = create(full, "Mühendislik Fakültesi", "faculty", ",\"webUrl\":\"https://mmf.bingol.edu.tr\"");
        // akademik olmayan kategori ayni konakta olsa da eslesmez
        long svc = create(full, "Bir Ofis", "service", ",\"webUrl\":\"https://mmf.bingol.edu.tr\"");
        long none = create(full, "Başka Fakülte", "faculty", ",\"webUrl\":\"https://yok.bingol.edu.tr\"");

        JsonNode detail = json(asUser(get("/api/campus/places/" + fac)));
        assertEquals("mmf", detail.get("unitSourceCode").asText());
        assertEquals(2, detail.get("departments").size());
        assertEquals("Bilgisayar Mühendisliği", detail.get("departments").get(0).asText());
        // liste ogesi: kod var, bolumler null
        for (JsonNode it : json(asUser(get("/api/campus/places"))).get("items")) {
            if (it.get("id").asLong() == fac) {
                assertEquals("mmf", it.get("unitSourceCode").asText());
                assertTrue(it.get("departments").isNull());
            }
        }
        assertTrue(json(asUser(get("/api/campus/places/" + svc))).get("unitSourceCode").isNull());
        JsonNode n = json(asUser(get("/api/campus/places/" + none)));
        assertTrue(n.get("unitSourceCode").isNull());
        assertTrue(n.get("departments").isNull());
        // yonetici detayi da ayni
        assertEquals(2, json(asAdmin(full, get("/api/admin/campus/places/" + fac))).get("departments").size());
    }

    // ---------------- yonetici ----------------

    @Test
    void permissionsFullAndEditorWriteOthersReadOnly() throws Exception {
        User full = admin(AdminProfile.FULL);
        User editor = admin(AdminProfile.EDITOR);
        User viewer = admin(AdminProfile.VIEWER);
        User moderator = admin(AdminProfile.MODERATOR);
        User support = admin(AdminProfile.SUPPORT);
        String body = place("Yer", "faculty", 38.8999, 40.4844, "");
        assertEquals(201, asAdmin(full, post("/api/admin/campus/places").contentType("application/json").content(body)).getStatus());
        assertEquals(201, asAdmin(editor, post("/api/admin/campus/places").contentType("application/json").content(body)).getStatus());
        for (User u : List.of(viewer, moderator, support)) {
            MockHttpServletResponse w = asAdmin(u, post("/api/admin/campus/places").contentType("application/json").content(body));
            assertEquals(403, w.getStatus(), u.getAdminProfile().name());
            assertEquals("ADMIN_PERMISSION_DENIED", json(w).get("code").asText());
            assertEquals(200, asAdmin(u, get("/api/admin/campus/places")).getStatus(), u.getAdminProfile().name());
            assertEquals(200, asAdmin(u, get("/api/admin/campus/config")).getStatus());
            assertEquals(403, asAdmin(u, put("/api/admin/campus/config").contentType("application/json")
                    .content(VALID_CONFIG)).getStatus());
        }
        // normal kullanici yonetici ucuna giremez
        assertEquals(403, asUser(get("/api/admin/campus/places")).getStatus());
    }

    @Test
    void placeValidationLimits() throws Exception {
        User full = admin(AdminProfile.FULL);
        String ok = place("Yer", "faculty", 38.8999, 40.4844, "");
        assertEquals(201, asAdmin(full, post("/api/admin/campus/places").contentType("application/json").content(ok)).getStatus());
        // kategori beyaz liste
        MockHttpServletResponse c = asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("Yer", "bogus", 38.8999, 40.4844, "")));
        assertEquals(400, c.getStatus());
        assertEquals("CAMPUS_CATEGORY_INVALID", json(c).get("code").asText());
        // koordinat araligi ve harita siniri
        assertEquals("CAMPUS_COORD_INVALID", json(asAdmin(full, post("/api/admin/campus/places")
                .contentType("application/json").content(place("Yer", "faculty", 95, 40.4844, "")))).get("code").asText());
        assertEquals("CAMPUS_OUT_OF_BOUNDS", json(asAdmin(full, post("/api/admin/campus/places")
                .contentType("application/json").content(place("Yer", "faculty", 41.0, 29.0, "")))).get("code").asText());
        // ad bos / 120+ / ozet 300+
        assertEquals(400, asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("", "faculty", 38.8999, 40.4844, ""))).getStatus());
        assertEquals(400, asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("A".repeat(121), "faculty", 38.8999, 40.4844, ""))).getStatus());
        assertEquals(400, asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("Yer", "faculty", 38.8999, 40.4844, ",\"summary\":\"" + "x".repeat(301) + "\""))).getStatus());
        // bina ana hatti: 2 nokta
        assertEquals(400, asAdmin(full, post("/api/admin/campus/places").contentType("application/json")
                .content(place("Yer", "faculty", 38.8999, 40.4844, ",\"footprint\":[[38.9,40.48],[38.91,40.49]]"))).getStatus());
    }

    @Test
    void updateChangesSearchKeyAndInvalidatesServerCache() throws Exception {
        User full = admin(AdminProfile.FULL);
        long id = create(full, "Eski Ad", "admin", "");
        // onbellegi isit (sorgusuz liste onbellekli)
        assertEquals("Eski Ad", json(asUser(get("/api/campus/places"))).get("items").get(0).get("name").asText());
        JsonNode v1 = json(asUser(get("/api/campus/map")));
        MockHttpServletResponse up = asAdmin(full, put("/api/admin/campus/places/" + id).contentType("application/json")
                .content(place("Yeni Şirin Ad", "social", 38.8999, 40.4844, "")));
        assertEquals(200, up.getStatus(), up.getContentAsString(StandardCharsets.UTF_8));
        // onbellek gecersiz kilindi: yeni ad ve arama anahtari
        assertEquals("Yeni Şirin Ad", json(asUser(get("/api/campus/places"))).get("items").get(0).get("name").asText());
        assertEquals(1, json(asUser(get("/api/campus/places?q=sirin"))).get("items").size());
        assertEquals(0, json(asUser(get("/api/campus/places?q=eski"))).get("items").size());
        JsonNode v2 = json(asUser(get("/api/campus/map")));
        assertTrue(v2.get("version").asLong() > v1.get("version").asLong(), "yazma surumu artirir");
    }

    @Test
    void deleteIsSoftNeedsReasonAndHidesEverywhere() throws Exception {
        User full = admin(AdminProfile.FULL);
        long id = create(full, "Silinecek", "admin", "");
        MockHttpServletResponse noReason = asAdmin(full, delete("/api/admin/campus/places/" + id));
        assertEquals(400, noReason.getStatus());
        assertEquals("REASON_REQUIRED", json(noReason).get("code").asText());
        assertEquals(200, asUser(get("/api/campus/places/" + id)).getStatus(), "gerekcesiz silme uygulanmadi");

        MockHttpServletResponse del = asAdmin(full, delete("/api/admin/campus/places/" + id)
                .header("X-Admin-Reason", "Yinelenen kayit"));
        assertEquals(200, del.getStatus(), del.getContentAsString(StandardCharsets.UTF_8));
        assertEquals(404, asUser(get("/api/campus/places/" + id)).getStatus());
        assertEquals(0, json(asUser(get("/api/campus/places"))).get("items").size());
        assertEquals(404, asAdmin(full, get("/api/admin/campus/places/" + id)).getStatus());
        assertEquals(0, json(asAdmin(full, get("/api/admin/campus/places"))).get("total").asInt());
        // satir fiziksel olarak durur (yumusak silme)
        CampusPlace row = places.findById(id).orElseThrow();
        assertFalse(row.isActive());
        assertNotNull(row.getDeletedAt());
        assertEquals(404, asAdmin(full, delete("/api/admin/campus/places/" + id).header("X-Admin-Reason", "tekrar")).getStatus());
    }

    @Test
    void adminListIncludesInactiveAndFilters() throws Exception {
        User full = admin(AdminProfile.FULL);
        create(full, "Gorunur", "faculty", "");
        create(full, "Gizli Yer", "faculty", ",\"active\":false");
        JsonNode l = json(asAdmin(full, get("/api/admin/campus/places?category=faculty")));
        assertEquals(2, l.get("total").asInt());
        assertEquals(1, json(asAdmin(full, get("/api/admin/campus/places?q=gizli"))).get("items").size());
        assertFalse(json(asAdmin(full, get("/api/admin/campus/places?q=gizli"))).get("items").get(0).get("active").asBoolean());
        assertEquals(400, asAdmin(full, get("/api/admin/campus/places?category=bogus")).getStatus());
    }

    @Test
    void configUpdateValidatesAndTakesEffect() throws Exception {
        User full = admin(AdminProfile.FULL);
        MockHttpServletResponse ok = asAdmin(full, put("/api/admin/campus/config").contentType("application/json").content(VALID_CONFIG));
        assertEquals(200, ok.getStatus(), ok.getContentAsString(StandardCharsets.UTF_8));
        JsonNode m = json(asUser(get("/api/campus/map")));
        assertEquals("https://tiles.example.com/{z}/{x}/{y}.png", m.get("tiles").get("urlTemplate").asText());
        assertEquals(18, m.get("tiles").get("maxNativeZoom").asInt());
        assertEquals(4, m.get("boundary").size());
        assertEquals(38.8958, m.get("boundary").get(0).get(0).asDouble(), 1e-9);
        // sinir kutusu poligondan turetilir ve onu kapsar
        assertTrue(m.get("bounds").get("south").asDouble() < 38.8958);
        assertTrue(m.get("bounds").get("east").asDouble() > 40.4968);
        assertEquals("BUKampus/{version}", m.get("tiles").get("userAgentHint").asText());
        // eski karo adresi onbellekte kalmaz
        assertNotEquals("https://tile.openstreetmap.org/{z}/{x}/{y}.png", m.get("tiles").get("urlTemplate").asText());
    }

    @Test
    void configValidationRejectsUnsafeOrMalformedInput() throws Exception {
        User full = admin(AdminProfile.FULL);
        String[][] cases = {
                {VALID_CONFIG.replace("https://tiles", "http://tiles"), "CAMPUS_TILE_URL_INVALID"},
                {VALID_CONFIG.replace("{y}", "y"), "CAMPUS_TILE_URL_INVALID"},
                {VALID_CONFIG.replace("© Example", "<b>x</b>"), "CAMPUS_TILE_URL_INVALID"},
                {VALID_CONFIG.replace("\"initial\":16", "\"initial\":25").replace("\"max\":19", "\"max\":25"), "CAMPUS_ZOOM_INVALID"},
                {VALID_CONFIG.replace("\"min\":14", "\"min\":17"), "CAMPUS_ZOOM_INVALID"},
                {VALID_CONFIG.replace("\"maxNativeZoom\":18", "\"maxNativeZoom\":40"), "CAMPUS_ZOOM_INVALID"},
                {VALID_CONFIG.replace("\"lat\":38.9009", "\"lat\":138.9"), "CAMPUS_COORD_INVALID"},
                {VALID_CONFIG.replace("\"lat\":38.9009", "\"lat\":10.0"), "CAMPUS_BOUNDS_INVALID"},
        };
        for (String[] c : cases) {
            MockHttpServletResponse r = asAdmin(full, put("/api/admin/campus/config").contentType("application/json").content(c[0]));
            assertEquals(400, r.getStatus(), c[1] + " " + r.getContentAsString(StandardCharsets.UTF_8));
            if (c[1] != null) {
                assertEquals(c[1], json(r).get("code").asText(), c[0]);
            }
        }
        // iki noktali poligon
        String two = VALID_CONFIG.replace("[38.8958,40.4968],[38.9060,40.4968],[38.9060,40.4737]", "[38.9060,40.4968]");
        assertEquals(400, asAdmin(full, put("/api/admin/campus/config").contentType("application/json").content(two)).getStatus());
        // acik sinir kutusu poligonu kapsamali
        String smallBounds = VALID_CONFIG.replace("\"boundary\"", "\"bounds\":{\"south\":38.90,\"west\":40.48,\"north\":38.91,\"east\":40.49},\"boundary\"");
        MockHttpServletResponse sb = asAdmin(full, put("/api/admin/campus/config").contentType("application/json").content(smallBounds));
        assertEquals("CAMPUS_BOUNDS_INVALID", json(sb).get("code").asText());
        // dunya boyutlu kutu
        String huge = VALID_CONFIG.replace("\"boundary\"", "\"bounds\":{\"south\":30,\"west\":30,\"north\":50,\"east\":50},\"boundary\"");
        assertEquals("CAMPUS_BOUNDS_INVALID", json(asAdmin(full, put("/api/admin/campus/config").contentType("application/json").content(huge))).get("code").asText());
        // hicbiri uygulanmadi
        assertEquals("https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                json(asUser(get("/api/campus/map"))).get("tiles").get("urlTemplate").asText());
    }

    private static void assertNotNull(Object o) {
        org.junit.jupiter.api.Assertions.assertNotNull(o);
    }
}
