package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.jsoup.Connection;
import org.jsoup.Jsoup;
import org.junit.jupiter.api.Test;

/** Guvenlik duzeltmeleri (A3/A4/A6): yonlendirme zinciri, port/kullanici bilgisi, boyut siniri, istek araligi. */
class UnitSiteScraperHardeningTest {

    private static final String MMF = "https://mmf.bingol.edu.tr";
    private static final String HTML = "<html><body><div class='media_w'></div></body></html>";

    private static Connection.Response ok(String url) {
        Connection.Response r = mock(Connection.Response.class);
        when(r.statusCode()).thenReturn(200);
        try {
            when(r.parse()).thenReturn(Jsoup.parse(HTML, url));
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
        return r;
    }

    private static Connection.Response redirect(int code, String location) {
        Connection.Response r = mock(Connection.Response.class);
        when(r.statusCode()).thenReturn(code);
        when(r.header("Location")).thenReturn(location);
        return r;
    }

    /** Cevaplari sirayla verir; istenen adresleri kaydeder. */
    private static UnitSiteScraper scraperWith(List<String> requested, List<Connection.Response> answers) {
        UnitSiteScraper s = new UnitSiteScraper();
        s.setPauseMs(0);
        AtomicInteger i = new AtomicInteger();
        s.setExecutor((url, timeout) -> {
            requested.add(url);
            assertTrue(timeout > 0 && timeout <= UnitSiteScraper.REQUEST_TIMEOUT_MS, "istek basina sure siniri");
            return answers.get(i.getAndIncrement());
        });
        return s;
    }

    // ------------------------------------------------------------------ A4: safeUrl

    @Test
    void safeUrlRejectsOddPortsAndUserInfoAndNormalisesCase() {
        String host = "mmf.bingol.edu.tr";
        assertNull(UnitSiteScraper.safeUrl("https://mmf.bingol.edu.tr:8443/x", host));
        assertNull(UnitSiteScraper.safeUrl("https://mmf.bingol.edu.tr:80/x", host));
        assertNull(UnitSiteScraper.safeUrl("https://user:p@mmf.bingol.edu.tr/x", host));
        assertNull(UnitSiteScraper.safeUrl("https://mmf.bingol.edu.tr@evil.example/x", host));
        assertNull(UnitSiteScraper.safeUrl("//evil.example/x", host));
        assertEquals("https://mmf.bingol.edu.tr/x?a=1#f", UnitSiteScraper.safeUrl("https://mmf.bingol.edu.tr:443/x?a=1#f", host));
        assertEquals("https://mmf.bingol.edu.tr/Media/A.pdf", UnitSiteScraper.safeUrl("HTTPS://MMF.Bingol.EDU.tr/Media/A.pdf", host));
        assertEquals("https://mmf.bingol.edu.tr/x", UnitSiteScraper.safeUrl("HTTP://mmf.bingol.edu.tr/x", host));
    }

    @Test
    void listEntriesOnAnotherSubdomainAreDropped() {
        String html = "<div class='media_w'><a href='https://btmyo.bingol.edu.tr/duyurular/x/'><h4 class='media_w-heading'>Baska site</h4>"
                + "<p>01.11.2026</p></a></div>"
                + "<div class='media_w'><a href='/duyurular/y/'><h4 class='media_w-heading'>Kendi sitesi</h4><p>01.11.2026</p></a></div>";
        List<UnitSiteScraper.ListEntry> list =
                UnitSiteScraper.parseList(Jsoup.parse(html, MMF + "/duyurular/"), "/duyurular/");
        assertEquals(1, list.size(), list.toString());
        assertEquals("Kendi sitesi", list.get(0).title());
    }

    // ------------------------------------------------------------------ A3: yonlendirme

    @Test
    void sameSiteRedirectsAreFollowedManually() throws Exception {
        List<String> asked = new ArrayList<>();
        UnitSiteScraper s = scraperWith(asked, List.of(redirect(301, "/duyurular/"), redirect(302, "http://mmf.bingol.edu.tr/duyurular/?x=1"),
                ok(MMF + "/duyurular/?x=1")));

        s.fetchList(MMF, "/duyurular");

        assertEquals(List.of(MMF + "/duyurular", MMF + "/duyurular/", MMF + "/duyurular/?x=1"), asked);
    }

    @Test
    void aRedirectOffTheSourceSiteIsRefusedBeforeAnyRequestIsMade() {
        for (String target : new String[] {"https://evil.example/x", "https://btmyo.bingol.edu.tr/x", "https://mmf.bingol.edu.tr:8443/x",
                "https://u:p@mmf.bingol.edu.tr/x", "http://127.0.0.1/admin", "ftp://mmf.bingol.edu.tr/x", "javascript:alert(1)"}) {
            List<String> asked = new ArrayList<>();
            UnitSiteScraper s = scraperWith(asked, List.of(redirect(302, target), ok("https://never.example/")));

            assertThrows(IOException.class, () -> s.fetchList(MMF, "/duyurular/"), target);
            assertEquals(List.of(MMF + "/duyurular/"), asked, "yonlendirme hedefine istek atilmadi: " + target);
        }
    }

    @Test
    void aRedirectWithoutLocationOrTooManyHopsIsRefused() {
        List<String> asked = new ArrayList<>();
        UnitSiteScraper noLoc = scraperWith(asked, List.of(redirect(302, null)));
        assertThrows(IOException.class, () -> noLoc.fetchList(MMF, "/duyurular/"));

        List<String> loop = new ArrayList<>();
        UnitSiteScraper s = scraperWith(loop, List.of(redirect(302, "/a/"), redirect(302, "/b/"), redirect(302, "/c/"),
                redirect(302, "/d/"), ok(MMF + "/e/")));
        IOException e = assertThrows(IOException.class, () -> s.fetchList(MMF, "/duyurular/"));
        assertTrue(e.getMessage().contains("yonlendirme"), e.getMessage());
        assertEquals(UnitSiteScraper.MAX_REDIRECTS + 1, loop.size(), "ilk istek + en cok 3 sicrama");
    }

    @Test
    void anHttpErrorStatusIsAnException() {
        Connection.Response notFound = mock(Connection.Response.class);
        when(notFound.statusCode()).thenReturn(404);
        UnitSiteScraper s = scraperWith(new ArrayList<>(), List.of(notFound));

        assertThrows(org.jsoup.HttpStatusException.class, () -> s.fetchList(MMF, "/duyurular/"));
    }

    @Test
    void theFirstRequestItselfMustBeOnTheSourceHost() {
        UnitSiteScraper s = scraperWith(new ArrayList<>(), List.of(ok("https://x/")));
        assertThrows(IOException.class, () -> s.fetchDetail("https://evil.example/duyurular/x/"));
        assertThrows(IOException.class, () -> s.fetchDetail("https://mmf.bingol.edu.tr:8443/duyurular/x/"));
        assertThrows(IOException.class, () -> s.fetchList("https://mmf.bingol.edu.tr:9000", "/duyurular/"));
    }

    @Test
    void theRealJsoupCallDoesNotFollowRedirectsAndCapsTheBody() throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        byte[] big = ("<html><body>" + "a".repeat(3_000_000) + "</body></html>").getBytes();
        server.createContext("/big", ex -> {
            ex.getResponseHeaders().add("Content-Type", "text/html; charset=utf-8");
            ex.sendResponseHeaders(200, big.length);
            try (OutputStream o = ex.getResponseBody()) {
                o.write(big);
            } catch (IOException ignored) {
                // istemci siniri asinca baglantiyi kapatabilir
            }
        });
        server.createContext("/moved", ex -> {
            ex.getResponseHeaders().add("Location", "/big");
            ex.sendResponseHeaders(302, -1);
            ex.close();
        });
        server.start();
        try {
            String base = "http://127.0.0.1:" + server.getAddress().getPort();
            Connection.Response moved = UnitSiteScraper.executeJsoup(base + "/moved", 5000);
            assertEquals(302, moved.statusCode(), "yonlendirme otomatik izlenmez");
            assertEquals("/big", moved.header("Location"));

            Connection.Response bigRes = UnitSiteScraper.executeJsoup(base + "/big", 5000);
            assertEquals(200, bigRes.statusCode());
            assertTrue(bigRes.bodyAsBytes().length <= UnitSiteScraper.MAX_BODY_BYTES,
                    "govde sinirlandi: " + bigRes.bodyAsBytes().length);
        } finally {
            server.stop(0);
        }
    }

    // ------------------------------------------------------------------ A6: istek araligi

    @Test
    void departmentFetchPausesBetweenTheHomePageAndTheDepartmentList() throws Exception {
        List<String> events = new ArrayList<>();
        UnitSiteScraper s = new UnitSiteScraper();
        s.setPauseMs(600);
        s.setSleeper(ms -> events.add("pause:" + ms));
        s.setExecutor((url, timeout) -> {
            events.add("req:" + url);
            return ok(url);
        });

        s.fetchDepartments(MMF);

        assertEquals(List.of("req:" + MMF + "/", "pause:600", "req:" + MMF + "/bolumler/"), events);
        // CLAUDE.md bolum 5: istekler arasi en az 500 ms (varsayilan 600)
        assertTrue(new UnitSiteScraper().pauseMsForTest() >= 500);
    }
}
