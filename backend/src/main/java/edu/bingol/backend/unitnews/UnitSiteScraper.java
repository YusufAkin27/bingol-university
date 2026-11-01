package edu.bingol.backend.unitnews;

import edu.bingol.backend.news.NewsDates;
import java.io.IOException;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * bingol.edu.tr alt sitelerinin (ortak "butema" sablonu) duyuru listesi, detay ve bolum yapisini okur.
 * Liste: {@code div.media_w > a[href]} (baslik {@code .media_w-heading}, tarih {@code p}); tek sayfada tum kayitlar.
 * Detay: baslik {@code div.sayfa h1}, tarih {@code ol.breadcrumb}, govde {@code div.sayfa-icerik}, ekler govdedeki
 * {@code /media/N/dosya.pdf} baglantilari. Yapi degisirse bos sonuc doner (cagiran bakim durumuna gecer).
 */
@Component
public class UnitSiteScraper {

    private static final Logger log = LoggerFactory.getLogger(UnitSiteScraper.class);
    private static final String UA = "Mozilla/5.0 (compatible; BingolMobileBot/1.0)";
    static final int MAX_URL_LEN = 500;
    static final int BODY_MAX = 8000;
    static final int SUMMARY_LEN = 200;
    private static final Pattern FILE_EXT = Pattern.compile(
            "(?i)\\.(pdf|docx?|xlsx?|pptx?|odt|ods|zip|rar)(?:[?#].*)?$");
    private static final Pattern DEPT_PATH = Pattern.compile("^/bolumler/([^/?#]+)/?$");
    private static final Pattern FEED_LINK = Pattern.compile("^/bolumler_/[^?#]+/duyurular/$");
    private static final Pattern LINE_UNIT = Pattern.compile("(?iu).*(b[öo]l[üu]m[üu]|program[ıi])\\s*$");

    /** Listedeki bir satir. */
    public record ListEntry(String url, String title, LocalDate date) {}

    /** Bolum: slug ({@code /bolumler/<slug>/}; baglantisiz metin bolumlerinde turetilmis) + gorunen ad. */
    public record Dept(String slug, String name) {}

    public record Attachment(String name, String url, String type) {}

    public record Detail(String body, List<Attachment> attachments, LocalDate date) {}

    // ---- ag ----

    public List<ListEntry> fetchList(String baseUrl, String feedPath) throws IOException {
        return parseList(connect(baseUrl + feedPath), feedPath);
    }

    public Detail fetchDetail(String url) throws IOException {
        return parseDetail(connect(url));
    }

    /** Ana sayfa menusu + /bolumler/ sayfasi (500 donebilir: yoksayilir). */
    public List<Dept> fetchDepartments(String baseUrl) throws IOException {
        Document home = connect(baseUrl + "/");
        Document list = null;
        try {
            list = connect(baseUrl + "/bolumler/");
        } catch (IOException e) {
            log.debug("/bolumler/ okunamadi {}: {}", baseUrl, e.toString());
        }
        return parseDepartments(home, list);
    }

    /** Bolum sayfasindaki kendi duyuru akisi baglantisi; yoksa null. */
    public String fetchFeedPath(String baseUrl, String slug) throws IOException {
        return parseFeedPath(connect(baseUrl + "/bolumler/" + slug + "/"));
    }

    private static Document connect(String url) throws IOException {
        return Jsoup.connect(url).userAgent(UA).timeout(20_000).get();
    }

    // ---- ayristirma (agsiz, test edilebilir) ----

    static List<ListEntry> parseList(Document doc, String feedPath) {
        List<ListEntry> out = new ArrayList<>();
        String host = doc.baseUri().isEmpty() ? "" : hostOf(doc.baseUri());
        for (Element a : doc.select("div.media_w a[href]")) {
            Element h = a.selectFirst(".media_w-heading");
            if (h == null) {
                continue;
            }
            String path = pathOf(a.attr("href"));
            if (path == null || !path.startsWith(feedPath) || path.length() <= feedPath.length()) {
                continue;
            }
            String url = safeUrl(a.absUrl("href").isEmpty() ? a.attr("href") : a.absUrl("href"), host);
            LocalDate date = NewsDates.parse(textOf(a.selectFirst("p")));
            String title = h.text().strip();
            if (url == null || title.isEmpty() || date == null) {
                continue;
            }
            out.add(new ListEntry(url, cut(title, 300), date));
        }
        return out;
    }

    static Detail parseDetail(Document doc) {
        Element content = doc.selectFirst("div.sayfa-icerik");
        if (content == null) {
            return new Detail("", List.of(), null);
        }
        String host = doc.baseUri().isEmpty() ? "" : hostOf(doc.baseUri());
        StringBuilder body = new StringBuilder();
        for (Element p : content.select("p, li, h2, h3, h4")) {
            String t = p.text().strip();
            if (!t.isEmpty()) {
                if (body.length() > 0) {
                    body.append("\n\n");
                }
                body.append(t);
            }
        }
        if (body.length() == 0) {
            body.append(content.text().strip());
        }
        Map<String, Attachment> files = new LinkedHashMap<>();
        for (Element a : content.select("a[href]")) {
            addFile(files, a.absUrl("href").isEmpty() ? a.attr("href") : a.absUrl("href"), a.text(), host);
        }
        for (Element e : content.select("iframe[src], embed[src]")) {
            addFile(files, e.absUrl("src"), "", host);
        }
        for (Element e : content.select("object[data]")) {
            addFile(files, e.absUrl("data"), "", host);
        }
        Element crumb = doc.selectFirst("ol.breadcrumb");
        return new Detail(cut(body.toString(), BODY_MAX), new ArrayList<>(files.values()),
                NewsDates.parse(textOf(crumb)));
    }

