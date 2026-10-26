package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class StrikeAppealBlocklistTest {

    private static final String HASH = "a".repeat(64);

    // --- ihlal takibi ---

    private final ModerationStrikeRepository strikeRepo = mock(ModerationStrikeRepository.class);
    private final SuspendRecommendationRepository recRepo = mock(SuspendRecommendationRepository.class);
    private final ModerationNotifier notifier = mock(ModerationNotifier.class);
    private final UserModerationService userModeration = mock(UserModerationService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final ModerationProperties props = new ModerationProperties(3, 24, 3, 180, 5, 30, 7, 30);
    private final StrikeService strikes = new StrikeService(strikeRepo, recRepo, props, notifier, userModeration, users);

    private Report report() {
        Report r = new Report();
        r.setId(1L);
        r.setTargetType(ReportTargetType.USER_AVATAR);
        r.setTargetId(5L);
        return r;
    }

    private void activeUser(long id) {
        User u = new User();
        u.setId(id);
        u.setStatus(UserStatus.ACTIVE);
        when(users.findById(id)).thenReturn(Optional.of(u));
    }

    @Test
    void thirdStrikeCreatesRecommendationAndNotifiesAdmins() {
        activeUser(10L);
        when(strikeRepo.countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(any(), any(Instant.class))).thenReturn(3L);
        when(recRepo.existsByUserIdAndStatus(10L, SuspendRecommendation.Status.OPEN)).thenReturn(false);

        strikes.record(10L, report(), Report.Resolution.HIDE);

        verify(strikeRepo).save(any(ModerationStrike.class));
        verify(recRepo).save(any(SuspendRecommendation.class));
        verify(notifier).adminRecommendation(10L, 3);
    }

    @Test
    void belowThresholdOrExistingOpenRecommendationDoesNothing() {
        activeUser(10L);
        when(strikeRepo.countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(any(), any(Instant.class))).thenReturn(2L);
        strikes.record(10L, report(), Report.Resolution.WARN);
        verify(recRepo, never()).save(any());

        when(strikeRepo.countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(any(), any(Instant.class))).thenReturn(4L);
        when(recRepo.existsByUserIdAndStatus(10L, SuspendRecommendation.Status.OPEN)).thenReturn(true);
        strikes.record(10L, report(), Report.Resolution.WARN);
        verify(recRepo, never()).save(any());
    }

    @Test
    void suspendedUserGetsNoRecommendation() {
        User u = new User();
        u.setId(10L);
        u.setStatus(UserStatus.SUSPENDED);
        when(users.findById(10L)).thenReturn(Optional.of(u));
        when(strikeRepo.countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(any(), any(Instant.class))).thenReturn(9L);

        strikes.record(10L, report(), Report.Resolution.SUSPEND_USER);

        verify(recRepo, never()).save(any());
    }

    @Test
    void acceptingRecommendationSuspendsUser() {
        SuspendRecommendation r = new SuspendRecommendation();
        r.setId(4L);
        r.setUserId(10L);
        r.setStrikeCount(3);
        when(recRepo.findById(4L)).thenReturn(Optional.of(r));

        strikes.accept(4L, 99L);

        verify(userModeration).suspend(any(), any());
        assertEquals(SuspendRecommendation.Status.ACCEPTED, r.getStatus());
        ApiException e = assertThrows(ApiException.class, () -> strikes.dismiss(4L, 99L));
        assertEquals("ALREADY_RESOLVED", e.code());
    }

    // --- itiraz ---

    private final ModerationAppealRepository appealRepo = mock(ModerationAppealRepository.class);
    private final ModerationTargetStateRepository states = mock(ModerationTargetStateRepository.class);
    private final ReportService reportService = mock(ReportService.class);
    private final StrikeService strikeMock = mock(StrikeService.class);
    private final ReportTargetHandler handler = mock(ReportTargetHandler.class);
    private final AppealService appeals = new AppealService(appealRepo, states, reportService, strikeMock, notifier);

    private ModerationTargetState hidden() {
        ModerationTargetState s = new ModerationTargetState();
        s.setHiddenBy(ModerationTargetState.HiddenBy.AUTO);
        s.setHiddenAt(Instant.now());
        return s;
    }

    private void appealSetup(boolean reversible) {
        when(reportService.handlerFor(ReportTargetType.USER_AVATAR)).thenReturn(handler);
        when(handler.exists(5L)).thenReturn(true);
        when(handler.ownerId(5L)).thenReturn(Optional.of(10L));
        when(handler.reversible()).thenReturn(reversible);
        when(states.findByTargetTypeAndTargetId(ReportTargetType.USER_AVATAR, 5L)).thenReturn(Optional.of(hidden()));
        when(appealRepo.save(any(ModerationAppeal.class))).thenAnswer(i -> {
            ModerationAppeal a = i.getArgument(0);
            a.setId(8L);
            return a;
        });
    }

    @Test
    void ownerCanAppealHiddenContent() {
        appealSetup(true);
        ModerationAppeal a = appeals.create(10L, ReportTargetType.USER_AVATAR, 5L, " lutfen inceleyin ");
        assertEquals("lutfen inceleyin", a.getMessage());
        verify(notifier).adminAppealOpened(8L);
    }

    @Test
    void otherUserGets404NotLeak() {
        appealSetup(true);
        ApiException e = assertThrows(ApiException.class,
                () -> appeals.create(11L, ReportTargetType.USER_AVATAR, 5L, "itiraz ediyorum"));
        assertEquals("APPEAL_TARGET_NOT_FOUND", e.code());
    }

    @Test
    void irreversibleTypeCannotBeAppealed() {
        appealSetup(false);
        ApiException e = assertThrows(ApiException.class,
                () -> appeals.create(10L, ReportTargetType.USER_AVATAR, 5L, "itiraz ediyorum"));
        assertEquals("APPEAL_NOT_ALLOWED", e.code());
    }

    @Test
    void duplicateAppealRejected() {
        appealSetup(true);
        when(appealRepo.existsByUserIdAndTargetTypeAndTargetIdAndCreatedAtAfter(any(), any(), any(), any())).thenReturn(true);
        ApiException e = assertThrows(ApiException.class,
                () -> appeals.create(10L, ReportTargetType.USER_AVATAR, 5L, "itiraz ediyorum"));
        assertEquals("APPEAL_ALREADY_EXISTS", e.code());
    }

    @Test
    void acceptedAppealUnhidesAndRevokesStrikes() {
        appealSetup(true);
        ModerationAppeal a = new ModerationAppeal();
        a.setId(8L);
        a.setUserId(10L);
        a.setTargetType(ReportTargetType.USER_AVATAR);
        a.setTargetId(5L);
        a.setMessage("x");
        when(appealRepo.findById(8L)).thenReturn(Optional.of(a));

        appeals.decide(8L, 99L, true, "hata olmus");

        verify(handler).unhide(5L);
        verify(states).clear(ReportTargetType.USER_AVATAR, 5L);
        verify(strikeMock).revokeForTarget(ReportTargetType.USER_AVATAR, 5L);
        verify(notifier).appealDecided(10L, true, "hata olmus");
        assertEquals(ModerationAppeal.Status.ACCEPTED, a.getStatus());
    }

    @Test
    void rejectedAppealKeepsContentHidden() {
        ModerationAppeal a = new ModerationAppeal();
        a.setId(8L);
        a.setUserId(10L);
        a.setTargetType(ReportTargetType.USER_AVATAR);
        a.setTargetId(5L);
        a.setMessage("x");
        when(appealRepo.findById(8L)).thenReturn(Optional.of(a));

        appeals.decide(8L, 99L, false, null);

        verify(handler, never()).unhide(anyLong());
        assertEquals(ModerationAppeal.Status.REJECTED, a.getStatus());
        assertThrows(ApiException.class, () -> appeals.decide(8L, 99L, true, null));
    }

    // --- yasakli ozet listesi ---

    private final BlockedContentHashRepository hashRepo = mock(BlockedContentHashRepository.class);
    private final ContentBlocklist blocklist = new ContentBlocklist(hashRepo);

    @Test
    void blocklistNormalizesCaseAndRejectsMalformed() {
        when(hashRepo.existsById(HASH)).thenReturn(true);
        assertTrue(blocklist.isBlocked(HASH.toUpperCase()));
        assertFalse(blocklist.isBlocked("zz"));
        assertFalse(blocklist.isBlocked(null));
        ApiException e = assertThrows(ApiException.class, () -> blocklist.add("abc", null, 1L));
        assertEquals("BLOCKLIST_HASH_INVALID", e.code());
    }

    @Test
    void blocklistAddIsIdempotent() {
        when(hashRepo.findById(HASH)).thenReturn(Optional.of(new BlockedContentHash(HASH, "x", 1L)));
        blocklist.add(HASH, "yeni", 2L);
        verify(hashRepo, never()).save(any());
        assertEquals(List.of(), List.of());
    }

    @Test
    void blocklistRemoveMissingIs404() {
        ApiException e = assertThrows(ApiException.class, () -> blocklist.remove(HASH));
        assertEquals("BLOCKLIST_ENTRY_NOT_FOUND", e.code());
    }
}
