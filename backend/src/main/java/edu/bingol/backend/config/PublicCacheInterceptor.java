package edu.bingol.backend.config;

import edu.bingol.backend.legal.LegalType;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.ModelAndView;

/**
 * "Herkese ayni cevap" okuma uclarina HTTP onbellek basligi ekler (ETag zaten {@link WebConfig}'te):
 * {@code Cache-Control: public, max-age=N, stale-while-revalidate=M} + {@code Vary: Accept-Language}.
 *
 * <ul>
 *   <li>Yalniz GET + 200 + uc kendisi Cache-Control koymadiysa. Hata/204/304 yanitlarina dokunulmaz.</li>
 *   <li>Authorization'li istekte {@code public} YOK: {@code private, max-age=N} (paylasimli onbellek/CDN'e girmez).</li>
 *   <li>Kullaniciya ozel uclar (profil, mesaj, bildirim, {@code /api/legal/consents*}, {@code acceptance-status}) listede
 *       olmadigindan basliksiz kalir (Spring Security varsayilan no-cache).</li>
 *   <li>{@code app.cache.enabled=false} iken hic baslik eklenmez.</li>
 * </ul>
 * Yalniz ETag filtresinin (WebConfig) kapsadigi yollar eklenir: govde tamponlandigindan baslik commit oncesi yazilabilir.
 * Sureler sunucu onbellegiyle uyumludur; yonetici degisikligi sunucuda hemen, tarayici/CDN'de en gec max-age sonra gorunur.
 */
@Component
public class PublicCacheInterceptor implements HandlerInterceptor {

    record Policy(int maxAge, int staleWhileRevalidate) {}

    private static final Pattern NEWS_ID = Pattern.compile("/api/news/[0-9]{1,18}");
    private static final Pattern LEGAL = Pattern.compile("/api/legal/([A-Za-z_-]{1,32})");

    private final CacheProperties props;

    public PublicCacheInterceptor(CacheProperties props) {
        this.props = props;
    }

    /** Yol politikasi; null = basliksiz. Yol sorgu dizgesiz, sonda egik cizgisiz olmalidir. */
    static Policy policyFor(String path) {
        if (path == null) {
            return null;
        }
        switch (path) {
            case "/api/news":
            case "/api/app/info":
            case "/api/app/version":
            case "/api/communities/categories":
                return new Policy(60, 120);
            case "/api/menu":
            case "/api/menu/today":
                return new Policy(300, 600);
            case "/api/status":
                return new Policy(30, 60);
            case "/api/faq":
            case "/api/legal":
                return new Policy(600, 1200);
            default:
                break;
        }
        if (NEWS_ID.matcher(path).matches()) {
            return new Policy(300, 600);
        }
        var m = LEGAL.matcher(path);
        if (m.matches() && LegalType.parse(m.group(1)) != null) {
            return new Policy(600, 1200);
        }
        return null;
    }

    @Override
    public void postHandle(HttpServletRequest req, HttpServletResponse res, Object handler, ModelAndView mav) {
        if (!props.enabled() || !"GET".equals(req.getMethod()) || res.getStatus() != HttpServletResponse.SC_OK
                || res.containsHeader("Cache-Control")) {
            return;
        }
        Policy p = policyFor(req.getRequestURI());
        if (p == null) {
            return;
        }
        boolean authed = req.getHeader("Authorization") != null;
        res.setHeader("Cache-Control", authed
                ? "private, max-age=" + p.maxAge()
                : "public, max-age=" + p.maxAge() + ", stale-while-revalidate=" + p.staleWhileRevalidate());
        res.addHeader("Vary", "Accept-Language");
    }
}
