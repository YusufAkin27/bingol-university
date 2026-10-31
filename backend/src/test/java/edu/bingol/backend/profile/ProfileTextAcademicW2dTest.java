package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.profile.dto.ProfileDtos.UpdateProfileRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** T-055: profil metin sinirlari kod noktasi ile sayilir; akademik alanlar birbiriyle tutarli guncellenir. */
class ProfileTextAcademicW2dTest {

    private final UserRepository users = mock(UserRepository.class);
    private final AppInfoService appInfo = mock(AppInfoService.class);
    private final ProfileService service = new ProfileService(users, null, null, null, appInfo, null, null, null,
            null, null, null, null, new CatalogService());

    private User user() {
        User u = new User();
        u.setId(1L);
        u.setDisplayName("Ali Veli");
        when(users.findById(1L)).thenReturn(Optional.of(u));
        when(users.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
        when(appInfo.faculties()).thenReturn(List.of());
        return u;
    }

    private static UpdateProfileRequest bio(String bio) {
        return new UpdateProfileRequest(null, null, null, null, null, bio, null, null);
    }

    private static UpdateProfileRequest academic(String faculty, String department, Short classYear, String grade) {
        return new UpdateProfileRequest(null, faculty, department, classYear, grade, null, null, null);
    }

    @Test
    void threeHundredEmojiBioIsAcceptedAndThreeHundredOneRejected() {
        User u = user();
        String emoji300 = "😀".repeat(300); // UTF-16'da 600 birim, 300 kod noktasi
        service.update(1L, bio(emoji300));
        assertEquals(emoji300, u.getBio());

        ApiException e = assertThrows(ApiException.class, () -> service.update(1L, bio("😀".repeat(301))));
        assertEquals("PROFILE_FIELD_TOO_LONG", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void displayNameLimitIsAlsoCodePoints() {
        user();
        ApiException e = assertThrows(ApiException.class,
                () -> service.update(1L, new UpdateProfileRequest("a".repeat(81), null, null, null, null, null, null, null)));
        assertEquals("PROFILE_FIELD_TOO_LONG", e.code());
    }

    @Test
    void changingFacultyClearsDepartmentThatBelongsToTheOldFaculty() {
        User u = user();
        u.setFaculty("Mühendislik Fakültesi");
        u.setDepartment("Bilgisayar Mühendisliği");

        service.update(1L, academic("Hukuk Fakültesi", null, null, null));

        assertEquals("Hukuk Fakültesi", u.getFaculty());
        assertNull(u.getDepartment()); // Hukuk + Bilgisayar Muhendisligi tutarsiz cift birakilmaz
    }

    @Test
    void sendingFacultyAndMismatchedDepartmentTogetherIsRejected() {
        User u = user();
        ApiException e = assertThrows(ApiException.class,
                () -> service.update(1L, academic("Mühendislik Fakültesi", "Hukuk", null, null)));
        assertEquals("ACADEMIC_INVALID", e.code());
        assertNull(u.getFaculty());
    }

    @Test
    void gradeDerivesClassYear() {
        User u = user();
        service.update(1L, academic(null, null, null, "3"));
        assertEquals("3", u.getGrade());
        assertEquals((short) 3, u.getClassYear());

        service.update(1L, academic(null, null, null, "PREP"));
        assertEquals((short) 0, u.getClassYear());

        service.update(1L, academic(null, null, (short) 4, "MASTER")); // yuksek lisansta sinif yili yok
        assertNull(u.getClassYear());
    }

    @Test
    void conflictingGradeAndClassYearIsRejected() {
        User u = user();
        ApiException e = assertThrows(ApiException.class,
                () -> service.update(1L, academic(null, null, (short) 2, "3")));
        assertEquals("ACADEMIC_INVALID", e.code());
        assertNull(u.getClassYear());
    }

    @Test
    void classYearAloneDerivesGrade() {
        User u = user();
        service.update(1L, academic(null, null, (short) 2, null));
        assertEquals("2", u.getGrade());
        assertEquals((short) 2, u.getClassYear());
    }
}
