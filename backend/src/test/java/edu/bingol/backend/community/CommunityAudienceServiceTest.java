package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Kulup onerisi hedef kitlesi: dogrulama, degistirme ve puanlama (bolum 2, fakulte 1). */
class CommunityAudienceServiceTest {

    private final CommunityAudienceRepository repo = mock(CommunityAudienceRepository.class);
    private final CatalogService catalog = new CatalogService();
    private final CommunityAudienceService svc = new CommunityAudienceService(repo, catalog);

    private String faculty() {
        return catalog.catalog().faculties().get(0).name();
    }

    private String dept() {
        return catalog.catalog().faculties().get(0).departments().get(0).name();
    }

    @Test
    void replaceRejectsNamesOutsideCatalog() {
        ApiException e = assertThrows(ApiException.class, () -> svc.replace(1L, List.of("Yok Fakultesi"), null));
        assertEquals("ACADEMIC_INVALID", e.code());
        e = assertThrows(ApiException.class, () -> svc.replace(1L, null, List.of("Yok Bolumu")));
        assertEquals("ACADEMIC_INVALID", e.code());
        verify(repo, never()).save(any());
    }

    @Test
    void replaceRejectsTooManyTargets() {
        List<String> many = new ArrayList<>();
        for (int i = 0; i < 13; i++) {
            many.add("F" + i);
        }
        assertEquals("VALIDATION_ERROR", assertThrows(ApiException.class, () -> svc.replace(1L, many, null)).code());
    }

    @Test
    void nullListsLeaveTargetsUntouched() {
        svc.replace(1L, null, null);
        verify(repo, never()).deleteAllFor(any());
    }

    @Test
    void replaceDeduplicatesAndSaves() {
        svc.replace(1L, List.of(faculty(), " " + faculty() + " ", ""), List.of(dept()));
        verify(repo).deleteAllFor(1L);
        verify(repo, org.mockito.Mockito.times(2)).save(any());
    }

    @Test
    void rankedForPrefersDepartmentMatch() {
        when(repo.matching(any(), any(), any())).thenReturn(List.of(
                new CommunityAudience(5L, CommunityAudience.FACULTY, "F"),
                new CommunityAudience(3L, CommunityAudience.DEPARTMENT, "D"),
                new CommunityAudience(9L, CommunityAudience.FACULTY, "F"),
                new CommunityAudience(9L, CommunityAudience.DEPARTMENT, "D")));
        assertEquals(List.of(9L, 3L, 5L), svc.rankedFor("F", "D"));
    }

    @Test
    void rankedForEmptyProfileGivesNothing() {
        assertEquals(List.of(), svc.rankedFor(null, " "));
        verify(repo, never()).matching(any(), any(), any());
    }
}
