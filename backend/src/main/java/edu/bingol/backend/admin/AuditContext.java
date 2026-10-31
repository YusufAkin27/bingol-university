package edu.bingol.backend.admin;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Istek kapsamli denetim baglami (denetim kaydi v2). Servis/controller hedefi, sebebi ve ozeti burada bildirir;
 * {@link AuditInterceptor} istek bitince {@link AuditRecorder} ile kayda yazar. Istek disinda (birim testi, zamanlayici)
 * tum cagrilar zararsizdir (bos nesne doner / yok sayilir). Govde SAKLANMAZ: yalniz sebep + kisa ozet.
 *
 * <pre>AuditContext.target("USER", id).reason(r).summary("rol: USER -> ADMIN");</pre>
 */
public final class AuditContext {

    /** Istek niteligi anahtari. */
    static final String ATTR = AuditContext.class.getName() + ".data";

    public static final int MAX_REASON = 300;
    public static final int MAX_SUMMARY = 500;

    private AuditContext() {}

    /** Tek istegin denetim bilgisi (degistirilebilir; akici). */
    public static final class Data {
        private volatile String targetType;
        private volatile String targetId;
        private volatile String reason;
        private volatile String summary;
        private volatile boolean reasonInvalid;

        public Data target(String type, Object id) {
            this.targetType = clip(type, 32);
            this.targetId = id == null ? null : clip(String.valueOf(id), 64);
            return this;
        }

        public Data reason(String r) {
            String v = clean(r);
            if (v != null) {
                this.reason = clip(v, MAX_REASON);
            }
            return this;
        }

        public Data summary(String s) {
            String v = clean(s);
            if (v != null) {
                this.summary = clip(v, MAX_SUMMARY);
            }
            return this;
        }

        /** Gerekce metni kontrol karakteri (CR/LF/sekme...) iceriyordu: guvenlik duvari 400 REASON_INVALID verir (T-013). */
        public Data reasonInvalid(boolean v) {
            this.reasonInvalid = v;
            return this;
        }

        public boolean reasonInvalid() {
            return reasonInvalid;
        }

        public String targetType() {
            return targetType;
        }

        public String targetId() {
            return targetId;
        }

        public String reason() {
            return reason;
        }

        public String summary() {
            return summary;
        }
    }

    /** Gecerli istegin baglami; istek yoksa atilan (kaydedilmeyen) bir nesne. */
    public static Data current() {
        RequestAttributes ra = RequestContextHolder.getRequestAttributes();
        if (ra instanceof ServletRequestAttributes sra) {
            return of(sra.getRequest());
        }
        return new Data();
    }

    /** Verilen isteginki (yoksa olusturur). */
    public static Data of(HttpServletRequest req) {
        Object o = req.getAttribute(ATTR);
        if (o instanceof Data d) {
            return d;
        }
        Data d = new Data();
        req.setAttribute(ATTR, d);
        return d;
    }

    /** Varsa (olusturmadan) istegin baglami. */
    static Data peek(HttpServletRequest req) {
        return req.getAttribute(ATTR) instanceof Data d ? d : null;
    }

    public static Data target(String type, Object id) {
        return current().target(type, id);
    }

    public static Data reason(String reason) {
        return current().reason(reason);
    }

    public static Data summary(String summary) {
        return current().summary(summary);
    }

    /** Istekte verilen sebep (yoksa null). */
    public static String currentReason() {
        RequestAttributes ra = RequestContextHolder.getRequestAttributes();
        if (ra instanceof ServletRequestAttributes sra) {
            Data d = peek(sra.getRequest());
            return d == null ? null : d.reason();
        }
        return null;
    }

    private static String clean(String s) {
        if (s == null) {
            return null;
        }
        // Denetim satirini bozan kontrol karakterleri (satir sonu, sekme) bosluga cevrilir
        String v = s.replaceAll("[\\p{Cntrl}]+", " ").trim();
        return v.isEmpty() ? null : v;
    }

    private static String clip(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }
}
