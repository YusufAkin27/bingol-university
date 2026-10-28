package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.CustomMailContent;
import edu.bingol.backend.mail.MailRenderer;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.function.UnaryOperator;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.web.util.HtmlUtils;

/**
 * Yonetici sablonunu (veritabani, sabit surum) alicinin dilinde mevcut {@code layout.html} sarmalayicisi icinde
 * HTML + duz metne cevirir. Yer tutucu degerleri HTML icin KACISLANIR, duz metin icin oldugu gibi yerlestirilir.
 * Alicinin dilinde icerik yoksa Turkce kullanilir.
 */
@Component
public class CustomMailRenderer implements CustomMailContent {

    /** Tek dil icin icerik: konu, temizlenmis HTML, duz metin. */
    public record Content(String subject, String html, String text) {
        public boolean complete() {
            return subject != null && !subject.isBlank() && html != null && !html.isBlank();
        }
    }

    /** Dil cozumu sonucu: kullanilan dil ve tr'ye dusuldu mu. */
    public record Resolved(Content content, Lang used, boolean fallback) {}

    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{(\\w+)}}");
    private static final int CACHE_MAX = 200;

    private final MailCustomTemplateVersionRepository versions;
    private final ResourceBundleMessageSource messages = new ResourceBundleMessageSource();
    private final String layout;
    private final Map<String, MailCustomTemplateVersion> cache = new ConcurrentHashMap<>();

    public CustomMailRenderer(MailCustomTemplateVersionRepository versions) {
        this.versions = versions;
        messages.setBasename("i18n/mail");
        messages.setDefaultEncoding("UTF-8");
        messages.setFallbackToSystemLocale(false);
        layout = readLayout();
    }

    @Override
    public MailRenderer.Rendered render(Lang lang, Map<String, String> vars) {
        long tplId = Long.parseLong(vars.getOrDefault("tplId", "0"));
        int ver = Integer.parseInt(vars.getOrDefault("tplVer", "0"));
        MailCustomTemplateVersion v = load(tplId, ver);
        Resolved r = resolve(v, lang);
        String prefix = vars.getOrDefault("subjectPrefix", "");
        return renderContent(r.content(), r.used(), vars, prefix);
    }

    /** Surumden dil icerigi: istenen dilde tam icerik yoksa tr. */
    public static Resolved resolve(MailCustomTemplateVersion v, Lang lang) {
        Content want = contentOf(v, lang);
        if (want != null && want.complete()) {
            return new Resolved(want, lang, false);
        }
        Content tr = contentOf(v, Lang.TR);
        return new Resolved(tr == null ? new Content("", "", "") : tr, Lang.TR, lang != Lang.TR);
    }

    public static Content contentOf(MailCustomTemplateVersion v, Lang lang) {
        return switch (lang) {
            case TR -> new Content(v.getSubjectTr(), v.getHtmlTr(), v.getTextTr());
            case EN -> new Content(v.getSubjectEn(), v.getHtmlEn(), v.getTextEn());
            case AR -> new Content(v.getSubjectAr(), v.getHtmlAr(), v.getTextAr());
        };
    }

    /** Onizleme/test icin de kullanilir. `vars` yalnizca izinli degiskenleri tasir (digerleri yok sayilir). */
    public MailRenderer.Rendered renderContent(Content c, Lang lang, Map<String, String> vars, String subjectPrefix) {
        Map<String, String> values = new LinkedHashMap<>();
        for (String name : MailTemplateSanitizer.VARIABLES) {
            values.put(name, vars.getOrDefault(name, ""));
        }
        UnaryOperator<String> raw = UnaryOperator.identity();
        String subject = singleLine((subjectPrefix == null ? "" : subjectPrefix) + fill(c.subject(), values, raw));

        // Abonelikten cik baglantisi kuyruk iscisi tarafindan her duyuru e-postasina otomatik eklenir (UnsubscribeFooter)
        StringBuilder body = new StringBuilder(fill(c.html(), values, CustomMailRenderer::escape));
        StringBuilder plain = new StringBuilder(fill(c.text() == null ? "" : c.text(), values, raw));
        String brand = text("mail.tpl.brand", lang);
        String footer = text("mail.tpl.footer", lang);
        plain.append("\n\n--\n").append(brand).append('\n').append(footer).append('\n');

        Map<String, String> page = new LinkedHashMap<>();
        page.put("lang", lang.code());
        page.put("dir", lang == Lang.AR ? "rtl" : "ltr");
        page.put("title", subject);
        page.put("brand", brand);
        page.put("footer", footer);
        page.put("bodyHtml", body.toString());
        page.put("codeHtml", "");
        return new MailRenderer.Rendered(subject, fillLayout(page), plain.toString());
    }

    private MailCustomTemplateVersion load(long tplId, int ver) {
        String key = tplId + ":" + ver;
        MailCustomTemplateVersion hit = cache.get(key);
        if (hit != null) {
            return hit;
        }
        MailCustomTemplateVersion v = versions.findByTemplateIdAndVersion(tplId, ver)
                .orElseThrow(() -> new IllegalStateException("Sablon surumu yok: " + key));
        if (cache.size() >= CACHE_MAX) {
            cache.clear();
        }
        cache.put(key, v); // surumler degismez: onbellek gecersizlesmez
        return v;
    }

    private String fillLayout(Map<String, String> page) {
        Matcher m = Pattern.compile("\\{\\{\\{(\\w+)}}}|\\{\\{(\\w+)}}").matcher(layout);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            boolean rawPart = m.group(1) != null;
            String value = page.getOrDefault(rawPart ? m.group(1) : m.group(2), "");
            m.appendReplacement(out, Matcher.quoteReplacement(rawPart ? value : escape(value)));
        }
        m.appendTail(out);
        return out.toString();
    }

    static String fill(String template, Map<String, String> values, UnaryOperator<String> escaper) {
        if (template == null) {
            return "";
        }
        Matcher m = PLACEHOLDER.matcher(template);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            String value = values.getOrDefault(m.group(1), "");
            m.appendReplacement(out, Matcher.quoteReplacement(escaper.apply(value)));
        }
        m.appendTail(out);
        return out.toString();
    }

    static String escape(String s) {
        return HtmlUtils.htmlEscape(s, "UTF-8");
    }

    static String singleLine(String s) {
        return s.replaceAll("[\\r\\n]+", " ").trim();
    }

    private String text(String key, Lang lang) {
        return messages.getMessage(key, null, key, lang.locale());
    }

    private static String readLayout() {
        try (var in = new ClassPathResource("mail-templates/layout.html").getInputStream()) {
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException("mail-templates/layout.html okunamadi", e);
        }
    }
}
