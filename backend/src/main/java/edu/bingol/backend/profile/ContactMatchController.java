package edu.bingol.backend.profile;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.ContactMatchDtos.MatchRequest;
import edu.bingol.backend.profile.ContactMatchDtos.MatchResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users/contacts")
public class ContactMatchController {

    static final int USER_PER_HOUR = 6;
    static final int IP_PER_HOUR = 30;

    private final ContactMatchService service;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public ContactMatchController(ContactMatchService service, RateLimiter limiter, ClientIp clientIp) {
        this.service = service;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** Kullanici dizinini toplu taramayi zorlastirmak icin siki saatlik limit (kullanici + IP). */
    @PostMapping("/match")
    public MatchResponse match(@Valid @RequestBody MatchRequest r, HttpServletRequest http) {
        Long uid = CurrentUser.id();
        limiter.check("contacts-match:user:" + uid, USER_PER_HOUR, Duration.ofHours(1));
        limiter.check("contacts-match:ip:" + clientIp.of(http), IP_PER_HOUR, Duration.ofHours(1));
        return service.match(uid, r.hashes());
    }
}
