package edu.bingol.backend.mail;

import edu.bingol.backend.i18n.Lang;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.UnaryOperator;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.web.util.HtmlUtils;

/**
 * Tum e-postalarin ortak, siyah-beyaz yerlesimi ({@code mail-templates/layout.html}) ve bilesenleri: paragraf, not
 * (guvenlik notu), kod kutusu, birincil dugme, baglanti satiri. Sablonlu ({@link MailRenderer}), yonetici sablonlu
 * (CustomMailRenderer), destek yanitlari ve sistem uyarisi ayni cerceveyi kullanir; boylece marka tek yerden degisir.
 * <p>Tasarim: siyah-beyaz (renkli vurgu yok), gradient/golge yok, kalin yazi yok (font-weight 400; hiyerarsi boyut +
 * renk + bosluk), 1 px kenarlik, 12 px kose, tek birincil dugme (siyah zemin/beyaz yazi; koyu temada tersi). Tum
 * degerler satir ici (Gmail/Outlook), koyu tema {@code prefers-color-scheme} ile yalniz destekleyen istemcilerde.
 */
public final class MailLayout {

    /** Alt bilgi turu: otomatik (yanitlamayin) ya da destek talebi iletisi. */
    public enum Footer {
        AUTOMATED("mail.tpl.footer"), SUPPORT("mail.tpl.footer.support");

        private final String key;

