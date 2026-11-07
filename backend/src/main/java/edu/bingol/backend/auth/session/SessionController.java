package edu.bingol.backend.auth.session;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.session.SessionDtos.SessionView;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.util.Comparator;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Cihazlarim: kullanicinin acik oturumlari ve tek cihazdan cikis. Kimlik gerekir (SecurityConfig). Baskasinin
 * oturumu listelenmez/silinemez (kayit kullanici kimligiyle aranir; yoksa 404 SESSION_NOT_FOUND).
 */
@RestController
@RequestMapping("/api/auth/sessions")
public class SessionController {

    private final UserSessionService sessions;
    private final RateLimiter limiter;

    public SessionController(UserSessionService sessions, RateLimiter limiter) {
        this.sessions = sessions;
        this.limiter = limiter;
    }

    private static String currentSid(HttpServletRequest http) {
        Object v = http.getAttribute(JwtAuthFilter.SESSION_ID_ATTR);
        return v instanceof String s ? s : null;
    }

    /** Acik oturumlar: bu cihaz (`current:true`) once, sonra en son kullanilan. */
    @GetMapping
    public List<SessionView> list(Authentication authentication, HttpServletRequest http) {
        Long uid = (Long) authentication.getPrincipal();
        limiter.check("sessions:list:" + uid, 60, Duration.ofMinutes(1));
        String cur = currentSid(http);
        return sessions.active(uid).stream()
                .map(s -> SessionView.of(s, s.getSid().equals(cur)))
                .sorted(Comparator.comparing(SessionView::current).reversed()) // sirali akis: bu cihaz basta, gerisi son kullanima gore
                .toList();
    }

    /** Belirli cihazdan cikis: 204. Bu oturumun kendisi de olabilir (normal cikis). 404 SESSION_NOT_FOUND. */
    @DeleteMapping("/{sid}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@PathVariable String sid, Authentication authentication) {
        Long uid = (Long) authentication.getPrincipal();
        limiter.check("sessions:del:" + uid, 20, Duration.ofMinutes(15));
        sessions.revoke(uid, sid);
    }
}
