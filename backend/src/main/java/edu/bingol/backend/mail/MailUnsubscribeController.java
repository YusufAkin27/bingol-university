package edu.bingol.backend.mail;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

/**
 * Herkese acik abonelikten cikma ucu (kimlik gerektirmez; imzali sureli jeton). GET yalniz onay sayfasini gosterir
 * (posta tarayicilari/onizleyiciler baglantiyi onceden acabilir; durum degistirmez). POST aboneligi bitirir; RFC 8058
 * tek tikla cikis de (List-Unsubscribe-Post) bu POST'a gelir. Gecersiz/suresi dolmus jeton hep ayni genel yanit.
 */
@RestController
@RequestMapping("/api/public/mail")
public class MailUnsubscribeController {

    private static final MediaType HTML = MediaType.parseMediaType("text/html;charset=UTF-8");

    private final UnsubscribeTokens tokens;
    private final MailSuppressionService suppression;
    private final RateLimiter limiter;
    private final ClientIp clientIp;
    private final I18n i18n;

    public MailUnsubscribeController(UnsubscribeTokens tokens, MailSuppressionService suppression,
                                     RateLimiter limiter, ClientIp clientIp, I18n i18n) {
        this.tokens = tokens;
        this.suppression = suppression;
        this.limiter = limiter;
        this.clientIp = clientIp;
        this.i18n = i18n;
    }

    @GetMapping("/unsubscribe")
    public ResponseEntity<String> confirmPage(@RequestParam(name = "token", required = false) String token,
                                              @RequestParam(name = "lang", required = false) String langParam,
                                              HttpServletRequest req) {
        limiter.check("mailunsub:" + clientIp.of(req), 60, Duration.ofHours(1));
        Lang lang = lang(langParam);
        if (tokens.verify(token, Instant.now()).isEmpty()) {
            return page(HttpStatus.BAD_REQUEST, lang, "invalid", null);
        }
        return page(HttpStatus.OK, lang, "confirm", token);
    }

    @PostMapping("/unsubscribe")
    public ResponseEntity<String> unsubscribe(@RequestParam(name = "token", required = false) String token,
                                              @RequestParam(name = "lang", required = false) String langParam,
                                              HttpServletRequest req) {
        limiter.check("mailunsub:" + clientIp.of(req), 60, Duration.ofHours(1));
        Lang lang = lang(langParam);
        Optional<String> hash = tokens.verify(token, Instant.now());
        if (hash.isEmpty()) {
            return page(HttpStatus.BAD_REQUEST, lang, "invalid", null);
        }
        suppression.suppressHash(hash.get(), SuppressionReason.UNSUBSCRIBED);
        return page(HttpStatus.OK, lang, "done", null);
    }

    private static Lang lang(String param) {
        Lang l = Lang.parseStrict(param);
        return l != null ? l : Lang.of(LocaleContextHolder.getLocale());
    }

    /** Kucuk, betiksiz, kendi kendine yeten siyah-beyaz sayfa; metinler i18n/mail*.properties (mail.unsub.*). */
    ResponseEntity<String> page(HttpStatus status, Lang lang, String kind, String token) {
        String title = esc(i18n.msg("mail.unsub." + kind + ".title", lang));
        String body = esc(i18n.msg("mail.unsub." + kind + ".body", lang));
        boolean rtl = lang == Lang.AR;
        StringBuilder h = new StringBuilder(2048);
        h.append("<!DOCTYPE html><html lang=\"").append(lang.code()).append("\" dir=\"")
                .append(rtl ? "rtl" : "ltr").append("\"><head><meta charset=\"UTF-8\">")
                .append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
                .append("<meta name=\"color-scheme\" content=\"light dark\">")
                .append("<meta name=\"robots\" content=\"noindex\"><title>").append(title).append("</title><style>")
                .append("body{margin:0;padding:24px 16px;background:#F4F4F5;color:#27272A;font-weight:400;")
                .append("font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;}")
                .append("main{max-width:480px;margin:40px auto;background:#fff;padding:28px 32px;")
                .append("border:1px solid #E4E4E7;border-radius:12px;}")
                .append("h1{font-size:26px;line-height:1.25;font-weight:400;margin:24px 0 16px;color:#09090B;}")
                .append("p{line-height:1.6;margin:0 0 16px;}.note{font-size:13px;color:#52525B;line-height:1.5;}")
                .append("button{background:#09090B;color:#fff;border:1px solid #09090B;border-radius:12px;")
                .append("padding:14px 28px;font-size:16px;font-weight:400;cursor:pointer;margin:0 0 16px;}")
                .append(".logo-dark{display:none;}")
                .append("@media (prefers-color-scheme:dark){body{background:#09090B;color:#E4E4E7;}")
                .append("main{background:#141416;border-color:#303034;}h1,.txt{color:#FAFAFA !important;}")
                .append(".note{color:#A1A1AA;}button{background:#fff;color:#09090B;border-color:#fff;}")
                .append(".logo-light{display:none !important;}.logo-dark{display:block !important;max-height:none !important;}}")
                .append("</style></head><body><main>")
                .append(MailBrand.forPreview(MailBrand.headerHtml(MailLayout.brand(lang), rtl)))
                .append("<h1>").append(title).append("</h1><p>").append(body).append("</p>");
        if ("confirm".equals(kind)) {
            h.append("<form method=\"post\" action=\"/api/public/mail/unsubscribe?lang=").append(lang.code())
                    .append("\"><input type=\"hidden\" name=\"token\" value=\"").append(esc(token)).append("\">")
                    .append("<button type=\"submit\">")
                    .append(esc(i18n.msg("mail.unsub.confirm.button", lang))).append("</button></form>");
        }
        if (!"invalid".equals(kind)) {
            h.append("<p class=\"note\">").append(esc(i18n.msg("mail.unsub.note", lang))).append("</p>");
        }
        h.append("</main></body></html>");
        return ResponseEntity.status(status).contentType(HTML).cacheControl(CacheControl.noStore())
                .header("Referrer-Policy", "no-referrer").header("X-Robots-Tag", "noindex")
                // sayfaya ozel: yalniz satir ici stil + gomulu (data:) logo + kendi sitesine form; betik yok
                .header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; img-src data:; "
                        + "form-action 'self'; frame-ancestors 'none'; base-uri 'none'")
                .body(h.toString());
    }

    private static String esc(String s) {
        return HtmlUtils.htmlEscape(s == null ? "" : s, "UTF-8");
    }
}
