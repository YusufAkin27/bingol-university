package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.ws.PresenceService;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** T-025: presence ucu kullanici basina dakikada 60 ile sinirli (id tarama / izleme). */
class MessagePresenceEndpointTest {

    private static final Long ME = 1L;

    private final PresenceService presence = mock(PresenceService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final MessageController controller = new MessageController(mock(MessageService.class),
            mock(MessageActionService.class), presence, limiter, mock(ReceiptService.class));

    @BeforeEach
    void login() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(ME, null, List.of()));
    }

    @AfterEach
    void logout() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void presenceChecksPerMinuteLimitBeforeReachingService() {
        controller.presence(2L);

        verify(limiter).check("presence:" + ME, MessageController.PRESENCE_PER_MINUTE, Duration.ofMinutes(1));
        verify(presence).view(ME, 2L);
        org.junit.jupiter.api.Assertions.assertEquals(60, MessageController.PRESENCE_PER_MINUTE);
    }

    @Test
    void limitedPresenceNeverReachesService() {
        org.mockito.Mockito.doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(any(), anyInt(), any());

        assertThrows(ApiException.class, () -> controller.presence(2L));

        verify(presence, never()).view(any(), any());
    }
}
