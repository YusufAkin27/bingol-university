package edu.bingol.backend.share;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.post.media.PostMediaService;
import io.swagger.v3.oas.annotations.Hidden;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Optional;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;

/**
 * Herkese acik paylasim sayfasi: {@code GET /s/{t}/{id}} (t: p gonderi, r reel, n haber/duyuru, e etkinlik) ve OpenGraph
 * gorseli {@code GET /s/{t}/{id}/img}. permitAll; kisisel veri yok, bu yuzden {@code public, max-age=300}.
 * <p>GIZLILIK: yalniz herkese acik icerik onizlenir ({@link ShareService#publicView}). Gizli / silinmis / olmayan /
 * gecersiz kimlik ve taninmayan tur AYNI notr sayfayi (HTTP 200) alir: var/yok ayrimi yapilmaz. Tum yanitlar noindex.
 * Sayfa JSON API'si degildir (OpenAPI'de gizli); sozlesme docs/SHARING.md.
 */
@Controller
@Hidden
public class SharePageController {

    private static final Logger log = LoggerFactory.getLogger(SharePageController.class);
    private static final Pattern ID = Pattern.compile("[0-9]{1,18}");
    private static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");

    private final ShareService shares;
    private final PostMediaService postMedia;
    private final RateLimiter limiter;
    private final ClientIp clientIp;
    private final SharePageRenderer renderer;

