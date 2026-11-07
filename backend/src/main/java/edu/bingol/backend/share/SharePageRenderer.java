package edu.bingol.backend.share;

import edu.bingol.backend.i18n.Lang;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import org.springframework.context.MessageSource;

/**
 * Herkese acik paylasim sayfasinin (GET /s/{t}/{id}) HTML'i: TEK dosya, satir ici CSS, tek sabit betik (harici betik/
 * kaynak yok). CSP betigi ve stili ozetle (sha256) yetkilendirir, bu yuzden dinamik veri betige degil `data-*`
 * ozniteliklerine yazilir. Her metin HTML kacislidir; URL'ler cagirandan gelen dogrulanmis degerlerdir ve ayrica kacislanir.
 */
@org.springframework.stereotype.Component
public final class SharePageRenderer {

    /** Mobilde uygulama acilmadiysa mağazaya yonlendiren sabit betik (kendi verisi yok). */
    static final String SCRIPT = "(function(){var b=document.body.dataset,u=navigator.userAgent||'',"
            + "i=/iPad|iPhone|iPod/.test(u)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1),"
            + "a=/Android/i.test(u),s=i?b.ios:(a?b.android:b.web),o=document.getElementById('open'),l=false;"
            + "if(!i&&!a){return}"
            + "if(a&&b.intent&&o){o.href=b.intent}"
            + "function h(){l=true}"
            + "document.addEventListener('visibilitychange',function(){if(document.hidden){h()}});"
            + "window.addEventListener('pagehide',h);window.addEventListener('blur',h);"
            + "try{if(i){var f=document.createElement('iframe');f.style.display='none';f.src=b.app;"
            + "document.body.appendChild(f)}else{location.href=b.intent||b.app}}catch(e){}"
            + "setTimeout(function(){if(!l&&!document.hidden){location.replace(s)}},1500);})();";

    static final String CSS = ":root{--bg:#faf6f3;--surface:#fff;--text:#171e33;--muted:#5f6577;--border:#e8dfd8;"
            + "--primary:#c62a20;--on-primary:#fff;--soft:#fde7e4;--on-soft:#8e1b13;color-scheme:light dark}"
            + "@media(prefers-color-scheme:dark){:root{--bg:#12131c;--surface:#1c1e2b;--text:#f4f1ee;--muted:#b6b9c6;"
            + "--border:#2d3042;--primary:#ff6a5f;--on-primary:#1a0907;--soft:#3a1f22;--on-soft:#ffb4ad}}"
            + "*{box-sizing:border-box}html,body{margin:0}"
            + "body{min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;"
            + "padding:24px 16px;background:var(--bg);color:var(--text);"
            + "font:16px/1.5 system-ui,-apple-system,'Segoe UI',Roboto,'Noto Sans Arabic',sans-serif}"
            + ".brand{font-weight:700;font-size:18px;letter-spacing:.2px;margin:0 0 16px;display:flex;align-items:center;gap:8px}"
            + ".dot{width:12px;height:12px;border-radius:50%;background:var(--primary);display:inline-block}"
            + ".card{width:100%;max-width:440px;background:var(--surface);border:1px solid var(--border);"
            + "border-radius:20px;overflow:hidden;box-shadow:0 8px 32px rgba(23,30,51,.12)}"
            + ".card img{display:block;width:100%;max-height:300px;object-fit:cover;background:var(--soft)}"
            + ".body{padding:20px}"
            + ".chip{display:inline-block;padding:2px 12px;border-radius:999px;background:var(--soft);color:var(--on-soft);"
            + "font-size:13px;font-weight:600;margin-block-end:10px}"
            + "h1{font-size:22px;line-height:1.3;margin:0 0 8px;overflow-wrap:anywhere}"
            + ".sub{color:var(--muted);font-size:14px;margin:0 0 6px;overflow-wrap:anywhere}"
            + ".desc{color:var(--muted);font-size:15px;margin:0 0 4px;overflow-wrap:anywhere}"
            + ".actions{display:flex;flex-direction:column;gap:10px;margin-top:20px}"
            + ".btn{display:flex;align-items:center;justify-content:center;min-height:48px;padding:10px 16px;"
            + "border-radius:14px;border:1px solid var(--border);color:var(--text);text-decoration:none;font-weight:600}"
            + ".btn.primary{background:var(--primary);color:var(--on-primary);border-color:var(--primary)}"
            + ".btn:focus-visible{outline:3px solid var(--primary);outline-offset:2px}"
            + ".row{display:flex;gap:10px;flex-wrap:wrap}.row .btn{flex:1 1 150px}"
            + ".hint{margin:14px 0 0;color:var(--muted);font-size:13px;text-align:center}"
            + ".more{margin-top:14px;font-size:14px}.more a{color:var(--primary)}";

