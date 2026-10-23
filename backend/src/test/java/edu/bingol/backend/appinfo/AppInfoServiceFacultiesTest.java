package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AppInfoServiceFacultiesTest {

    private final AppSettingRepository repo = mock(AppSettingRepository.class);
    private final AppInfoService service = new AppInfoService(repo);

    private AppSetting setting(String value) {
        AppSetting s = new AppSetting();
        s.setKey("faculties");
        s.setValue(value);
        when(repo.findById("faculties")).thenReturn(Optional.of(s));
        return s;
    }

    @Test
    void splitTrimsDropsEmptiesAndDeduplicates() {
        assertEquals(List.of("A", "B C"), AppInfoService.splitFaculties(" A ; B C;;A ; "));
        assertEquals(List.of(), AppInfoService.splitFaculties(""));
        assertEquals(List.of(), AppInfoService.splitFaculties(null));
    }

    @Test
    void setNormalizesTheList() {
        setting("");
        service.set("faculties", " Mühendislik ;Fen;; Mühendislik");

        ArgumentCaptor<AppSetting> c = ArgumentCaptor.forClass(AppSetting.class);
        verify(repo).save(c.capture());
        assertEquals("Mühendislik;Fen", c.getValue().getValue());
    }

    @Test
    void tooLongFacultyOrListRejected() {
        setting("");
        assertThrows(ApiException.class, () -> service.set("faculties", "x".repeat(121)));
        // 11 x 99 karakter + ayiricilar > 1000
        String many = String.join(";", java.util.stream.IntStream.range(0, 11).mapToObj(i -> "y".repeat(98) + (char) (97 + i)).toList());
        ApiException e = assertThrows(ApiException.class, () -> service.set("faculties", many));
        assertEquals(400, e.status().value());
        verify(repo, org.mockito.Mockito.never()).save(any());
    }

    @Test
    void facultiesReadsFromSetting() {
        setting("A;B");
        assertEquals(List.of("A", "B"), service.faculties());
    }
}
