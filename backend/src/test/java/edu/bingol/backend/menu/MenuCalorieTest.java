package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Yemek kalorisi: anahtar normalizasyonu, yonetici uclari, kismi toplu uygulama, senkronun kaloriyi EZMEMESI. */
@SpringBootTest
class MenuCalorieTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final LocalDate D1 = LocalDate.of(2031, 3, 3);
    private static final LocalDate D2 = LocalDate.of(2031, 3, 4);

    @Autowired WebApplicationContext ctx;
    @Autowired MenuRepository menu;
    @Autowired MenuItemCalorieRepository cal;
    @Autowired MenuService menuService;
    @Autowired MenuSyncService sync;

    @MockitoBean RateLimiter limiter;
    @MockitoBean MenuScraper scraper;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
        cal.deleteAll();
        menu.deleteAll();
        save(D1, "PATLICAN MUSAKKA\nBULGUR PİLAVI\nCACIK");
        save(D2, "ORMAN KEBABI");
    }

    private void save(LocalDate d, String items) {
        MenuDay m = new MenuDay();
        m.setMenuDate(d);
        m.setItems(items);
        menu.saveAndFlush(m);
    }

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(990001L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990002L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MockHttpServletResponse putJson(String path, String body) throws Exception {
        MockHttpServletRequestBuilder b = put(path).contentType("application/json").content(body);
        return mvc.perform(b.with(authentication(admin()))).andReturn().getResponse();
    }

    private static JsonNode json(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString());
    }

    private MenuResponse dayOf(LocalDate d) {
        return menuService.month(java.time.YearMonth.from(d)).stream()
                .filter(x -> x.date().equals(d.toString())).findFirst().orElseThrow();
    }

    @Test
    void keyIgnoresCaseSpacesNbspAndTurkishLetters() {
        assertEquals("bulgur pilavi", MenuItemKey.of("  Bulgur   Pilavı "));
        assertEquals(MenuItemKey.of("Bulgur Pilavı"), MenuItemKey.of("BULGUR PİLAVI"));
        assertEquals(MenuItemKey.of("BULGUR PILAVI"), MenuItemKey.of("bulgur pilavı"));
        assertEquals(MenuItemKey.of("MERCIMEK CORBASI"), MenuItemKey.of("mercimek çorbası"));
        assertEquals("", MenuItemKey.of(null));
    }

    @Test
    void responseWithoutCaloriesHasNullKcalAndNoTotal() {
        MenuResponse r = dayOf(D1);
        assertEquals(3, r.items().size());
        assertEquals(3, r.dishes().size());
        assertNull(r.dishes().get(0).kcal());
        assertNull(r.totalKcal());
        assertFalse(r.kcalComplete());
    }

    @Test
    void singleDaySetsAndClearsCaloriesAndTotals() throws Exception {
        MockHttpServletResponse res = putJson("/api/admin/menu/2031-03-03/calories",
                "{\"items\":[{\"name\":\"patlıcan musakka\",\"kcal\":320},{\"name\":\"CACIK\",\"kcal\":80}]}");
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode body = json(res);
        assertEquals(320, body.get("dishes").get(0).get("kcal").asInt());
        assertTrue(body.get("dishes").get(1).get("kcal").isNull());
        assertEquals(400, body.get("totalKcal").asInt());
        assertFalse(body.get("kcalComplete").asBoolean());
        assertEquals("PATLICAN MUSAKKA", body.get("items").get(0).asText());

        // tamamlayinca kcalComplete true
        putJson("/api/admin/menu/2031-03-03/calories", "{\"items\":[{\"name\":\"BULGUR PİLAVI\",\"kcal\":0}]}");
        assertTrue(dayOf(D1).kcalComplete());
        assertEquals(400, dayOf(D1).totalKcal());

        // null = sil
        JsonNode cleared = json(putJson("/api/admin/menu/2031-03-03/calories",
                "{\"items\":[{\"name\":\"CACIK\",\"kcal\":null}]}"));
        assertTrue(cleared.get("dishes").get(2).get("kcal").isNull());
        assertEquals(2, cal.findByMenuDate(D1).size());
    }

    @Test
    void invalidValuesAndUnknownTargetsAreRejected() throws Exception {
        assertEquals("MENU_KCAL_INVALID", json(putJson("/api/admin/menu/2031-03-03/calories",
                "{\"items\":[{\"name\":\"CACIK\",\"kcal\":5001}]}")).get("code").asText());
        assertEquals(400, putJson("/api/admin/menu/2031-03-03/calories",
                "{\"items\":[{\"name\":\"CACIK\",\"kcal\":-1}]}").getStatus());
        MockHttpServletResponse unknownItem = putJson("/api/admin/menu/2031-03-03/calories",
                "{\"items\":[{\"name\":\"YOK BOYLE YEMEK\",\"kcal\":10}]}");
        assertEquals(400, unknownItem.getStatus());
        assertEquals("MENU_ITEM_NOT_FOUND", json(unknownItem).get("code").asText());
        MockHttpServletResponse noDay = putJson("/api/admin/menu/2031-03-09/calories",
                "{\"items\":[{\"name\":\"CACIK\",\"kcal\":10}]}");
        assertEquals(404, noDay.getStatus());
        assertEquals("MENU_DATE_INVALID", json(putJson("/api/admin/menu/bozuk/calories",
                "{\"items\":[{\"name\":\"CACIK\",\"kcal\":10}]}")).get("code").asText());
        assertEquals("MENU_KCAL_LIMIT", json(putJson("/api/admin/menu/2031-03-03/calories", "{\"items\":[]}"))
                .get("code").asText());
        assertEquals(0, cal.count());
    }

    @Test
    void bulkAppliesPartiallyAndReportsSkipped() throws Exception {
        JsonNode r = json(putJson("/api/admin/menu/calories", """
                {"days":[
                  {"date":"2031-03-03","items":[{"name":"CACIK","kcal":80},{"name":"YANLIS","kcal":5}]},
                  {"date":"2031-03-04","items":[{"name":"ORMAN KEBABI","kcal":550}]},
                  {"date":"2031-03-20","items":[{"name":"X","kcal":1}]}
                ]}"""));
        assertEquals(2, r.get("updated").asInt());
        assertEquals(2, r.get("skipped").size());
        assertEquals("ITEM_NOT_FOUND", r.get("skipped").get(0).get("reason").asText());
        assertEquals("DAY_NOT_FOUND", r.get("skipped").get(1).get("reason").asText());
        assertEquals(550, dayOf(D2).totalKcal());

        // tekrar ayni degerler -> degismeyen
        JsonNode again = json(putJson("/api/admin/menu/calories",
                "{\"days\":[{\"date\":\"2031-03-04\",\"items\":[{\"name\":\"ORMAN KEBABI\",\"kcal\":550}]}]}"));
        assertEquals(0, again.get("updated").asInt());
        assertEquals(1, again.get("unchanged").asInt());

        // gecersiz kalori tum istegi reddeder, hicbir sey yazilmaz
        assertEquals(400, putJson("/api/admin/menu/calories", """
                {"days":[{"date":"2031-03-03","items":[{"name":"PATLICAN MUSAKKA","kcal":300}]},
                         {"date":"2031-03-04","items":[{"name":"ORMAN KEBABI","kcal":9999}]}]}""").getStatus());
        assertNull(dayOf(D1).dishes().get(0).kcal());
    }

    @Test
    void syncNeverTouchesCaloriesEvenWhenSourceRewritesTheDay() throws Exception {
        putJson("/api/admin/menu/2031-03-03/calories",
                "{\"items\":[{\"name\":\"PATLICAN MUSAKKA\",\"kcal\":320},{\"name\":\"CACIK\",\"kcal\":80}]}");

        // kaynak site gunu degistirdi (yemek eklendi) ve baska bir gunu sildi/yeniden yazdi
        when(scraper.fetch()).thenReturn(List.of(
                new MenuScraper.Day(D1, List.of("PATLICAN MUSAKKA", "BULGUR PİLAVI", "CACIK", "AYRAN")),
                new MenuScraper.Day(D2, List.of("ORMAN KEBABI", "SUTLAC"))));
        assertEquals(2, sync.sync());

        MenuResponse r = dayOf(D1);
        assertEquals(4, r.items().size());
        assertEquals(320, r.dishes().get(0).kcal());
        assertEquals(80, r.dishes().get(2).kcal());
        assertNull(r.dishes().get(3).kcal());
        assertEquals(400, r.totalKcal());

        // gun satiri silinip kaynak yeniden yazsa bile kalori geri gelir
        menu.deleteAll();
        assertEquals(2, sync.sync());
        assertEquals(320, dayOf(D1).dishes().get(0).kcal());
    }

    @Test
    void publicEndpointExposesKcalAndItemsStayStrings() throws Exception {
        putJson("/api/admin/menu/2031-03-03/calories", "{\"items\":[{\"name\":\"CACIK\",\"kcal\":80}]}");
        MockHttpServletResponse res = mvc.perform(get("/api/menu?month=2031-03")).andReturn().getResponse();
        assertEquals(200, res.getStatus(), res.getContentAsString());
        JsonNode day = json(res).get(0);
        assertTrue(day.get("items").get(0).isTextual());
        assertEquals(80, day.get("dishes").get(2).get("kcal").asInt());
        assertEquals(80, day.get("totalKcal").asInt());
    }

    @Test
    void plainUserCannotWriteCalories() throws Exception {
        MockHttpServletResponse res = mvc.perform(put("/api/admin/menu/2031-03-03/calories")
                .contentType("application/json").content("{\"items\":[{\"name\":\"CACIK\",\"kcal\":80}]}")
                .with(authentication(plainUser()))).andReturn().getResponse();
        assertEquals(403, res.getStatus());
        assertEquals(0, cal.count());
    }
}
