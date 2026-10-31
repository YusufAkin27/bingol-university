package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import edu.bingol.backend.auth.AuthController;
import edu.bingol.backend.auth.AuthService;
import edu.bingol.backend.auth.LoginThrottle;
import edu.bingol.backend.auth.dto.LogoutRequest;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.bookmark.BookmarkController;
import edu.bingol.backend.bookmark.BookmarkService;
import edu.bingol.backend.config.RateLimitProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.legal.LegalController;
import edu.bingol.backend.legal.LegalDtos.AcceptRequest;
import edu.bingol.backend.legal.LegalDtos.ConsentItem;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.legal.LegalType;
import edu.bingol.backend.moderation.BlockController;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.DeviceService;
import edu.bingol.backend.notification.NotificationController;
import edu.bingol.backend.notification.NotificationInboxService;
import edu.bingol.backend.notification.NotificationPrefService;
import edu.bingol.backend.post.follow.FollowController;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.profile.ProfileController;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.dto.ProfileDtos.UpdateProfileRequest;
import edu.bingol.backend.support.feedback.FeedbackController;
import edu.bingol.backend.support.feedback.FeedbackService;
import edu.bingol.backend.support.ticket.PublicSupportService;
import edu.bingol.backend.support.ticket.TicketController;
import edu.bingol.backend.support.ticket.TicketService;
import edu.bingol.backend.user.UserRepository;
import jakarta.validation.Validation;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * T-060: hiz siniri baglantilari. Her uc (a) limiter kotayi astiginda 429 ({@link RateLimitedException}) verir ve
 * servise HIC inmez, (b) beklenen anahtar/pencereyle limiter'i cagirir. Kaynak taramasi: RateLimitCoverageTest.
 */
class WriteEndpointRateLimitTest {

    private final RateLimiter limiter = mock(RateLimiter.class);

