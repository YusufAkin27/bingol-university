package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.ContactMatchDtos.MatchRequest;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

class ContactMatchControllerTest {

    private final ContactMatchService service = mock(ContactMatchService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ClientIp ip = mock(ClientIp.class);
    private final ContactMatchController controller = new ContactMatchController(service, limiter, ip);
    private final HttpServletRequest http = mock(HttpServletRequest.class);

    @BeforeEach
    void login() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        when(ip.of(http)).thenReturn("1.2.3.4");
    }

    @AfterEach
    void logout() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void checksUserAndIpLimitsThenDelegates() {
        controller.match(new MatchRequest(List.of("x")), http);

        verify(limiter).check("contacts-match:user:7", 6, Duration.ofHours(1));
        verify(limiter).check("contacts-match:ip:1.2.3.4", 30, Duration.ofHours(1));
        verify(service).match(7L, List.of("x"));
    }

    @Test
    void limitedCallNeverReachesService() {
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(any(), anyInt(), any());

        assertThrows(ApiException.class, () -> controller.match(new MatchRequest(List.of()), http));
        verify(service, never()).match(any(), any());
    }
}
