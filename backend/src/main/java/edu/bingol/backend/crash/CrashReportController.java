package edu.bingol.backend.crash;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.crash.CrashDtos.ReportRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Mobilin anonim cokme/hata raporu ucu (giris GEREKMEZ; varsa kimlik yok sayilir, kullanici kimligi saklanmaz).
 * Govde en cok 16 KB (RequestBodyLimitFilter). Hiz siniri: cihaz basina gunde {@code app.crash.per-device-per-day}
 * (20) ve dakikada 6; IP basina gunde 300 (cihaz kimligi yoksa 60). Asim 429 + Retry-After; istemci bu durumda
 * raporu atar (yeniden denemez).
 */
@RestController
@RequestMapping("/api/app")
public class CrashReportController {

    private final CrashService service;
    private final RateLimiter limiter;
    private final ClientContexts contexts;
    private final int perDevicePerDay;

    public CrashReportController(CrashService service, RateLimiter limiter, ClientContexts contexts,
                                 @Value("${app.crash.per-device-per-day:20}") int perDevicePerDay) {
        this.service = service;
        this.limiter = limiter;
        this.contexts = contexts;
        this.perDevicePerDay = Math.max(1, perDevicePerDay);
    }

    @PostMapping("/crash-reports")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void report(@Valid @RequestBody ReportRequest r, HttpServletRequest req) {
        ClientContext c = contexts.of(req);
        String ip = ClientIp.limitKey(c.ip());
        if (c.hasDevice()) {
            limiter.check("crash:dev:" + c.deviceHash(), perDevicePerDay, Duration.ofDays(1));
            limiter.check("crash:burst:" + c.deviceHash(), 6, Duration.ofMinutes(1));
            limiter.check("crash:ip:" + ip, 300, Duration.ofDays(1));
        } else {
            limiter.check("crash:ipn:" + ip, 60, Duration.ofDays(1));
            limiter.check("crash:burst:" + ip, 6, Duration.ofMinutes(1));
        }
        service.record(r);
    }
}
