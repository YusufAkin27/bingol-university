package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.common.ApiException;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.safety.Safelist;
import org.springframework.http.HttpStatus;

/**
 * Yonetici sablonlarinin dogrulanmasi ve guvenli hale getirilmesi. Yer tutucular yalnizca izinli kume
 * ({@link #VARIABLES}) olabilir; HTML jsoup Safelist ile temizlenir (script/iframe/form/on* yok, baglanti ve
 * gorseller yalnizca https), inline stilde expression()/javascript:/harici url() temizlenir.
 */
public final class MailTemplateSanitizer {

    /** Izinli degiskenler ({{ad}} biciminde). abonelikCikUrl her e-postaya otomatik eklenen baglantidir. */
    public static final List<String> VARIABLES =
            List.of("ad", "eposta", "bolum", "fakulte", "sinif", "uygulamaUrl", "abonelikCikUrl");

    public static final int MAX_HTML = 100_000;
    public static final int MAX_SUBJECT = 200;

    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{([^{}]*)}}");
    private static final String TOKEN_HOST = "https://mv.invalid/";
    private static final Pattern BAD_STYLE =
            Pattern.compile("(?i)expression\\s*\\(|javascript\\s*:|vbscript\\s*:|@import|behavior\\s*:|-moz-binding|\\\\");
    private static final Pattern STYLE_URL = Pattern.compile("(?i)url\\s*\\(\\s*(['\"]?)([^)]*)");
    private static final String BLOCK_TAGS = "script,style,iframe,frame,frameset,object,embed,applet,form,input,button,"
            + "textarea,select,option,link,meta,base,svg,math,noscript,template,title,head";

    private static final Safelist SAFELIST = buildSafelist();

    private MailTemplateSanitizer() {}

    private static Safelist buildSafelist() {
        Safelist s = new Safelist();
        s.addTags("a", "b", "strong", "i", "em", "u", "s", "strike", "small", "big", "sub", "sup", "br", "hr", "p",
                "div", "span", "center", "blockquote", "pre", "code", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol",
                "li", "dl", "dt", "dd", "img", "table", "thead", "tbody", "tfoot", "tr", "th", "td", "caption",
                "colgroup", "col", "font");
        s.addAttributes(":all", "style", "align", "dir", "lang", "title");
        s.addAttributes("a", "href", "name");
        s.addAttributes("img", "src", "alt", "width", "height");
        s.addAttributes("table", "width", "border", "cellpadding", "cellspacing", "bgcolor");
        s.addAttributes("td", "width", "height", "colspan", "rowspan", "valign", "bgcolor");
        s.addAttributes("th", "width", "height", "colspan", "rowspan", "valign", "bgcolor");
        s.addAttributes("tr", "valign", "bgcolor");
        s.addAttributes("col", "span", "width");
        s.addAttributes("colgroup", "span");
        s.addAttributes("font", "color", "size", "face");
        s.addAttributes("ol", "start", "type");
        s.addProtocols("a", "href", "https");
        s.addProtocols("img", "src", "https");
        s.addEnforcedAttribute("a", "rel", "noopener noreferrer nofollow");
        return s;
    }

    /** Konu: tek satir, yer tutucu dogrulamali. Doner: normallestirilmis metin. */
    public static String cleanSubject(String subject) {
        String s = subject == null ? "" : subject.replaceAll("[\\r\\n]+", " ").trim();
        if (s.isEmpty() || s.length() > MAX_SUBJECT) {
            throw invalid("subject");
        }
        return validatePlaceholders(s);
    }

    /** HTML govde: dogrula + temizle. Yer tutucular korunur ({{ad}} bicimi). */
    public static String cleanHtml(String html) {
        if (html == null || html.isBlank() || html.length() > MAX_HTML) {
            throw invalid("html");
        }
        if (html.contains("mv.invalid")) {
            throw invalid("html");
        }
        String normalized = validatePlaceholders(html);
        // Yer tutucular https baglanti olarak tokenlastirilir: href="{{uygulamaUrl}}" Safelist'ten sag cikar
        String tokenized = normalized;
        for (String v : VARIABLES) {
            tokenized = tokenized.replace("{{" + v + "}}", TOKEN_HOST + v + "/");
        }
        Document frag = Jsoup.parseBodyFragment(tokenized);
        frag.select(BLOCK_TAGS).remove();
        String cleaned = Jsoup.clean(frag.body().html(), "", SAFELIST,
                new Document.OutputSettings().prettyPrint(false));
        Document out = Jsoup.parseBodyFragment(cleaned);
        out.outputSettings().prettyPrint(false);
        for (Element e : out.select("[style]")) {
            String st = e.attr("style");
            if (!safeStyle(st)) {
                e.removeAttr("style");
            }
        }
        String result = out.body().html();
        for (String v : VARIABLES) {
            result = result.replace(TOKEN_HOST + v + "/", "{{" + v + "}}");
        }
        if (result.contains("mv.invalid") || Jsoup.parse(result).text().isBlank() && !result.contains("<img")) {
            throw invalid("html");
        }
        return result;
    }

    /** Duz metin: yoksa HTML'den uretilir. */
    public static String cleanText(String text, String cleanedHtml) {
        if (text != null && !text.isBlank()) {
            if (text.length() > MAX_HTML) {
                throw invalid("text");
            }
            return validatePlaceholders(text);
        }
        return htmlToText(cleanedHtml);
    }

    public static String htmlToText(String html) {
        Document d = Jsoup.parseBodyFragment(html);
        d.outputSettings().prettyPrint(false);
        d.select("br").after("[[NL]]");
        d.select("p,div,h1,h2,h3,h4,h5,h6,li,tr,blockquote,pre,table").append("[[NL]]");
        d.select("li").prepend("- ");
        for (Element a : d.select("a[href]")) {
            String href = a.attr("href");
            if (!href.isBlank() && !a.text().trim().equals(href)) {
                a.append(" (" + href + ")");
            }
        }
        String t = d.body().wholeText().replace("[[NL]]", "\n");
        t = t.replaceAll("[ \\t\\u00A0]+", " ").replaceAll(" ?\\n ?", "\n").replaceAll("\\n{3,}", "\n\n").trim();
        return t;
    }

    /** Metindeki yer tutuculari dogrular; `{{ ad }}` -> `{{ad}}`. Uclu suslu ve dengesiz suslu reddedilir. */
    static String validatePlaceholders(String s) {
        if (s.contains("{{{") || s.contains("}}}")) {
            throw invalid("placeholder");
        }
        Matcher m = PLACEHOLDER.matcher(s);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            String name = m.group(1).trim();
            if (!VARIABLES.contains(name)) {
                String shown = name.length() > 40 ? name.substring(0, 40) : name;
                throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_TEMPLATE_VARIABLE_UNKNOWN",
                        "Bilinmeyen değişken: " + shown, shown.replaceAll("[^\\w\\-.]", "?"));
            }
            m.appendReplacement(out, Matcher.quoteReplacement("{{" + name + "}}"));
        }
        m.appendTail(out);
        String res = out.toString();
        String rest = PLACEHOLDER.matcher(res).replaceAll("");
        if (rest.contains("{{") || rest.contains("}}")) {
            throw invalid("placeholder");
        }
        return res;
    }

    /** Kullanilan degiskenler (yonetici ekrani icin). */
    public static Set<String> usedVariables(String s) {
        Set<String> used = new LinkedHashSet<>();
        if (s != null) {
            Matcher m = PLACEHOLDER.matcher(s);
            while (m.find()) {
                used.add(m.group(1).trim());
            }
        }
        return used;
    }

    private static boolean safeStyle(String style) {
        if (BAD_STYLE.matcher(style).find()) {
            return false;
        }
        Matcher m = STYLE_URL.matcher(style);
        while (m.find()) {
            if (!m.group(2).trim().toLowerCase().startsWith("https://")) {
                return false;
            }
        }
        return true;
    }

    private static ApiException invalid(String what) {
        return new ApiException(HttpStatus.BAD_REQUEST, "MAIL_TEMPLATE_INVALID", "Şablon geçersiz.", what);
    }
}
