package edu.bingol.backend.mail;

import edu.bingol.backend.i18n.Lang;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.UnaryOperator;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.stereotype.Component;
import org.springframework.web.util.HtmlUtils;

/**
 * Sablonu dile gore HTML + duz metne cevirir. Yerlestirme: `{{ad}}` HTML kacislidir, `{{{ad}}}` ham eklenir
 * (yalnizca bu sinifin urettigi guvenli parcalar icin). Degiskenler kullanici kaynakli olabilir; her zaman kacislanir.
 * Metinler `i18n/mail*.properties` icindedir (ana messages paketinden ayri, kendi MessageSource'u ile).
 * <p>Yerlesim ve bilesenler ({@link MailLayout}): baslik, paragraflar, (kodlu sablonlarda) kod kutusu, son paragraf
 * "not" (guvenlik/gecerlilik cumlesi; duyuru haric), alt bilgi. Cerceve siyah-beyazdir, bkz. docs/changes/mail.md.
 */
@Component
public class MailRenderer {

    public record Rendered(String subject, String html, String text) {
    }

    private final ResourceBundleMessageSource messages = new ResourceBundleMessageSource();
    private CustomMailContent custom;

    public MailRenderer() {
        messages.setBasename("i18n/mail");
        messages.setDefaultEncoding("UTF-8");
        messages.setFallbackToSystemLocale(false);
    }

    /** Yonetici sablonlari (mail/campaign) icin cozucu; yoksa CUSTOM sablon gonderilemez. */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setCustom(CustomMailContent custom) {
        this.custom = custom;
    }

    public Rendered render(MailTemplate template, Lang lang, Map<String, String> vars) {
        if (template == MailTemplate.CUSTOM) {
            if (custom == null) {
                throw new IllegalStateException("CUSTOM e-posta cozucusu yok");
            }
            return custom.render(lang, vars);
        }
        String prefix = "mail.tpl." + template.key() + ".";
        String code = vars.get("code");
        boolean hasCode = code != null && !code.isBlank();

        String subject = singleLine(fill(text(prefix + "subject", lang), vars, UnaryOperator.identity()));
        String titleText = fill(text(prefix + "title", lang), vars, UnaryOperator.identity());

        // Mantiksal paragraflar: duyuruda mesaj tek parca (serbest metin); digerlerinde doldurulmus metin satirlara bolunur
        // (iki faktorlu bildirim mesaji "olay\nguvenlik cumlesi" iki satirdir).
        List<String> html = new ArrayList<>();
        List<String> plainParas = new ArrayList<>();
        for (String p : text(prefix + "body", lang).split("\n")) {
            if (template == MailTemplate.ANNOUNCEMENT) {
                html.add(fill(p, vars, MailRenderer::escape));
                plainParas.add(fill(p, vars, UnaryOperator.identity()));
            } else {
                for (String h : fill(p, vars, MailRenderer::escape).split("\n")) {
                    html.add(h);
                }
                for (String t : fill(p, vars, UnaryOperator.identity()).split("\n")) {
                    plainParas.add(t);
                }
            }
        }

        int noteIdx = template != MailTemplate.ANNOUNCEMENT && html.size() > 1 ? html.size() - 1 : -1;
        String label = hasCode ? text(prefix + "code.label", lang) : "";
        StringBuilder content = new StringBuilder();
        for (int i = 0; i < html.size(); i++) {
            if (i == noteIdx) {
                if (hasCode) {
                    content.append(MailLayout.code(label, code));
                }
                content.append(MailLayout.note(html.get(i)));
            } else {
                content.append(MailLayout.paragraph(html.get(i)));
            }
        }
        if (hasCode && noteIdx < 0) {
            content.append(MailLayout.code(label, code));
        }

        StringBuilder plain = new StringBuilder(MailLayout.brand(lang)).append("\n\n").append(titleText).append("\n\n");
        for (int i = 0; i < plainParas.size(); i++) {
            if (i == noteIdx && hasCode) {
                plain.append(label).append(" ").append(code).append("\n\n");
            }
            plain.append(plainParas.get(i)).append("\n\n");
        }
        if (hasCode && noteIdx < 0) {
            plain.append(label).append(" ").append(code).append("\n\n");
        }
        plain.append(MailLayout.plainTail(lang, MailLayout.Footer.AUTOMATED));

        String page = MailLayout.page(lang, titleText, content.toString(), MailLayout.Footer.AUTOMATED);
        return new Rendered(subject, page, plain.toString());
    }

    /** `{{x}}` degerini escaper ile, `{{{x}}}` degerini oldugu gibi yerlestirir; bilinmeyen alan bos kalir. */
    static String fill(String template, Map<String, String> vars, UnaryOperator<String> escaper) {
        return MailLayout.fill(template, vars, escaper);
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
}
