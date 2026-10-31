package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** T-028: silinmis/askidaki/olmayan hedefi engelleme 404 (204 ve gereksiz user_block satiri yok). */
class BlockControllerTargetTest {

    private final BlockService blocks = mock(BlockService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockController controller = new BlockController(blocks, users, mock(edu.bingol.backend.common.RateLimiter.class));

    @BeforeEach
    void login() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(1L, null, List.of()));
    }

    @AfterEach
    void logout() {
        SecurityContextHolder.clearContext();
    }

    private static User user(long id, UserStatus status) {
        User u = new User();
        u.setId(id);
        u.setStatus(status);
        return u;
    }

    @Test
    void activeTargetIsBlocked() {
        when(users.findById(2L)).thenReturn(Optional.of(user(2L, UserStatus.ACTIVE)));

        controller.block(2L);

        verify(blocks).block(1L, 2L);
    }

    @Test
    void deletedSuspendedOrMissingTargetIs404AndNoRowIsWritten() {
        when(users.findById(3L)).thenReturn(Optional.of(user(3L, UserStatus.DELETED)));
        when(users.findById(4L)).thenReturn(Optional.of(user(4L, UserStatus.SUSPENDED)));
        when(users.findById(5L)).thenReturn(Optional.empty());

        for (long id : new long[] {3L, 4L, 5L}) {
            ApiException e = assertThrows(ApiException.class, () -> controller.block(id));
            assertEquals(404, e.status().value());
            assertEquals("USER_NOT_FOUND", e.code());
        }
        verify(blocks, never()).block(anyLong(), anyLong());
    }

    @Test
    void blockingSelfKeepsServiceError() {
        controller.block(1L);

        verify(blocks).block(1L, 1L); // CANNOT_BLOCK_SELF servis katmaninda
    }
}
