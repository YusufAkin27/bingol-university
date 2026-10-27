package edu.bingol.backend.config;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.LoggerContext;
import io.sentry.Sentry;
import io.sentry.SentryEvent;
import io.sentry.logback.SentryAppender;
import io.sentry.protocol.Message;
import io.sentry.protocol.Request;
import io.sentry.protocol.SentryException;
import jakarta.annotation.PreDestroy;
import java.util.regex.Pattern;
import org.slf4j.ILoggerFactory;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Istege bagli Sentry hata takibi. {@code SENTRY_DSN} bossa hicbir sey yapmaz (SDK baslatilmaz).
 * Spring Boot starter yerine cekirdek SDK + logback appender kullanilir (Boot 4 uyumluluk riskini azaltir):
 * ERROR duzeyindeki log olaylari (istisnali) Sentry'ye gider. PII gonderilmez; {@link #scrub} istek govdesini,
 * basliklari, cerezleri, sorgu dizesini, kullanici bilgisini siler ve e-posta/token benzeri metni maskeler.
 */
@Component
public class ObservabilitySentry {

    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static final Pattern BEARER = Pattern.compile("(?i)bearer\\s+[A-Za-z0-9._~+/=-]+");
    private static final Pattern JWT = Pattern.compile("eyJ[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]*");
    private static final Pattern SECRET_KV = Pattern.compile(
            "(?i)(password|passwd|sifre|secret|token|authorization|code)([\"'=:\\s]+)([^\\s\"',;&]+)");

    private SentryAppender appender;

    public ObservabilitySentry(@Value("${sentry.dsn:}") String dsn,
                               @Value("${sentry.environment:}") String environment,
                               @Value("${sentry.release:}") String release,
                               @Value("${sentry.traces-sample-rate:0.0}") double tracesSampleRate) {
        if (dsn == null || dsn.isBlank()) {
            return;
        }
        try {
            Sentry.init(o -> {
                o.setDsn(dsn.trim());
                if (!environment.isBlank()) {
                    o.setEnvironment(environment);
                }
                if (!release.isBlank()) {
                    o.setRelease(release);
                }
                o.setSendDefaultPii(false);
                o.setTracesSampleRate(tracesSampleRate);
                o.setBeforeSend((event, hint) -> scrub(event));
            });
            ILoggerFactory f = LoggerFactory.getILoggerFactory();
            if (f instanceof LoggerContext ctx) {
                SentryAppender a = new SentryAppender();
                a.setContext(ctx);
                a.setMinimumEventLevel(Level.ERROR);
                a.setMinimumBreadcrumbLevel(Level.INFO);
                a.start();
                Logger root = ctx.getLogger(Logger.ROOT_LOGGER_NAME);
                root.addAppender(a);
                this.appender = a;
            }
        } catch (RuntimeException e) {
            // Gozlemlenebilirlik hatasi uygulamayi durdurmamali
            LoggerFactory.getLogger(ObservabilitySentry.class).warn("Sentry baslatilamadi: {}", e.toString());
        }
    }

    @PreDestroy
    void close() {
        if (appender != null) {
            appender.stop();
            Sentry.close();
        }
    }

    /** Olay gonderilmeden once kisisel veri/sirlari temizler. Null donmez (olay atilmaz). */
    static SentryEvent scrub(SentryEvent event) {
        Request req = event.getRequest();
        if (req != null) {
            req.setData(null);
            req.setHeaders(null);
            req.setCookies(null);
            req.setQueryString(null);
            req.setEnvs(null);
        }
        event.setUser(null);
        Message m = event.getMessage();
        if (m != null) {
            m.setMessage(mask(m.getMessage()));
            m.setFormatted(mask(m.getFormatted()));
            m.setParams(null);
        }
        if (event.getExceptions() != null) {
            for (SentryException ex : event.getExceptions()) {
                ex.setValue(mask(ex.getValue()));
            }
        }
        return event;
    }

    static String mask(String s) {
        if (s == null) {
            return null;
        }
        String out = EMAIL.matcher(s).replaceAll("[email]");
        out = JWT.matcher(out).replaceAll("[jwt]");
        out = BEARER.matcher(out).replaceAll("Bearer [token]");
        return SECRET_KV.matcher(out).replaceAll("$1$2[gizli]");
    }
}
