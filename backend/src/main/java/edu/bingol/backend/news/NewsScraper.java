package edu.bingol.backend.news;

import java.io.IOException;
import java.net.URI;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
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

    private static Document connect(String url) throws IOException {
        return Jsoup.connect(url).userAgent(UA).timeout(20_000).get();
    }
}
