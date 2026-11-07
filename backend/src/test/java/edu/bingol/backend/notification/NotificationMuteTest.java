package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** B5: kulup/etkinlik sessize alma karari (kritik tipler susmaz) + NotificationService filtresi + uc davranisi. */
class NotificationMuteTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private final NotificationMuteRepository mutes = mock(NotificationMuteRepository.class);
    private final NotificationService svc = new NotificationService(notifications, prefs, subtypePrefs, devices, fcm, i18n);

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(subtypePrefs.findByUserIdAndSubtype(anyLong(), anyString())).thenReturn(Optional.empty());
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString()))
                .thenReturn(Optional.empty());
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
        // kullanici 1 hem kulup 5'i hem etkinlik 7'yi sessize almis; kullanici 2 hicbirini
        when(mutes.mutedAmong(eq("COMMUNITY"), eq(5L), anyCollection())).thenAnswer(i ->
                ((Collection<Long>) i.getArgument(2)).contains(1L) ? List.of(1L) : List.of());
        when(mutes.mutedAmong(eq("EVENT"), eq(7L), anyCollection())).thenAnswer(i ->
                ((Collection<Long>) i.getArgument(2)).contains(1L) ? List.of(1L) : List.of());
        svc.setMuteService(new NotificationMuteService(mutes));
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void mutedClubPostIsDroppedForMutedUserOnly() {
        svc.send(1L, NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_POST, null, "T", "B", Map.of("communityId", "5"));
        verify(notifications, never()).save(any(Notification.class));

        svc.send(2L, NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_POST, null, "T", "B", Map.of("communityId", "5"));
        verify(notifications).save(any(Notification.class));
    }

    @Test
    void mutedEventReminderIsDropped() {
        svc.send(1L, NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, null, "T", "B", Map.of("eventId", "7"));
        verify(notifications, never()).save(any(Notification.class));
    }

    @Test
    void criticalNotificationsPassEvenWhenMuted() {
        svc.send(1L, NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE, null, "Iptal", "B",
                Map.of("eventId", "7", "eventChange", "CANCELLED"));
        svc.send(1L, NotificationType.EVENT, NotificationSubtype.EVENT_ADMISSION, null, "Kabul", "B", Map.of("eventId", "7"));
        svc.send(1L, NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_JOIN, null, "Uyelik", "B", Map.of("communityId", "5"));
        svc.send(1L, NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_ROLE, null, "Rol", "B", Map.of("communityId", "5"));
        svc.send(1L, NotificationType.SYSTEM, null, null, "Sistem", "B", Map.of("communityId", "5"));
        verify(notifications, times(5)).save(any(Notification.class));
    }

    @Test
    void notificationWithoutSourceKeyIsNeverMuted() {
        assertFalse(NotificationMuteService.mutable(NotificationType.NEWS, null, Map.of("newsId", "1")));
        assertFalse(NotificationMuteService.mutable(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, null));
        assertTrue(NotificationMuteService.mutable(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, Map.of("eventId", "7")));
        assertFalse(NotificationMuteService.mutable(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, Map.of("eventId", "abc")));
    }

    @Test
    void repositoryFailureFailsOpen() {
        NotificationMuteRepository bad = mock(NotificationMuteRepository.class);
        when(bad.mutedAmong(anyString(), anyLong(), anyCollection())).thenThrow(new IllegalStateException("db"));
        assertEquals(Set.of(), new NotificationMuteService(bad).mutedAmong(List.of(1L), NotificationType.EVENT,
                NotificationSubtype.EVENT_REMINDER, Map.of("eventId", "7")));
    }

    // ---- uc davranisi ----

    private NotificationMuteController controller(CommunityMemberRepository members, UserEventRepository events) {
        return new NotificationMuteController(mutes, members, events, mock(RateLimiter.class));
    }

    private static void login(Long id) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(id, null, List.of()));
    }

    @Test
    void cannotMuteClubWhenNotActiveMember() {
        CommunityMemberRepository members = mock(CommunityMemberRepository.class);
        when(members.findByUserIdAndCommunityIdIn(eq(3L), any())).thenReturn(List.of());
        login(3L);
        NotificationMuteController c = controller(members, mock(UserEventRepository.class));
        ApiException e = assertThrows(ApiException.class,
                () -> c.communitySet(5L, new NotificationMuteController.MuteRequest(true)));
        assertEquals("COMMUNITY_NOT_FOUND", e.code());
        verify(mutes, never()).save(any());
    }

    @Test
    void activeMemberCanMuteAndUnmute() {
        CommunityMemberRepository members = mock(CommunityMemberRepository.class);
        CommunityMember m = new CommunityMember();
        m.setStatus(CommunityMember.Status.ACTIVE);
        when(members.findByUserIdAndCommunityIdIn(eq(3L), any())).thenReturn(List.of(m));
        login(3L);
        NotificationMuteController c = controller(members, mock(UserEventRepository.class));
        assertTrue(c.communitySet(5L, new NotificationMuteController.MuteRequest(true)).muted());
        verify(mutes).save(any(NotificationMute.class));
        assertFalse(c.communitySet(5L, new NotificationMuteController.MuteRequest(false)).muted());
        verify(mutes).remove(3L, "COMMUNITY", 5L);
    }

    @Test
    void unknownEventCannotBeMutedButCanAlwaysBeUnmuted() {
        UserEventRepository events = mock(UserEventRepository.class);
        when(events.existsById(99L)).thenReturn(false);
        login(3L);
        NotificationMuteController c = controller(mock(CommunityMemberRepository.class), events);
        assertThrows(ApiException.class, () -> c.eventSet(99L, new NotificationMuteController.MuteRequest(true)));
        assertFalse(c.eventSet(99L, new NotificationMuteController.MuteRequest(false)).muted());
    }
}
