package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.media.StoredImage;
import edu.bingol.backend.menu.dto.MenuResponse;
import edu.bingol.backend.status.StatusService;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class MenuImageTest {

    private final MenuRepository repo = mock(MenuRepository.class);
    private final MediaService media = mock(MediaService.class);
    private final MenuAdminService service = new MenuAdminService(repo, media, mock(MenuCalorieService.class));
    private final LocalDate date = LocalDate.of(2026, 10, 28);
    private final MockMultipartFile file = new MockMultipartFile("file", "a.jpg", "image/jpeg", new byte[] {1});

    private MenuDay day(String image) {
        MenuDay d = new MenuDay();
        d.setMenuDate(date);
        d.setItems("Corba\nPilav");
        d.setImageUrl(image);
        return d;
    }

    @Test
    void setImageReplacesAndReleasesOld() {
        MenuDay d = day("/files/covers/old.jpg");
        when(repo.findByMenuDate(date)).thenReturn(Optional.of(d));
        when(media.storeImage(any(), eq(ImageKind.COVER)))
                .thenReturn(new StoredImage("/files/covers/new.jpg", "/files/covers/new-t.jpg", 1, 1, 1, "image/jpeg"));
        var res = service.setImage(date, file);
        assertEquals("/files/covers/new.jpg", res.imageUrl());
        assertEquals("2026-10-28", res.date());
        assertEquals("/files/covers/new.jpg", d.getImageUrl());
        verify(media).release("/files/covers/old.jpg");
    }

    @Test
    void missingDayIs404AndStoresNothing() {
        when(repo.findByMenuDate(date)).thenReturn(Optional.empty());
        ApiException e = assertThrows(ApiException.class, () -> service.setImage(date, file));
        assertEquals("MENU_DAY_NOT_FOUND", e.code());
        verify(media, never()).storeImage(any(), any());
        assertThrows(ApiException.class, () -> service.deleteImage(date));
    }

    @Test
    void deleteClearsAndReleases() {
        MenuDay d = day("/files/covers/old.jpg");
        when(repo.findByMenuDate(date)).thenReturn(Optional.of(d));
        service.deleteImage(date);
        assertNull(d.getImageUrl());
        verify(media).release("/files/covers/old.jpg");
    }

    @Test
    void responseCarriesImageUrl() {
        assertEquals("/files/covers/x.jpg", MenuResponse.of(day("/files/covers/x.jpg")).imageUrl());
        assertNull(MenuResponse.of(day(null)).imageUrl());
    }

    @Test
    void badDatesAndRangesRejected() {
        assertEquals("MENU_DATE_INVALID",
                assertThrows(ApiException.class, () -> MenuAdminService.parseDate("28.10.2026")).code());
        assertEquals("MENU_RANGE_INVALID",
                assertThrows(ApiException.class, () -> service.list("2026-10-10", "2026-10-01")).code());
        assertEquals("MENU_RANGE_INVALID",
                assertThrows(ApiException.class, () -> service.list("2020-01-01", "2026-01-01")).code());
    }

    @Test
    void syncKeepsExistingImage() throws Exception {
        MenuScraper scraper = mock(MenuScraper.class);
        MenuRepository r = mock(MenuRepository.class);
        MenuDay d = day("/files/covers/keep.jpg");
        when(scraper.fetch()).thenReturn(List.of(new MenuScraper.Day(date, List.of("Yeni", "Liste"))));
        when(r.findByMenuDate(date)).thenReturn(Optional.of(d));
        int changed = new MenuSyncService(scraper, r, mock(StatusService.class), new SyncProperties(false)).sync();
        assertEquals(1, changed);
        assertEquals("Yeni\nListe", d.getItems());
        assertEquals("/files/covers/keep.jpg", d.getImageUrl());
    }
}
