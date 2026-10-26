package edu.bingol.backend.news;

import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Kaynak sitedeki tarih bicimlerini (20.10.2026, 20/10/2026, 2026-10-20, "20 Ekim 2026") ayristirir. */
final class NewsDates {

    private static final Pattern NUMERIC = Pattern.compile("(?<!\\d)(\\d{1,2})[./-](\\d{1,2})[./-](\\d{4})(?!\\d)");
    private static final Pattern ISO = Pattern.compile("(?<!\\d)(\\d{4})-(\\d{2})-(\\d{2})(?!\\d)");
    private static final Pattern NAMED = Pattern.compile("(?<!\\d)(\\d{1,2})\\s+(\\p{L}+)\\s+(\\d{4})");

    private static final Map<String, Integer> MONTHS = Map.ofEntries(
            Map.entry("ocak", 1), Map.entry("subat", 2), Map.entry("mart", 3), Map.entry("nisan", 4),
            Map.entry("mayis", 5), Map.entry("haziran", 6), Map.entry("temmuz", 7), Map.entry("agustos", 8),
            Map.entry("eylul", 9), Map.entry("ekim", 10), Map.entry("kasim", 11), Map.entry("aralik", 12));

    private NewsDates() {}

    /** Metindeki ilk gecerli tarihi doner; bulunamazsa null. */
    static LocalDate parse(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        String s = text.replace(' ', ' ').trim();
        LocalDate d = fromNumeric(s);
        if (d == null) {
            d = fromIso(s);
        }
        return d != null ? d : fromNamed(s);
    }

    private static LocalDate fromNumeric(String s) {
        Matcher m = NUMERIC.matcher(s);
        while (m.find()) {
            LocalDate d = of(m.group(3), m.group(2), m.group(1));
            if (d != null) {
                return d;
            }
        }
        return null;
    }

    private static LocalDate fromIso(String s) {
        Matcher m = ISO.matcher(s);
        while (m.find()) {
            LocalDate d = of(m.group(1), m.group(2), m.group(3));
            if (d != null) {
                return d;
            }
        }
        return null;
    }

    private static LocalDate fromNamed(String s) {
        Matcher m = NAMED.matcher(s);
        while (m.find()) {
            Integer month = MONTHS.get(fold(m.group(2)));
            if (month != null) {
                LocalDate d = of(m.group(3), String.valueOf(month), m.group(1));
                if (d != null) {
                    return d;
                }
            }
        }
        return null;
    }

    /** Turkce harfleri ASCII'ye indirger ("Şubat" -> "subat"). */
    private static String fold(String s) {
        return s.toLowerCase(Locale.ROOT).replace("̇", "")
                .replace('ı', 'i').replace('ş', 's').replace('ğ', 'g')
                .replace('ü', 'u').replace('ö', 'o').replace('ç', 'c');
    }

    private static LocalDate of(String year, String month, String day) {
        try {
            return LocalDate.of(Integer.parseInt(year), Integer.parseInt(month), Integer.parseInt(day));
        } catch (DateTimeException | NumberFormatException e) {
            return null;
        }
    }
}
