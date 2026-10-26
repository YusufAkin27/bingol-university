package edu.bingol.backend.menu;

import java.io.IOException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.springframework.stereotype.Component;

/** sks.bingol.edu.tr/yemek-listesi sayfasindaki aylik tabloyu okur: tarih + yemekler. */
@Component
public class MenuScraper {

    private static final String URL = "https://sks.bingol.edu.tr/yemek-listesi";
    private static final String UA = "Mozilla/5.0 (compatible; BingolMobileBot/1.0)";
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("d.M.yyyy");

    public record Day(LocalDate date, List<String> items) {}

    /** Bos liste = beklenen tablo bulunamadi (sayfa yapisi degismis olabilir). */
    public List<Day> fetch() throws IOException {
        return parse(Jsoup.connect(URL).userAgent(UA).timeout(20_000).get());
    }

    static List<Day> parse(Document doc) {
        List<Day> days = new ArrayList<>();
        for (Element row : doc.select(".sayfa-icerik table tr")) {
            List<Element> cells = row.select("> td");
            if (cells.size() < 2) {
                continue;
            }
            LocalDate date = parseDate(clean(cells.get(0).text()));
            if (date == null) {
                continue; // bos / ayirici satir
            }
            List<String> items = new ArrayList<>();
            for (int i = 1; i < cells.size(); i++) {
                String t = clean(cells.get(i).text());
                if (!t.isEmpty()) {
                    items.add(t);
                }
            }
            if (!items.isEmpty()) {
                days.add(new Day(date, items));
            }
        }
        return days;
    }

    private static String clean(String s) {
        return s.replace(' ', ' ').trim();
    }

    private static LocalDate parseDate(String s) {
        try {
            return LocalDate.parse(s, DATE);
        } catch (DateTimeParseException e) {
            return null;
        }
    }
}
