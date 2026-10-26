package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.AddMembersRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.RenameRequest;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** Grup yonetimi ve detay uclari rate limit'ten gecmeden servise ulasmamali. */
class ConversationControllerRateLimitTest {

    private static final Long ME = 1L;

    private final ConversationService conversations = mock(ConversationService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ConversationController controller =
            new ConversationController(conversations, limiter, mock(ConversationPrefsService.class));

    @BeforeEach
    void login() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(ME, null, List.of()));
    }

    @AfterEach
    void logout() {
        SecurityContextHolder.clearContext();
    }

    private void exhaustLimiter() {
        org.mockito.Mockito.doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(any(), anyInt(), any());
    }

    @Test
    void renameChecksManageLimit() {
        controller.rename(10L, new RenameRequest("Yeni"));

        verify(limiter).check("conv:manage:" + ME, ConversationController.MANAGE_PER_MINUTE, Duration.ofMinutes(1));
        verify(conversations).rename(ME, 10L, "Yeni");
    }

    @Test
    void limitedManageCallsNeverReachService() {
        exhaustLimiter();

        assertThrows(ApiException.class, () -> controller.rename(10L, new RenameRequest("Yeni")));
        assertThrows(ApiException.class, () -> controller.addMembers(10L, new AddMembersRequest(List.of(2L))));
        assertThrows(ApiException.class, () -> controller.removeMember(10L, 2L));
        assertThrows(ApiException.class, () -> controller.leave(10L));
        assertThrows(ApiException.class, () -> controller.detail(10L));

        verify(conversations, never()).rename(any(), any(), any());
        verify(conversations, never()).addMembers(any(), any(), any());
        verify(conversations, never()).removeMember(any(), any(), any());
        verify(conversations, never()).leave(any(), any());
        verify(conversations, never()).detail(any(), eq(10L));
    }
}