    /** Sayfa verisi; tum metinler ham (kacis render'da). `image` mutlak https URL ya da null (marka gorseli). */
    public record Page(Lang lang, boolean neutral, String label, String title, String subtitle, String description,
                       String image, String canonicalUrl, String appLink, String androidIntent, String iosStoreUrl,
                       String playStoreUrl, String webDownloadUrl, String brandImage, String appleAppId,
                       boolean article) {}

    private final MessageSource messages;

    public SharePageRenderer(MessageSource messages) {
        this.messages = messages;
    }

    public String msg(String key, Lang lang) {
        return messages.getMessage(key, null, key, lang.locale());
    }

    /** CSP basligi: betik ve stil ozetle; gorsel yalniz kendi kokeni, bingol.edu.tr ve data:. */
    public static String csp() {
        return "default-src 'none'; script-src 'sha256-" + sha256(SCRIPT) + "'; style-src 'sha256-" + sha256(CSS)
                + "'; img-src 'self' https://bingol.edu.tr https://*.bingol.edu.tr data:; base-uri 'none'; "
                + "form-action 'none'; frame-ancestors 'none'";
    }

    static String sha256(String s) {
        try {
            return Base64.getEncoder().encodeToString(
                    MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public static String esc(String s) {
        if (s == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&' -> sb.append("&amp;");
                case '<' -> sb.append("&lt;");
                case '>' -> sb.append("&gt;");
                case '"' -> sb.append("&quot;");
                case '\'' -> sb.append("&#39;");
                default -> {
                    if (c < 0x20 && c != '\n' && c != '\t') {
                        sb.append(' ');
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.toString();
    }

    public String render(Page p) {
        Lang lang = p.lang();
        boolean rtl = lang == Lang.AR;
        String brand = msg("share.brand", lang);
        String fullTitle = p.neutral() ? p.title() : p.title() + " | " + brand;
        String img = p.image() != null ? p.image() : p.brandImage();
        StringBuilder h = new StringBuilder(4096);
        h.append("<!doctype html>\n<html lang=\"").append(lang.code()).append("\" dir=\"").append(rtl ? "rtl" : "ltr")
                .append("\">\n<head>\n<meta charset=\"utf-8\">\n")
                .append("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n")
                .append("<title>").append(esc(fullTitle)).append("</title>\n")
                .append("<meta name=\"description\" content=\"").append(esc(p.description())).append("\">\n")
                .append("<meta name=\"robots\" content=\"noindex,nofollow\">\n")
                .append("<meta name=\"theme-color\" content=\"#c62a20\">\n")
                .append("<meta name=\"apple-itunes-app\" content=\"app-id=").append(esc(p.appleAppId()))
                .append(", app-argument=").append(esc(p.canonicalUrl())).append("\">\n")
                .append("<meta property=\"og:site_name\" content=\"").append(esc(brand)).append("\">\n")
                .append("<meta property=\"og:type\" content=\"").append(p.article() ? "article" : "website").append("\">\n")
                .append("<meta property=\"og:title\" content=\"").append(esc(p.title())).append("\">\n")
                .append("<meta property=\"og:description\" content=\"").append(esc(p.description())).append("\">\n")
                .append("<meta property=\"og:url\" content=\"").append(esc(p.canonicalUrl())).append("\">\n")
                .append("<meta property=\"og:image\" content=\"").append(esc(img)).append("\">\n")
                .append("<meta property=\"og:image:alt\" content=\"").append(esc(p.title())).append("\">\n")
                .append("<meta property=\"og:locale\" content=\"").append(locale(lang)).append("\">\n");
        if (p.image() == null) {
            h.append("<meta property=\"og:image:width\" content=\"1200\">\n")
                    .append("<meta property=\"og:image:height\" content=\"630\">\n");
        }
        h.append("<meta name=\"twitter:card\" content=\"summary_large_image\">\n")
                .append("<meta name=\"twitter:title\" content=\"").append(esc(p.title())).append("\">\n")
                .append("<meta name=\"twitter:description\" content=\"").append(esc(p.description())).append("\">\n")
                .append("<meta name=\"twitter:image\" content=\"").append(esc(img)).append("\">\n")
                .append("<style>").append(CSS).append("</style>\n</head>\n<body")
                .append(" data-app=\"").append(esc(p.appLink())).append('"')
                .append(" data-intent=\"").append(esc(p.androidIntent())).append('"')
                .append(" data-ios=\"").append(esc(p.iosStoreUrl())).append('"')
                .append(" data-android=\"").append(esc(p.playStoreUrl())).append('"')
                .append(" data-web=\"").append(esc(p.webDownloadUrl())).append("\">\n")
                .append("<p class=\"brand\"><span class=\"dot\"></span>").append(esc(brand)).append("</p>\n")
                .append("<main class=\"card\">\n");
        if (p.image() != null) {
            h.append("<img src=\"").append(esc(p.image())).append("\" alt=\"\" width=\"440\" height=\"300\">\n");
        }
        h.append("<div class=\"body\">\n");
        if (p.label() != null) {
            h.append("<span class=\"chip\">").append(esc(p.label())).append("</span>\n");
        }
        h.append("<h1>").append(esc(p.title())).append("</h1>\n");
        if (p.subtitle() != null && !p.subtitle().isBlank()) {
            h.append("<p class=\"sub\">").append(esc(p.subtitle())).append("</p>\n");
        }
        if (p.description() != null && !p.description().isBlank() && !p.description().equals(p.title())) {
            h.append("<p class=\"desc\">").append(esc(p.description())).append("</p>\n");
        }
        h.append("<div class=\"actions\">\n")
                .append("<a id=\"open\" class=\"btn primary\" href=\"").append(esc(p.appLink())).append("\">")
                .append(esc(msg("share.cta.open", lang))).append("</a>\n")
                .append("<div class=\"row\">")
                .append("<a class=\"btn\" href=\"").append(esc(p.iosStoreUrl())).append("\" rel=\"noopener\">")
                .append(esc(msg("share.cta.appstore", lang))).append("</a>")
                .append("<a class=\"btn\" href=\"").append(esc(p.playStoreUrl())).append("\" rel=\"noopener\">")
                .append(esc(msg("share.cta.play", lang))).append("</a></div>\n</div>\n")
                .append("<p class=\"hint\">").append(esc(msg("share.hint", lang))).append("</p>\n")
                .append("<p class=\"more\"><a href=\"").append(esc(p.webDownloadUrl())).append("\">")
                .append(esc(msg("share.cta.more", lang))).append("</a></p>\n")
                .append("</div>\n</main>\n<script>").append(SCRIPT).append("</script>\n</body>\n</html>\n");
        return h.toString();
    }

    private static String locale(Lang lang) {
        return switch (lang) {
            case TR -> "tr_TR";
            case EN -> "en_US";
            case AR -> "ar_AR";
        };
    }
}