    /** Forum konu kucuk resmi (forum.share; yoksa forum OG gorseli 404). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ForumShareImageProvider forumImages;

    @Value("${app.share.ios-store-url:https://apps.apple.com/tr/app/id6830530499}")
    private String iosStoreUrl;
    @Value("${app.share.android-store-url:https://play.google.com/store/apps/details?id=tr.com.bukampus.app}")
    private String androidStoreUrl;
    @Value("${app.share.apple-app-id:6830530499}")
    private String appleAppId;
    @Value("${app.share.android-package:tr.com.bukampus.app}")
    private String androidPackage;
    @Value("${app.share.page-per-minute:300}")
    private int perMinute;

    public SharePageController(ShareService shares, PostMediaService postMedia, RateLimiter limiter, ClientIp clientIp,
                               SharePageRenderer renderer) {
        this.shares = shares;
        this.postMedia = postMedia;
        this.limiter = limiter;
        this.clientIp = clientIp;
        this.renderer = renderer;
    }

    @GetMapping(value = "/s/{t}/{id}", produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> page(@PathVariable("t") String t, @PathVariable("id") String id,
                                       HttpServletRequest req) {
        Lang lang = Lang.of(LocaleContextHolder.getLocale());
        try {
            limiter.check("share:page:" + clientIp.limitKey(req), perMinute, Duration.ofMinutes(1));
        } catch (RateLimitedException e) {
            return html(HttpStatus.TOO_MANY_REQUESTS, renderer.render(neutral(lang, t, id)), 0, e.retryAfterSeconds());
        } catch (RuntimeException e) {
            // Redis kesik: sayfa yalniz veritabanindan uretilir; sinirsiz birakmak yerine devam (cache + CDN koruyucu)
            log.debug("Paylasim sayfasi hiz siniri atlandi: {}", e.toString());
        }
        ShareRef ref = parse(t, id);
        // Profil baglantisi: sayfa HER kimlik icin ayni notr profil sayfasidir (var/gizli/engelli/askida ayrimi sizmaz)
        if (ref != null && ref.type().isUser()) {
            return html(HttpStatus.OK, renderer.render(profile(lang, String.valueOf(ref.id()))), 300, null);
        }
        Optional<ShareService.Resolved> item = ref == null ? Optional.empty() : shares.publicView(ref);
        SharePageRenderer.Page page = item.map(v -> publicPage(lang, v)).orElseGet(() -> neutral(lang, t, id));
        return html(HttpStatus.OK, renderer.render(page), 300, null);
    }

    /** OpenGraph gorseli: yalniz herkese acik gonderinin kucuk resmi; aksi halde 404 (sayfa marka gorseline duser). */
    @GetMapping("/s/{t}/{id}/img")
    public ResponseEntity<Resource> image(@PathVariable("t") String t, @PathVariable("id") String id,
                                          @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String inm,
                                          HttpServletRequest req) {
        try {
            limiter.check("share:img:" + clientIp.limitKey(req), perMinute, Duration.ofMinutes(1));
        } catch (RateLimitedException e) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .header(HttpHeaders.RETRY_AFTER, String.valueOf(e.retryAfterSeconds())).build();
        } catch (RuntimeException e) {
            log.debug("Paylasim gorseli hiz siniri atlandi: {}", e.toString());
        }
        ShareRef ref = parse(t, id);
        if (ref == null || !(ref.type().isPost() || ref.type().isForum() && forumImages != null)) {
            return noImage();
        }
        Optional<Long> mediaId = shares.publicView(ref).map(ShareService.Resolved::mediaId);
        if (mediaId.isEmpty()) {
            return noImage();
        }
        try {
            return ref.type().isForum() ? forumImages.servePublicPreview(mediaId.get(), inm)
                    : postMedia.servePublicPreview(mediaId.get(), inm);
        } catch (ApiException e) {
            return noImage();
        }
    }

    private static ResponseEntity<Resource> noImage() {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)).cachePublic())
                .header("X-Robots-Tag", "noindex, nofollow").build();
    }

    // ------------------------------------------------------------------ sayfa verisi

    static ShareRef parse(String t, String id) {
        ShareType type = ShareType.ofCode(t);
        if (type == null || id == null || !ID.matcher(id).matches()) {
            return null;
        }
        long n = Long.parseLong(id);
        return n <= 0 ? null : new ShareRef(type, n);
    }

    private SharePageRenderer.Page neutral(Lang lang, String t, String id) {
        ShareType type = ShareType.ofCode(t);
        String code = type == null ? "p" : type.code();
        String num = id != null && ID.matcher(id).matches() ? id : "0";
        return build(lang, true, null, renderer.msg("share.neutral.title", lang), null,
                renderer.msg("share.neutral.desc", lang), null, code, num, false);
    }

    private SharePageRenderer.Page profile(Lang lang, String id) {
        return build(lang, true, null, renderer.msg("share.profile.title", lang), null,
                renderer.msg("share.profile.desc", lang), null, ShareType.USER.code(), id, false);
    }

    private SharePageRenderer.Page publicPage(Lang lang, ShareService.Resolved v) {
        ShareType type = v.ref().type();
        String labelKey = switch (type) {
            case NEWS -> "share.label." + (v.kind() == null ? "NEWS" : v.kind());
            case EVENT -> "share.label.EVENT";
            case REEL -> "share.label.REEL";
            case POST -> "VIDEO".equals(v.kind()) ? "share.label.REEL" : "share.label.POST";
            case FORUM_TOPIC -> "share.label.FORUM_TOPIC";
            case FORUM_COMMENT -> "share.label.FORUM_COMMENT";
            case USER -> "share.label.USER";
            case CLUB -> "share.label.CLUB";
            case POLL -> "share.label.POLL";
        };
        String label = renderer.msg(labelKey, lang);
        String desc = v.description();
        if (type == ShareType.EVENT && v.when() != null) {
            String when = DateTimeFormatter.ofPattern("d MMMM yyyy, HH:mm", lang.locale()).format(v.when().atZone(ISTANBUL));
            desc = when + (v.place() != null && !v.place().isBlank() ? " · " + v.place() : "")
                    + (desc != null && !desc.isBlank() ? " — " + desc : "");
        }
        if (desc == null || desc.isBlank()) {
            desc = v.subtitle() != null && !v.subtitle().isBlank() ? label + " · " + v.subtitle()
                    : renderer.msg("share.desc.generic", lang);
        }
        String image = null;
        if (v.mediaId() != null) {
            image = shares.baseUrl() + "/s/" + type.code() + "/" + v.ref().id() + "/img";
        } else if (v.imageUrl() != null && v.imageUrl().startsWith("/files/")) {
            image = shares.baseUrl() + v.imageUrl();
        } else if (v.imageUrl() != null && v.imageUrl().startsWith("https://")) {
            image = v.imageUrl(); // haber gorseli: ShareService.safeBingolImage ile dogrulanmis
        }
        return build(lang, false, label, v.title(), v.subtitle(), desc, image, type.code(),
                String.valueOf(v.ref().id()), type == ShareType.NEWS);
    }

    private SharePageRenderer.Page build(Lang lang, boolean neutral, String label, String title, String subtitle,
                                         String desc, String image, String code, String id, boolean article) {
        String base = shares.baseUrl();
        String canonical = base + "/s/" + code + "/" + id;
        String intent = "intent://s/" + code + "/" + id + "#Intent;scheme=bukampus;package=" + androidPackage
                + ";S.browser_fallback_url=" + URLEncoder.encode(androidStoreUrl, StandardCharsets.UTF_8) + ";end";
        return new SharePageRenderer.Page(lang, neutral, label, title, subtitle, desc, image, canonical,
                "bukampus://s/" + code + "/" + id, intent, iosStoreUrl, androidStoreUrl,
                base + "/" + lang.code() + "/download", base + "/og.png", appleAppId, article);
    }

    private static ResponseEntity<String> html(HttpStatus status, String body, int maxAge, Long retryAfter) {
        HttpHeaders h = new HttpHeaders();
        h.setContentType(new MediaType("text", "html", StandardCharsets.UTF_8));
        h.set("Content-Security-Policy", SharePageRenderer.csp());
        h.set("X-Robots-Tag", "noindex, nofollow");
        h.set(HttpHeaders.VARY, "Accept-Language");
        h.set(HttpHeaders.CACHE_CONTROL, maxAge > 0 ? "public, max-age=" + maxAge : "no-store");
        if (retryAfter != null) {
            h.set(HttpHeaders.RETRY_AFTER, String.valueOf(retryAfter));
        }
        return new ResponseEntity<>(body, h, status);
    }
}
