package edu.bingol.backend.post.follow;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;

/** T-029 (golge engel: takip no-op 200) ve T-053 (oneri nedeni gizli alani sizdirmaz). */
class FollowShadowPrivacyW2dTest {

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    @SuppressWarnings("unchecked")
    private final FollowService svc = new FollowService(jdbc, mock(UserFollowRepository.class), users, blocks,
            mock(PublicProfileMapper.class), mock(ObjectProvider.class));

    private void target() {
        User t = new User();
        t.setId(2L);
        t.setEmailVerified(true);
        when(users.findById(2L)).thenReturn(Optional.of(t));
    }

    @Test
    void followingSomeoneWhoBlockedMeIsA200NoOpWithNoRecord() {
        target();
        when(blocks.isBlocked(1L, 2L)).thenReturn(true);
        when(blocks.hasBlocked(1L, 2L)).thenReturn(false); // beni o engelledi

        FollowService.FollowResult r = svc.follow(1L, 2L);

        assertTrue(r.following());
        assertEquals(0, r.followerCount());
        verifyNoInteractions(jdbc); // takip kaydi / sayac yok
    }

    @Test
    void followingSomeoneIBlockedStaysNotFound() {
        target();
        when(blocks.isBlocked(1L, 2L)).thenReturn(true);
        when(blocks.hasBlocked(1L, 2L)).thenReturn(true);

        assertEquals("USER_NOT_FOUND", assertThrows(ApiException.class, () -> svc.follow(1L, 2L)).code());
    }

    @Test
    void suggestionReasonRequiresTheMatchingFieldToBeVisible() {
        PublicProfile hiddenDept = new PublicProfile(3L, "Gizli", null, null, null, null, null, null);
        PublicProfile deptOnly = new PublicProfile(4L, "Bolum", null, "Bilgisayar", null, null, null, null);
        PublicProfile both = new PublicProfile(5L, "Tam", null, "Bilgisayar", (short) 2, null, null, null);

        assertFalse(FollowService.reasonVisible("DEPARTMENT", hiddenDept)); // ONLY_ME bolum: onerilmez
        assertFalse(FollowService.reasonVisible("GRADE", deptOnly));
        assertTrue(FollowService.reasonVisible("DEPARTMENT", deptOnly));
        assertTrue(FollowService.reasonVisible("GRADE", both));
        assertTrue(FollowService.reasonVisible("CLUB", hiddenDept)); // ortak kulup acik baglamdir
    }
}
