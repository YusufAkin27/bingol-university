package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.profile.dto.ProfileDtos.UpdateProfileRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** T-060: gorunen ad 7 gunde bir degisir (+ gecmis kaydi); hesap silme gecmisi temizler. */
class DisplayNameCooldownTest {

    private final UserRepository users = mock(UserRepository.class);
    private final AppInfoService appInfo = mock(AppInfoService.class);
    private final DisplayNameChangeRepository history = mock(DisplayNameChangeRepository.class);
    private final ProfileService service = new ProfileService(users, null, null, null, appInfo, null, null, null,
            null, null, null, null, new CatalogService());
    private User u;

    @BeforeEach
    void setUp() {
        u = new User();
        u.setId(1L);
        u.setDisplayName("Ali Veli");
        when(users.findById(1L)).thenReturn(Optional.of(u));
        when(users.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
        when(appInfo.faculties()).thenReturn(List.of());
        service.setNameHistory(history);
    }

    private static UpdateProfileRequest name(String n) {
        return new UpdateProfileRequest(n, null, null, null, null, null, null, null);
    }

    private void lastChange(Duration ago) {
        DisplayNameChange c = new DisplayNameChange();
        c.setUserId(1L);
        c.setChangedAt(Instant.now().minus(ago));
        when(history.findFirstByUserIdOrderByChangedAtDesc(1L)).thenReturn(Optional.of(c));
    }

    @Test
    void firstChangeIsAllowedAndRecorded() {
        when(history.findFirstByUserIdOrderByChangedAtDesc(1L)).thenReturn(Optional.empty());

        service.update(1L, name("Ayse Yilmaz"));

        assertEquals("Ayse Yilmaz", u.getDisplayName());
        org.mockito.ArgumentCaptor<DisplayNameChange> cap = org.mockito.ArgumentCaptor.forClass(DisplayNameChange.class);
        verify(history).save(cap.capture());
        assertEquals("Ali Veli", cap.getValue().getOldName());
        assertEquals("Ayse Yilmaz", cap.getValue().getNewName());
    }

    @Test
    void secondChangeWithinSevenDaysIs429() {
        lastChange(Duration.ofDays(2));

        ApiException e = assertThrows(ApiException.class, () -> service.update(1L, name("Baska Ad")));

        assertEquals("DISPLAY_NAME_COOLDOWN", e.code());
        assertEquals(429, e.status().value());
        assertEquals("Ali Veli", u.getDisplayName());
        verify(history, never()).save(any());
    }

    @Test
    void changeAfterCooldownIsAllowed() {
        lastChange(Duration.ofDays(8));

        service.update(1L, name("Baska Ad"));

        assertEquals("Baska Ad", u.getDisplayName());
        verify(history).save(any(DisplayNameChange.class));
    }

    @Test
    void resendingTheSameNameIsNotAChange() {
        lastChange(Duration.ofHours(1));

        service.update(1L, name("Ali Veli"));

        assertEquals("Ali Veli", u.getDisplayName());
        verify(history, never()).save(any());
    }

    @Test
    void otherFieldsAreNotBlockedByTheNameCooldown() {
        lastChange(Duration.ofHours(1));

        service.update(1L, new UpdateProfileRequest(null, null, null, null, null, "merhaba", null, null));

        assertEquals("merhaba", u.getBio());
    }
}
