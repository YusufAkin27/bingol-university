package edu.bingol.backend.news;

import java.io.IOException;
import java.net.URI;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.jsoup.Connection;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * bingol.edu.tr haber/duyuru/etkinlik listesini ve detay sayfalarini okur.
 * Liste verisi sitede bir iframe icinde (HaberDuyuruEtkinlik.aspx) gelir; ilk sayfa 20 kayit icerir.
 */
@Component
public class NewsScraper {

    private static final Logger log = LoggerFactory.getLogger(NewsScraper.class);
    private static final String BASE = "https://www.bingol.edu.tr";
    private static final String LIST_URL = BASE + "/buproject/HaberDuyuruEtkinlik.aspx?tip=%d&dil=tr";
    private static final String UA = "Mozilla/5.0 (compatible; BingolMobileBot/1.0)";
    private static final String LIST_BASE = BASE + "/buproject/";
    /** news_item.url kolon siniri; kirpilmis baglanti bozuk olacagindan daha uzunlar atlanir. */
    private static final int MAX_URL_LEN = 1000;
    private static final int SUMMARY_LEN = 220;
    private static final Pattern EVENT_DATE_LABEL = Pattern.compile(
            "(?iu)(?:etkinlik\\s+tarihi|ba[sş]lang[ıi][cç]\\s+tarihi|tarih)\\s*[:\\-]\\s*([^\\n]{0,40})");

    /** Listedeki bir satir. */
    public record ListEntry(String url, String title, LocalDate date) {}

    /** Detay sayfasindan cikan veri. */
    public record Detail(String content, String imageUrl, LocalDate eventDate) {}

    public List<ListEntry> fetchList(ContentType type) throws IOException {
        return parseList(connect(LIST_URL.formatted(type.siteCode())));
    }

    static List<ListEntry> parseList(Document doc) {
        if (doc.baseUri().isEmpty()) {
            doc.setBaseUri(LIST_BASE);
        }
        List<ListEntry> out = new ArrayList<>();
        for (Element row : doc.select("tr[id^=grid_DXDataRow]")) {
            Element a = row.selectFirst("a[href]");
            Element dateCell = row.selectFirst("td.dx-ac");
            if (a == null) {
                continue;
            }
            String href = absoluteHref(a);
            if (href.isEmpty() || href.length() > MAX_URL_LEN) {
                log.warn("Gecersiz/cok uzun baglanti atlandi (uzunluk {})", href.length());
                continue;
            }
            out.add(new ListEntry(href, a.text().trim(), NewsDates.parse(dateCell == null ? null : dateCell.text())));
        }
        return out;
    }

    private static String absoluteHref(Element a) {
        String href = a.absUrl("href");
        if (href.isEmpty()) {
            href = a.attr("href").trim();
        }
        return href.replaceFirst("^http://", "https://");
    }

    /** "Etkinlik Tarihi: 12 Kasim 2026" gibi etiketli alandan baslangic tarihini cikarir; yoksa null. */
    static LocalDate extractEventDate(String text) {
        if (text == null) {
            return null;
        }
        Matcher m = EVENT_DATE_LABEL.matcher(text);
        return m.find() ? NewsDates.parse(m.group(1)) : null;
    }

    /** Yalnizca www.bingol.edu.tr sayfalari icin icerik cikarir; harici sitelerde ve hatada null doner. */
    public Detail fetchDetail(String url) {
        if (!isMainSite(url)) {
            return null;
        }
        try {
            Document doc = connect(url);
            Element body = doc.selectFirst("div.sade");
            if (body == null) {
                return null;
            }
            Element img = body.selectFirst("img[src]");
            String image = img == null ? null : img.absUrl("src");
            // Paragraf ve satir sonlarini koruyarak duz metne cevir.
            body.select("br").after("\\n");
            body.select("p").after("\\n");
            String text = body.text().replace("\\n", "\n")
                    .replaceAll("[ \\t]+", " ")
                    .replaceAll(" ?\n ?", "\n")
                    .replaceAll("\n{3,}", "\n\n")
                    .trim();
            return new Detail(text, image, extractEventDate(text));
        } catch (IOException e) {
            log.warn("Detay alinamadi {}: {}", url, e.getMessage());
            return null;
        }
    }

    public static String summarize(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        String flat = text.replaceAll("\\s+", " ").trim();
        return flat.length() <= SUMMARY_LEN ? flat : flat.substring(0, SUMMARY_LEN).trim() + "…";
    }

    private static boolean isMainSite(String url) {
        try {
            return "www.bingol.edu.tr".equalsIgnoreCase(URI.create(url).getHost());
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    /** Yonlendirme sayisi ve istek basina toplam sure ust siniri. */
    static final int MAX_REDIRECTS = 3;
    private static final long TOTAL_BUDGET_MS = 40_000;
    private static final int MAX_BODY_BYTES = 2 * 1024 * 1024;
    private static final String HOST = "www.bingol.edu.tr";

    /**
     * Yonlendirmeleri ELLE izler (P07-B13): Jsoup varsayilani herhangi bir host'a 20 yonlendirme izler ve oradan gelen
     * metin herkese sunulan `content` olabilirdi. Yalniz ayni host'ta (https, varsayilan port) en cok
     * {@value #MAX_REDIRECTS} yonlendirme; toplam sure ve govde boyutu sinirli.
     */
    private static Document connect(String url) throws IOException {
        long deadline = System.nanoTime() + TOTAL_BUDGET_MS * 1_000_000L;
        String current = url;
        for (int hop = 0; hop <= MAX_REDIRECTS; hop++) {
            long left = (deadline - System.nanoTime()) / 1_000_000L;
            if (left <= 0) {
                throw new IOException("toplam sure butcesi asildi: " + url);
            }
            Connection.Response res = Jsoup.connect(current).userAgent(UA).timeout((int) Math.min(20_000, left))
                    .maxBodySize(MAX_BODY_BYTES).followRedirects(false).execute();
            int code = res.statusCode();
            if (code >= 300 && code < 400 && res.hasHeader("Location")) {
                current = nextHop(current, res.header("Location"));
                continue;
            }
            return res.parse();
        }
        throw new IOException("cok fazla yonlendirme: " + url);
    }

    /** Yonlendirme hedefi: ayni ana site, https (http -> https cevrilir), varsayilan port; aksi halde IOException. */
    static String nextHop(String current, String location) throws IOException {
        try {
            URI target = URI.create(current).resolve(location.trim());
            String scheme = target.getScheme() == null ? "" : target.getScheme().toLowerCase(java.util.Locale.ROOT);
            boolean okPort = target.getPort() == -1 || target.getPort() == 443 || target.getPort() == 80;
            if (!("https".equals(scheme) || "http".equals(scheme)) || !HOST.equalsIgnoreCase(target.getHost()) || !okPort
                    || target.getUserInfo() != null) {
                throw new IOException("yonlendirme ana site disina: " + target.getHost());
            }
            String path = target.getRawPath() == null || target.getRawPath().isEmpty() ? "/" : target.getRawPath();
            return "https://" + HOST + path + (target.getRawQuery() == null ? "" : "?" + target.getRawQuery());
        } catch (IllegalArgumentException e) {
            throw new IOException("gecersiz yonlendirme: " + e.getMessage());
        }
    }
}