    static List<Dept> parseDepartments(Document home, Document list) {
        Map<String, Dept> out = new LinkedHashMap<>();
        String host = hostOf(home.baseUri());
        collectLinks(home, host, out);
        if (list != null) {
            collectLinks(list, host, out);
            Element content = list.selectFirst("div.sayfa-icerik");
            if (content != null) {
                for (String line : content.wholeText().split("\\R")) {
                    String name = line.strip();
                    if (name.length() < 5 || name.length() > 120 || !LINE_UNIT.matcher(name).matches()) {
                        continue;
                    }
                    String key = UnitKeys.deptKey(name);
                    boolean known = key != null && out.values().stream().anyMatch(d -> key.equals(UnitKeys.deptKey(d.name())));
                    if (key != null && !known) {
                        String slug = "x-" + key.replace(' ', '-');
                        out.putIfAbsent(slug, new Dept(cut(slug, 160), name));
                    }
                }
            }
        }
        return new ArrayList<>(out.values());
    }

    private static void collectLinks(Document doc, String host, Map<String, Dept> out) {
        for (Element a : doc.select("a[href]")) {
            String path = pathOf(a.attr("href"));
            Matcher m = path == null ? null : DEPT_PATH.matcher(path);
            if (m == null || !m.matches()) {
                continue;
            }
            String abs = a.absUrl("href");
            if (!abs.isEmpty() && !host.isEmpty() && !host.equalsIgnoreCase(hostOf(abs))) {
                continue;
            }
            String name = a.text().strip();
            String slug = m.group(1);
            if (name.isEmpty() || name.toLowerCase(Locale.ROOT).contains("planlanan")) {
                continue;
            }
            out.putIfAbsent(slug, new Dept(slug, cut(name, 200)));
        }
    }

    static String parseFeedPath(Document deptPage) {
        for (Element a : deptPage.select("a[href*=/bolumler_/]")) {
            String path = pathOf(a.attr("href"));
            if (path != null && FEED_LINK.matcher(path).matches()) {
                return path;
            }
        }
        return null;
    }

    // ---- yardimcilar ----

    private static void addFile(Map<String, Attachment> files, String href, String text, String host) {
        String url = safeUrl(href, host);
        if (url == null || !FILE_EXT.matcher(url).find()) {
            return;
        }
        String file = url.substring(url.lastIndexOf('/') + 1).replaceAll("[?#].*$", "");
        String name = text == null ? "" : text.strip();
        if (name.isEmpty() || name.length() > 120) {
            name = URLDecoder.decode(file, StandardCharsets.UTF_8);
        }
        Matcher ext = FILE_EXT.matcher(url);
        String type = ext.find() ? typeOf(ext.group(1).toLowerCase(Locale.ROOT)) : "OTHER";
        files.putIfAbsent(url, new Attachment(cut(name, 160), url, type));
    }

    static String typeOf(String ext) {
        return switch (ext) {
            case "pdf" -> "PDF";
            case "doc", "docx", "odt" -> "DOC";
            case "xls", "xlsx", "ods" -> "XLS";
            case "ppt", "pptx" -> "PPT";
            default -> "OTHER";
        };
    }

    /**
     * Yalniz https ve bingol.edu.tr alan adlari (alt alanlar dahil); http https'e cevrilir; cok uzun/bozuk adres null.
     * {@code host} bos degilse ve baglanti goreliyse o host'a baglanir.
     */
    static String safeUrl(String href, String host) {
        if (href == null || href.isBlank()) {
            return null;
        }
        String u = href.strip();
        try {
            if (u.startsWith("/") && !host.isEmpty()) {
                u = "https://" + host + u;
            }
            if (u.startsWith("http://")) {
                u = "https://" + u.substring(7);
            }
            URI uri = URI.create(u.replace(" ", "%20"));
            String h = uri.getHost();
            if (!"https".equalsIgnoreCase(uri.getScheme()) || h == null
                    || !(h.equalsIgnoreCase("bingol.edu.tr") || h.toLowerCase(Locale.ROOT).endsWith(".bingol.edu.tr"))) {
                return null;
            }
            String out = uri.toString();
            return out.length() > MAX_URL_LEN ? null : out;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static String pathOf(String href) {
        if (href == null || href.isBlank()) {
            return null;
        }
        try {
            URI uri = URI.create(href.strip().replace(" ", "%20"));
            String p = uri.getRawPath();
            return p == null || p.isEmpty() ? null : p;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static String hostOf(String url) {
        try {
            String h = URI.create(url).getHost();
            return h == null ? "" : h;
        } catch (IllegalArgumentException e) {
            return "";
        }
    }

    private static String textOf(Element e) {
        return e == null ? null : e.text();
    }

    static String cut(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }

    /** Ozet: bosluklar tek, en cok {@link #SUMMARY_LEN} karakter. */
    static String summaryOf(String body, String title) {
        String base = body == null || body.isBlank() ? title : body;
        String flat = base.replaceAll("\\s+", " ").strip();
        return flat.length() <= SUMMARY_LEN ? flat : flat.substring(0, SUMMARY_LEN - 1).stripTrailing() + "…";
    }
}
