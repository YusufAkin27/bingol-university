package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.media.StoredImage;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

/** Etkinlik kapagi (medya hatti, yetki, temizlik) ve ana sayfa one cikan etkinlik secimi. */
class EventCoverFeaturedTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final MediaService media = mock(MediaService.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class),
            communities, mock(NotificationService.class), media);

    private final Actor owner = new Actor(7L, false);
    private final Actor stranger = new Actor(8L, false);
    private final MockMultipartFile file = new MockMultipartFile("file", "a.png", "image/png", new byte[] {1});

    private UserEvent event(UserEvent.Status status, String cover) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setStartsAt(Instant.now().plus(Duration.ofDays(2)));
        e.setEndsAt(Instant.now().plus(Duration.ofDays(2)).plusSeconds(3600));
        e.setCreatedBy(7L);
        e.setStatus(status);
        e.setCoverUrl(cover);
        when(events.findById(5L)).thenReturn(Optional.of(e));
        return e;
    }

    @Test
    void ownerSetsCoverThroughMediaPipelineAndOldIsReleased() {
        UserEvent e = event(UserEvent.Status.ACTIVE, "/files/covers/old.jpg");
        when(media.storeImage(file, ImageKind.COVER))
                .thenReturn(new StoredImage("/files/covers/new.jpg", "/files/covers/new-t.jpg", 1600, 900, 10, "image/jpeg"));
        EventView v = svc.setCover(owner, 5L, file);
        assertEquals("/files/covers/new.jpg", v.coverUrl());
        assertEquals("/files/covers/new.jpg", e.getCoverUrl());
        verify(media).release("/files/covers/old.jpg");
    }

    @Test
    void strangerCannotSetCover() {
        event(UserEvent.Status.ACTIVE, null);
        ApiException ex = assertThrows(ApiException.class, () -> svc.setCover(stranger, 5L, file));
        assertEquals("FORBIDDEN", ex.code());
        verify(media, never()).storeImage(any(), any());
    }

    @Test
    void cancelledEventCoverIsNotEditable() {
        event(UserEvent.Status.CANCELLED, null);
        ApiException ex = assertThrows(ApiException.class, () -> svc.setCover(owner, 5L, file));
        assertEquals("EVENT_NOT_EDITABLE", ex.code());
    }

    @Test
    void removeCoverClearsAndReleasesAndIsIdempotent() {
        UserEvent e = event(UserEvent.Status.ACTIVE, "/files/covers/c.jpg");
        svc.removeCover(owner, 5L);
        assertNull(e.getCoverUrl());
        verify(media).release("/files/covers/c.jpg");
        svc.removeCover(owner, 5L); // ikinci cagri: yeni release yok
        verify(media).release("/files/covers/c.jpg");
    }

    @Test
    void cancellingEventReleasesCover() {
        UserEvent e = event(UserEvent.Status.ACTIVE, "/files/covers/c.jpg");
        svc.delete(owner, 5L);
        assertNull(e.getCoverUrl());
        verify(media).release("/files/covers/c.jpg");
    }

    @Test
    void featuredReturnsTopRowOrEmpty() {
        UserEvent e = event(UserEvent.Status.ACTIVE, "/files/covers/c.jpg");
        e.setGoingCount(42);
        when(events.featured(any(), any(), any(), any(), any(), any(), any())).thenReturn(List.of(e));
        Optional<EventView> v = svc.featured(owner);
        assertTrue(v.isPresent());
        assertEquals(42, v.get().goingCount());
        assertEquals("/files/covers/c.jpg", v.get().coverUrl());

        when(events.featured(any(), any(), any(), any(), any(), any(), any())).thenReturn(List.of());
        assertTrue(svc.featured(owner).isEmpty());
    }
}
