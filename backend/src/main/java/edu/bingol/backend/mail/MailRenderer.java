package edu.bingol.backend.mail;

import edu.bingol.backend.i18n.Lang;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.UnaryOperator;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.web.util.HtmlUtils;

/**
 * Sablonu dile gore HTML + duz metne cevirir. Yerlestirme: `{{ad}}` HTML kacislidir, `{{{ad}}}` ham eklenir
 * (yalnizca bu sinifin urettigi guvenli parcalar icin). Degiskenler kullanici kaynakli olabilir; her zaman kacislanir.
 * Metinler `i18n/mail*.properties` icindedir (ana messages paketinden ayri, kendi MessageSource'u ile).
 */
@Component
public class MailRenderer {

    public record Rendered(String subject, String html, String text) {
    }

    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{\\{(\\w+)}}}|\\{\\{(\\w+)}}");
    private static final String BRAND_KEY = "mail.tpl.brand";
    private static final String FOOTER_KEY = "mail.tpl.footer";
    private static final String CODE_STYLE = "display:inline-block;margin:8px 0 16px 0;padding:12px 20px;"
            + "background-color:#FAF6F3;color:#C62A20;font-family:'Courier New',monospace;font-size:28px;"
            + "font-weight:bold;letter-spacing:6px;border-radius:6px;";

    private final ResourceBundleMessageSource messages = new ResourceBundleMessageSource();
    private final String layout;

    public MailRenderer() {
        messages.setBasename("i18n/mail");
        messages.setDefaultEncoding("UTF-8");
        messages.setFallbackToSystemLocale(false);
        layout = readLayout();
    }

    public Rendered render(MailTemplate template, Lang lang, Map<String, String> vars) {
        String prefix = "mail.tpl." + template.key() + ".";
        String[] paragraphs = text(prefix + "body", lang).split("\n");
        String code = vars.get("code");

        String subject = singleLine(fill(text(prefix + "subject", lang), vars, UnaryOperator.identity()));
        String titleText = fill(text(prefix + "title", lang), vars, UnaryOperator.identity());
        String footerText = text(FOOTER_KEY, lang);
        String brand = text(BRAND_KEY, lang);

        StringBuilder bodyHtml = new StringBuilder();
        StringBuilder plain = new StringBuilder(titleText).append("\n\n");
        for (String p : paragraphs) {
            bodyHtml.append("<p class=\"txt\" style=\"margin:0 0 16px 0;white-space:pre-line;\">")
                    .append(fill(p, vars, MailRenderer::escape)).append("</p>\n");
            plain.append(fill(p, vars, UnaryOperator.identity())).append("\n\n");
        }
        String codeHtml = "";
        if (code != null && !code.isBlank()) {
            String label = text(prefix + "code.label", lang);
            codeHtml = "<p class=\"muted\" style=\"margin:0;font-size:13px;color:#6b6f80;\">" + escape(label) + "</p>"
                    + "<div class=\"code\" dir=\"ltr\" style=\"" + CODE_STYLE + "\">" + escape(code) + "</div>";
            plain.append(label).append(" ").append(code).append("\n\n");
        }
        plain.append("--\n").append(brand).append("\n").append(footerText).append("\n");

        Map<String, String> page = new LinkedHashMap<>();
        page.put("lang", lang.code());
        page.put("dir", lang == Lang.AR ? "rtl" : "ltr");
        page.put("title", titleText);
        page.put("brand", brand);
        page.put("footer", footerText);
        page.put("bodyHtml", bodyHtml.toString());
        page.put("codeHtml", codeHtml);
        return new Rendered(subject, fill(layout, page, MailRenderer::escape), plain.toString());
    }

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
        return HtmlUtils.htmlEscape(s, "UTF-8");
    }

    /** Konu satirinda CR/LF olamaz (baslik enjeksiyonu). */
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