        Footer(String key) {
            this.key = key;
        }
    }

    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{\\{(\\w+)}}}|\\{\\{(\\w+)}}");
    private static final Pattern URL = Pattern.compile("https?://[^\\s<>\"']+");
    private static final Pattern WHOLE_URL = Pattern.compile("^https?://[^\\s<>\"']+$");
    private static final Pattern OLD_BRAND_RED = Pattern.compile("(?i)#(?:C62A20|F73A2E|ED211B)\\b");
    private static final String FONT = MailBrand.FONT;
    private static final String MONO = "'SFMono-Regular',Menlo,Consolas,'Liberation Mono','Courier New',monospace";

    private static final ResourceBundleMessageSource MESSAGES = new ResourceBundleMessageSource();
    private static final String LAYOUT;

    static {
        MESSAGES.setBasename("i18n/mail");
        MESSAGES.setDefaultEncoding("UTF-8");
        MESSAGES.setFallbackToSystemLocale(false);
        try (var in = new ClassPathResource("mail-templates/layout.html").getInputStream()) {
            LAYOUT = new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException("mail-templates/layout.html okunamadi", e);
        }
    }

    private MailLayout() {
    }

    // ---------- metinler ----------

    public static String text(String key, Lang lang) {
        return MESSAGES.getMessage(key, null, key, lang.locale());
    }

    public static String brand(Lang lang) {
        return text("mail.tpl.brand", lang);
    }

    /** Duz metin e-postanin kuyrugu: "--", kurum satiri, alt bilgi. */
    public static String plainTail(Lang lang, Footer footer) {
        return "--\n" + text("mail.tpl.org", lang) + "\n" + text(footer.key, lang) + "\n";
    }

    // ---------- sayfa ----------

    /**
     * Cerceveyi doldurur. `contentHtml` HAM eklenir (cagiran bilesenlerle uretir/kacislar); `title` kacislanir.
     * Alt bilgideki {@code <!--bu-footer-extra-->} isareti abonelikten cik satiri icin yerinde birakilir.
     */
    public static String page(Lang lang, String title, String contentHtml, Footer footer) {
        boolean rtl = lang == Lang.AR;
        Map<String, String> v = Map.of(
                "lang", lang.code(),
                "dir", rtl ? "rtl" : "ltr",
                "align", rtl ? "right" : "left",
                "title", title == null ? "" : title,
                "headerHtml", MailBrand.headerHtml(brand(lang), rtl),
                "contentHtml", contentHtml == null ? "" : contentHtml,
                "org", text("mail.tpl.org", lang),
                "footer", text(footer.key, lang));
        return fill(LAYOUT, v, MailLayout::escape);
    }

    // ---------- bilesenler (cagiran girdiyi KACISLI verir: *Html parametreleri) ----------

    /** Govde paragrafi; `escapedHtml` zaten kacisli. */
    public static String paragraph(String escapedHtml) {
        return "<p class=\"body-txt\" style=\"margin:0 0 16px 0;font-size:16px;line-height:1.6;font-weight:400;color:#27272A;"
                + "white-space:pre-line;word-break:break-word;overflow-wrap:anywhere;\">" + escapedHtml + "</p>\n";
    }

    /** Guvenlik/ek not: ince cerceveli, yuvarlak kose, ikincil renk. */
    public static String note(String escapedHtml) {
        return "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" class=\"note\" "
                + "style=\"margin:8px 0 16px 0;border:1px solid #E4E4E7;border-radius:12px;border-collapse:separate;\">"
                + "<tr><td class=\"muted\" style=\"padding:14px 16px;font-family:" + FONT + ";font-size:14px;line-height:1.55;"
                + "font-weight:400;color:#52525B;white-space:pre-line;word-break:break-word;overflow-wrap:anywhere;\">" + escapedHtml + "</td></tr></table>\n";
    }

    /** 6 haneli kod kutusu: LTR, tabular/monospace, genis harf araligi. `label` bos olabilir. */
    public static String code(String label, String code) {
        String lab = label == null || label.isBlank() ? ""
                : "<p class=\"muted\" style=\"margin:0 0 8px 0;font-size:14px;line-height:1.4;color:#52525B;\">"
                + escape(label) + "</p>";
        return lab + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" "
                + "class=\"codebox\" bgcolor=\"#FAFAFA\" style=\"margin:0 0 20px 0;background-color:#FAFAFA;border:1px solid #D4D4D8;"
                + "border-radius:12px;border-collapse:separate;\"><tr><td class=\"code-text txt\" dir=\"ltr\" align=\"center\" "
                + "style=\"padding:18px 12px 18px 22px;font-family:" + MONO + ";font-size:34px;line-height:1.2;font-weight:400;"
                + "letter-spacing:10px;text-align:center;color:#09090B;\">" + escape(code) + "</td></tr></table>\n";
    }

    /** Birincil dugme (kenarlikli tablo hucresi, VML gerektirmez) + altinda ham baglanti (uzunsa kirilir). */
    public static String button(String url, String label) {
        String href = escape(url);
        return "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"margin:8px 0 12px 0;\"><tr>"
                + "<td class=\"btn\" align=\"center\" bgcolor=\"#09090B\" style=\"background-color:#09090B;border:1px solid #09090B;"
                + "border-radius:12px;padding:14px 28px;\"><a class=\"btn-a\" href=\"" + href + "\" style=\"font-family:" + FONT
                + ";font-size:16px;line-height:1.2;font-weight:400;color:#FFFFFF;text-decoration:none;display:inline-block;\">"
                + escape(label) + "</a></td></tr></table>\n" + linkLine(url);
    }

    /** Ikincil baglanti satiri (kucuk, ikincil renk, kirilabilir). */
    public static String linkLine(String url) {
        String href = escape(url);
        return "<p class=\"muted\" style=\"margin:0 0 20px 0;font-size:13px;line-height:1.5;color:#52525B;word-break:break-all;"
                + "overflow-wrap:anywhere;\"><a class=\"link\" href=\"" + href + "\" style=\"color:#52525B;text-decoration:underline;\">"
                + href + "</a></p>\n";
    }

    /** Ince ayirici cizgi. */
    public static String divider() {
        return "<div class=\"hair\" style=\"border-top:1px solid #E4E4E7;font-size:0;line-height:0;height:0;margin:8px 0 16px 0;\">"
                + "&nbsp;</div>\n";
    }

    // ---------- duz metinden HTML ----------

    /**
     * Duz metni (destek yanitlari, uyari) bilesenlere cevirir: bos satirla ayrilan bloklar paragraf, tek basina bir
     * baglanti satiri `actionLabel` varsa birincil dugme (yoksa baglanti satiri), {@code ---} satiri ayirici. Metin
     * icindeki http(s) baglantilari tiklanabilir olur; her sey KACISLANIR (ham HTML enjeksiyonu yok).
     * `code` verilirse ve bir blok kodla bitiyorsa kod o bloktan ayrilip kutuda gosterilir.
     */
    public static String fromPlain(String plain, String actionLabel, String code) {
        StringBuilder out = new StringBuilder();
        List<String> para = new ArrayList<>();
        boolean codeDone = code == null || code.isBlank();
        for (String raw : (plain == null ? "" : plain).replace("\r\n", "\n").split("\n", -1)) {
            String line = raw.strip();
            boolean blank = line.isEmpty();
            boolean url = WHOLE_URL.matcher(line).matches();
            boolean rule = line.equals("---");
            if (blank || url || rule) {
                codeDone = flush(out, para, code, codeDone);
                if (url) {
                    out.append(actionLabel == null || actionLabel.isBlank() ? linkLine(line) : button(line, actionLabel));
                } else if (rule) {
                    out.append(divider());
                }
            } else {
                para.add(raw);
            }
        }
        flush(out, para, code, codeDone);
        return out.toString();
    }

    private static boolean flush(StringBuilder out, List<String> para, String code, boolean codeDone) {
        if (para.isEmpty()) {
            return codeDone;
        }
        String block = String.join("\n", para).strip();
        para.clear();
        boolean emitCode = false;
        if (!codeDone && block.endsWith(code)) {
            block = block.substring(0, block.length() - code.length()).strip();
            emitCode = true;
        }
        if (!block.isEmpty()) {
            out.append(paragraph(linkify(block)));
        }
        if (emitCode) {
            out.append(code(null, code));
        }
        return codeDone || emitCode;
    }

    /** Metni kacislar, http(s) baglantilarini {@code <a>} yapar (sondaki noktalama baglantiya girmez). */
    static String linkify(String text) {
        Matcher m = URL.matcher(text);
        StringBuilder out = new StringBuilder();
        int last = 0;
        while (m.find()) {
            String u = m.group();
            String trail = "";
            while (!u.isEmpty() && ".,;:!?)]".indexOf(u.charAt(u.length() - 1)) >= 0) {
                trail = u.charAt(u.length() - 1) + trail;
                u = u.substring(0, u.length() - 1);
            }
            out.append(escape(text.substring(last, m.start())));
            out.append("<a class=\"link\" href=\"").append(escape(u)).append("\" style=\"color:#09090B;text-decoration:underline;"
                    + "word-break:break-all;overflow-wrap:anywhere;\">").append(escape(u)).append("</a>").append(escape(trail));
            last = m.end();
        }
        out.append(escape(text.substring(last)));
        return out.toString();
    }

    /** Eski kirmizi marka renkleri (yonetici sablonlarinda kalmis olabilir) siyaha cevrilir: marka artik siyah-beyaz. */
    public static String neutralizeBrandRed(String html) {
        return html == null ? null : OLD_BRAND_RED.matcher(html).replaceAll("#09090B");
    }

    // ---------- yer tutucu ----------

    /** `{{x}}` degerini escaper ile, `{{{x}}}` degerini oldugu gibi yerlestirir; bilinmeyen alan bos kalir. */
    static String fill(String template, Map<String, String> vars, UnaryOperator<String> escaper) {
        Matcher m = PLACEHOLDER.matcher(template);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            boolean raw = m.group(1) != null;
            String value = vars.getOrDefault(raw ? m.group(1) : m.group(2), "");
            m.appendReplacement(out, Matcher.quoteReplacement(raw ? value : escaper.apply(value)));
        }
        m.appendTail(out);
        return out.toString();
    }

    static String escape(String s) {
        return HtmlUtils.htmlEscape(s == null ? "" : s, "UTF-8");
    }
}
