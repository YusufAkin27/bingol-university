package edu.bingol.backend.common.web;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * İstek gövdesi boyut sınırı (AccessBanFilter'dan hemen sonra, Spring Security'den ÖNCE). Kimliksiz uçlarda
 * (login, register, destek talebi...) JSON gövdesi hız sınırından önce belleğe okunduğu için 55 MB'lık bir gövde
 * ve eşzamanlı istekler OOM'a yol açabiliyordu. Sınır sınıfları:
 * <ul>
 *   <li>varsayılan JSON uçları: {@code app.http.max-body-bytes} (64 KB)</li>
 *   <li>yönetim uçları (/api/admin/**): {@code app.http.max-admin-body-bytes} (2 MB)</li>
 *   <li>analitik toplu olay: 256 KB</li>
 *   <li>yükleme uçları (allowlist): {@code app.http.max-upload-body-bytes} (55 MB; Caddy ile aynı)</li>
 * </ul>
 * Content-Length sınırı aşıyorsa gövde okunmadan 413 PAYLOAD_TOO_LARGE; parçalı (chunked) gövdelerde akış sayılır
 * ve aşımda {@link RequestBodyTooLargeException} fırlatılır (ApiExceptionHandler 413'e çevirir).
 * Çok parçalı (multipart) yüklemelerde akışı kapsayıcı okur: orada Content-Length önkontrolü + Spring/Tomcat
 * multipart sınırları geçerlidir.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 30)
public class RequestBodyLimitFilter extends OncePerRequestFilter {

    /** Büyük gövdeye izin verilen yükleme uçları (yalnız gövdeli yöntemler). */
    static final List<Pattern> UPLOAD_PATHS = List.of(
            Pattern.compile("^/api/posts/media$"),
            Pattern.compile("^/api/conversations/[^/]+/media$"),
            Pattern.compile("^/api/conversations/[^/]+/avatar$"),
            Pattern.compile("^/api/users/me/avatar$"),
            Pattern.compile("^/api/communities/[^/]+/cover$"),
            Pattern.compile("^/api/communities/[^/]+/logo$"),
            Pattern.compile("^/api/communities/[^/]+/posts/upload$"),
            Pattern.compile("^/api/events/[^/]+/cover$"),
            Pattern.compile("^/api/admin/menu/[^/]+/image$"));

    private static final long ANALYTICS_LIMIT = 256L * 1024;

    private final long maxBody;
    private final long maxAdminBody;
    private final long maxUploadBody;
    private final I18n i18n;

    public RequestBodyLimitFilter(I18n i18n,
                                  @Value("${app.http.max-body-bytes:65536}") long maxBody,
                                  @Value("${app.http.max-admin-body-bytes:2097152}") long maxAdminBody,
                                  @Value("${app.http.max-upload-body-bytes:57671680}") long maxUploadBody) {
        this.i18n = i18n;
        this.maxBody = Math.max(1024, maxBody);
        this.maxAdminBody = Math.max(this.maxBody, maxAdminBody);
        this.maxUploadBody = Math.max(this.maxBody, maxUploadBody);
    }

    /** Bu istek için geçerli üst sınır (bayt); sınırlanmayan istekler için -1. */
    long limitFor(String method, String uri) {
        if (uri == null || !uri.startsWith("/api/")) {
            return -1;
        }
        if (!("POST".equals(method) || "PUT".equals(method) || "PATCH".equals(method) || "DELETE".equals(method))) {
            return -1;
        }
        for (Pattern p : UPLOAD_PATHS) {
            if (p.matcher(uri).matches()) {
                return maxUploadBody;
            }
        }
        if (uri.equals("/api/analytics/events")) {
            return Math.max(maxBody, ANALYTICS_LIMIT);
        }
        if (uri.equals("/api/admin") || uri.startsWith("/api/admin/")) {
            return maxAdminBody;
        }
        return maxBody;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return limitFor(req.getMethod(), req.getRequestURI()) < 0;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        long limit = limitFor(req.getMethod(), req.getRequestURI());
        long declared = req.getContentLengthLong();
        if (declared > limit) {
            reject(req, res);
            return;
        }
        String ct = req.getContentType() == null ? "" : req.getContentType().toLowerCase(java.util.Locale.ROOT);
        if (ct.startsWith("multipart/")) {
            // Akışı kapsayıcı ayrıştırır; Content-Length önkontrolü yukarıda yapıldı
            chain.doFilter(req, res);
            return;
        }
        chain.doFilter(new LimitedRequest(req, limit), res);
    }

    private void reject(HttpServletRequest req, HttpServletResponse res) throws IOException {
        Lang lang = langOf(req.getHeader("Accept-Language"));
        String message = i18n.msg("error.PAYLOAD_TOO_LARGE", lang.locale());
        res.setStatus(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.setHeader("Connection", "close");
        res.getWriter().write("{\"code\":\"PAYLOAD_TOO_LARGE\",\"message\":\""
                + message.replace("\\", "\\\\").replace("\"", "\\\"") + "\"}");
    }

    static Lang langOf(String header) {
        if (header == null || header.isBlank()) {
            return Lang.DEFAULT;
        }
        return Lang.of(header.split(",")[0].split(";")[0]);
    }

    /** Okunan bayt sayısını sayan sarmalayıcı: sınır aşılınca {@link RequestBodyTooLargeException}. */
    static final class LimitedRequest extends HttpServletRequestWrapper {

        private final long limit;
        private ServletInputStream stream;
        private BufferedReader reader;

        LimitedRequest(HttpServletRequest request, long limit) {
            super(request);
            this.limit = limit;
        }

        @Override
        public ServletInputStream getInputStream() throws IOException {
            if (reader != null) {
                throw new IllegalStateException("getReader() zaten cagrildi");
            }
            if (stream == null) {
                stream = new CountingStream(super.getInputStream(), limit);
            }
            return stream;
        }

        @Override
        public BufferedReader getReader() throws IOException {
            if (reader == null) {
                String enc = getCharacterEncoding();
                Charset cs = enc == null ? StandardCharsets.UTF_8 : Charset.forName(enc);
                reader = new BufferedReader(new InputStreamReader(getInputStream(), cs));
            }
            return reader;
        }
    }

    static final class CountingStream extends ServletInputStream {

        private final ServletInputStream in;
        private final long limit;
        private long count;

        CountingStream(ServletInputStream in, long limit) {
            this.in = in;
            this.limit = limit;
        }

        private void add(long n) throws IOException {
            if (n > 0) {
                count += n;
                if (count > limit) {
                    throw new RequestBodyTooLargeException(limit);
                }
            }
        }

        @Override
        public int read() throws IOException {
            int b = in.read();
            if (b >= 0) {
                add(1);
            }
            return b;
        }

        @Override
        public int read(byte[] b, int off, int len) throws IOException {
            int n = in.read(b, off, len);
            add(n);
            return n;
        }

        @Override
        public boolean isFinished() {
            return in.isFinished();
        }

        @Override
        public boolean isReady() {
            return in.isReady();
        }

        @Override
        public void setReadListener(ReadListener listener) {
            in.setReadListener(listener);
        }

        @Override
        public void close() throws IOException {
            in.close();
        }
    }
}
