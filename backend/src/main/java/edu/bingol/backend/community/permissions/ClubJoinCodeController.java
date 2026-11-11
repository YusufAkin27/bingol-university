package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.permissions.ClubDtos.JoinByCodeResult;
import edu.bingol.backend.community.permissions.ClubJoinCodeService.JoinCodeRequest;
import edu.bingol.backend.community.permissions.ClubJoinCodeService.JoinCodeView;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Kulup QR katilim uclari (docs/changes/community.md "QR ile katilim"). Yalnizca HTTP eslemesi + rate limit. */
@RestController
@RequestMapping("/api")
public class ClubJoinCodeController {

    private final ClubJoinCodeService codes;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public ClubJoinCodeController(ClubJoinCodeService codes, RateLimiter limiter, ClientIp clientIp) {
        this.codes = codes;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** Ekran ~1 dk'da bir yeniler (60 sn pencere); sik ama makul limit. */
    @GetMapping("/communities/{id}/join-code")
    public JoinCodeView joinCode(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("club-join-code:user:" + a.id(), 60, Duration.ofMinutes(10));
        return codes.issue(a, id);
    }

    /** Kod tahminine karsi sik limit (kullanici basina 10/dk + IP basina 60/dk). */
    @PostMapping("/communities/{id}/join-by-code")
    public JoinByCodeResult joinByCode(@PathVariable Long id, @Valid @RequestBody JoinCodeRequest r,
                                       HttpServletRequest req) {
        Actor a = Actor.current();
        limiter.check("club-qr-join:user:" + a.id(), 10, Duration.ofMinutes(1));
        limiter.check("club-qr-join:ip:" + clientIp.limitKey(req), 60, Duration.ofMinutes(1));
        return codes.join(a, id, r.code());
    }
}
