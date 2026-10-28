package edu.bingol.backend.admin;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URLDecoder;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import tools.jackson.databind.json.JsonMapper;

/**
 * Yonetici isteklerinden SEBEP'i ayiklar ve {@link AuditContext}'e koyar (Spring Security'den SONRA calisir).
 * Kaynaklar (oncelik sirasiyla): `X-Admin-Reason` basligi (Turkce/Arapca icin yuzde-kodlu olabilir), GET'te `reason`
 * sorgu parametresi, JSON govdedeki ust duzey `reason` alani (govde yalnizca bu alan icin okunur ve SAKLANMAZ;
 * Content-Length bilinen ve {@value #MAX_BODY} bayti asmayan govdeler okunup denetleyiciye yeniden sunulur;
 * parcali/buyuk govdede yalniz baslik/parametre gecerlidir).
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 100)
public class AdminReasonFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Admin-Reason";
    static final int MAX_BODY = 65536;
    private static final JsonMapper JSON = JsonMapper.builder().build();

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !req.getRequestURI().startsWith("/api/admin/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        HttpServletRequest next = req;
        AuditContext.Data data = AuditContext.of(req);
        String reason = fromHeader(req.getHeader(HEADER));
        String method = req.getMethod();
        if (reason == null && ("GET".equals(method) || "HEAD".equals(method))) {
            reason = req.getParameter("reason");
        }
        if (reason == null && AdminGuardPolicy.isWrite(method) && isJson(req)) {
            long len = req.getContentLengthLong();
            if (len > 0 && len <= MAX_BODY) {
                byte[] body = req.getInputStream().readNBytes(MAX_BODY + 1);
                reason = fromJson(body);
                next = new CachedBodyRequest(req, body);
            }
        }
        data.reason(reason);
        chain.doFilter(next, res);
    }

    /** Baslik degeri: yuzde-kodlu gelirse (HTTP basliklari ASCII) UTF-8 olarak cozulur. */
    static String fromHeader(String v) {
        if (v == null || v.isBlank()) {
            return null;
        }
        if (v.indexOf('%') >= 0) {
            try {
                return URLDecoder.decode(v, StandardCharsets.UTF_8);
            } catch (IllegalArgumentException e) {
                return v;
            }
        }
        return v;
    }

    /** Ust duzey JSON nesnesinde `reason` metni; bozuk/farkli sekilli govde null. */
    static String fromJson(byte[] body) {
        try {
            Object o = JSON.readValue(body, Object.class);
            if (o instanceof Map<?, ?> m && m.get("reason") instanceof String s) {
                return s;
            }
        } catch (RuntimeException e) {
            // bozuk govde: denetleyici kendi 400'unu verir
        }
        return null;
    }

    private static boolean isJson(HttpServletRequest req) {
        String ct = req.getContentType();
        return ct != null && ct.toLowerCase(java.util.Locale.ROOT).contains("json");
    }

    /** Okunmus govdeyi denetleyiciye yeniden sunar. */
    static final class CachedBodyRequest extends HttpServletRequestWrapper {

        private final byte[] body;
        private BufferedReader reader;

        CachedBodyRequest(HttpServletRequest request, byte[] body) {
            super(request);
            this.body = body;
        }

        @Override
        public ServletInputStream getInputStream() {
            ByteArrayInputStream in = new ByteArrayInputStream(body);
            return new ServletInputStream() {
                @Override
                public boolean isFinished() {
                    return in.available() == 0;
                }

                @Override
                public boolean isReady() {
                    return true;
                }

                @Override
                public void setReadListener(ReadListener l) {
                    throw new UnsupportedOperationException();
                }

                @Override
                public int read() {
                    return in.read();
                }

                @Override
                public int read(byte[] b, int off, int len) {
                    return in.read(b, off, len);
                }
            };
        }

        @Override
        public BufferedReader getReader() {
            if (reader == null) {
                String enc = getCharacterEncoding();
                Charset cs = enc == null ? StandardCharsets.UTF_8 : Charset.forName(enc);
                reader = new BufferedReader(new InputStreamReader(getInputStream(), cs));
            }
            return reader;
        }

        @Override
        public int getContentLength() {
            return body.length;
        }

        @Override
        public long getContentLengthLong() {
            return body.length;
        }
    }
}