    @BeforeEach
    void login() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(1L, null, List.of()));
    }

    @AfterEach
    void logout() {
        SecurityContextHolder.clearContext();
    }

    private void exhausted() {
        doThrow(new RateLimitedException(60)).when(limiter).check(anyString(), anyInt(), any(Duration.class));
    }

    @Test
    void blockAndUnblockAre429WhenExhaustedAndLimitedPerHour() {
        BlockService blocks = mock(BlockService.class);
        UserRepository users = mock(UserRepository.class);
        BlockController c = new BlockController(blocks, users, limiter);

        c.unblock(9L);
        verify(limiter).check("block:user:1", 60, Duration.ofHours(1));

        exhausted();
        assertThrows(RateLimitedException.class, () -> c.block(9L));
        assertThrows(RateLimitedException.class, () -> c.unblock(9L));
        verifyNoInteractions(users);
    }

    @Test
    void legalAcceptIsLimitedAndItemsAreCapped() {
        LegalService legal = mock(LegalService.class);
        LegalController c = new LegalController(legal, limiter, false);
        AcceptRequest ok = new AcceptRequest(List.of(new ConsentItem(LegalType.values()[0], 1)));
        c.accept(ok);
        verify(limiter).check("legal:accept:1", 20, Duration.ofHours(1));

        exhausted();
        assertThrows(RateLimitedException.class, () -> c.accept(ok));

        List<ConsentItem> eleven = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            eleven.add(new ConsentItem(LegalType.values()[0], 1));
        }
        var v = Validation.buildDefaultValidatorFactory().getValidator();
        assertTrue(v.validate(new AcceptRequest(eleven)).stream().anyMatch(x -> x.getPropertyPath().toString().equals("items")),
                "en fazla 10 kalem");
        assertTrue(v.validate(new AcceptRequest(eleven.subList(0, 10))).isEmpty());
    }

    @Test
    void profileUpdateAndViewAreLimited() {
        ProfileService profiles = mock(ProfileService.class);
        edu.bingol.backend.user.User me = new edu.bingol.backend.user.User();
        me.setId(1L);
        me.setDisplayName("Ali Veli");
        org.mockito.Mockito.when(profiles.update(any(), any())).thenReturn(me);
        ProfileController c = new ProfileController(profiles, limiter);
        UpdateProfileRequest r = new UpdateProfileRequest(null, null, null, null, null, "x", null, null);

        c.update(r);
        verify(limiter).check("profile:update:1", 10, Duration.ofHours(1));
        c.get(5L);
        verify(limiter).check("user-view:user:1", 120, Duration.ofMinutes(1));
        verify(limiter).check("user-view-day:user:1", 2000, Duration.ofDays(1));

        org.mockito.Mockito.clearInvocations(profiles);
        exhausted();
        assertThrows(RateLimitedException.class, () -> c.update(r));
        assertThrows(RateLimitedException.class, () -> c.get(5L));
        verifyNoInteractions(profiles);
    }

    @Test
    void followHasDailyCeiling() {
        FollowService service = mock(FollowService.class);
        FollowController c = new FollowController(service, limiter);

        c.follow(5L);
        verify(limiter).check("follow:1", 60, Duration.ofMinutes(1));
        verify(limiter).check("follow-day:1", 500, Duration.ofDays(1));

        org.mockito.Mockito.clearInvocations(service);
        exhausted();
        assertThrows(RateLimitedException.class, () -> c.follow(5L));
        verifyNoInteractions(service);
    }

    @Test
    void suggestionUnvoteAndTicketCloseAreLimited() {
        FeedbackService feedback = mock(FeedbackService.class);
        FeedbackController fc = new FeedbackController(feedback, limiter);
        TicketService tickets = mock(TicketService.class);
        TicketController tc = new TicketController(tickets, limiter, mock(PublicSupportService.class),
                mock(edu.bingol.backend.support.admin.SupportAdminService.class));

        fc.unvote(3L);
        verify(limiter).check("vote:user:1", 60, Duration.ofHours(1));
        tc.close(4L);
        verify(limiter).check("ticket:close:1", 30, Duration.ofHours(1));

        org.mockito.Mockito.clearInvocations(feedback, tickets);
        exhausted();
        assertThrows(RateLimitedException.class, () -> fc.unvote(3L));
        assertThrows(RateLimitedException.class, () -> tc.close(4L));
        verifyNoInteractions(feedback, tickets);
    }

    @Test
    void notificationListAndBookmarkReadsAreLimited() {
        NotificationInboxService inbox = mock(NotificationInboxService.class);
        NotificationController nc = new NotificationController(inbox, mock(NotificationPrefService.class),
                mock(DeviceService.class), limiter);
        BookmarkService bookmarks = mock(BookmarkService.class);
        BookmarkController bc = new BookmarkController(bookmarks, limiter);

        nc.list(null, 20, null, false);
        verify(limiter).check(eq("notif-list:1"), eq(120), any(Duration.class));
        bc.list(null, 20);
        bc.ids();
        verify(limiter, org.mockito.Mockito.times(2)).check("bookmark:read:1", 120, Duration.ofMinutes(1));

        org.mockito.Mockito.clearInvocations(inbox, bookmarks);
        exhausted();
        assertThrows(RateLimitedException.class, () -> nc.list(null, 20, null, false));
        assertThrows(RateLimitedException.class, () -> bc.list(null, 20));
        assertThrows(RateLimitedException.class, () -> bc.ids());
        verifyNoInteractions(inbox, bookmarks);
    }

    @Test
    void logoutIsLimitedPerIpAndPerToken() {
        AuthService auth = mock(AuthService.class);
        AuthController c = new AuthController(auth, limiter, mock(I18n.class), new ClientIp("10.0.0.0/8"),
                mock(ClientContexts.class), mock(JwtService.class), mock(LoginThrottle.class),
                RateLimitProperties.defaults(), mock(RefreshTokenService.class));
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.setRemoteAddr("203.0.113.5");
        LogoutRequest body = new LogoutRequest("refresh-token-value", null);

        c.logout(body, req);
        verify(limiter).check(eq("logout:ip:203.0.113.5"), eq(600), eq(Duration.ofHours(1)));
        verify(limiter).check(eq("logout:tok:" + Hashing.sha256("refresh-token-value")), eq(20), eq(Duration.ofHours(1)));

        org.mockito.Mockito.clearInvocations(auth);
        exhausted();
        assertThrows(RateLimitedException.class, () -> c.logout(body, req));
        verifyNoInteractions(auth);
        assertEquals(429, new RateLimitedException(1).status().value());
    }
}
