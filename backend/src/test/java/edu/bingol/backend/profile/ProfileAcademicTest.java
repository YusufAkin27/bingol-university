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

class ProfileAcademicTest {

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

    private static UpdateProfileRequest req(String faculty, String department, String grade) {
        return new UpdateProfileRequest(null, faculty, department, null, grade, null, null, null);
    }

    @Test
    void updatesFacultyDepartmentAndGrade() {
        User u = user();
        service.update(1L, req("Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "3"));
        assertEquals("Mühendislik Fakültesi", u.getFaculty());
        assertEquals("Bilgisayar Mühendisliği", u.getDepartment());
        assertEquals("3", u.getGrade());
    }

    @Test
    void blankStringClearsFields() {
        User u = user();
        u.setFaculty("Hukuk Fakültesi");
        u.setDepartment("Hukuk");
        u.setGrade("1");
        service.update(1L, req("", "", ""));
        assertNull(u.getFaculty());
        assertNull(u.getDepartment());
        assertNull(u.getGrade());
    }

    @Test
    void departmentIsCheckedAgainstExistingFacultyWhenOnlyDepartmentSent() {
        User u = user();
        u.setFaculty("Hukuk Fakültesi");
        ApiException e = assertThrows(ApiException.class,
                () -> service.update(1L, req(null, "Bilgisayar Mühendisliği", null)));
        assertEquals("ACADEMIC_INVALID", e.code());
        service.update(1L, req(null, "Hukuk", null));
        assertEquals("Hukuk", u.getDepartment());
    }

    @Test
    void invalidValuesAreRejectedWith400AndNothingChanges() {
        User u = user();
        for (UpdateProfileRequest bad : List.of(req("Uydurma Fakülte", null, null), req(null, null, "7"),
                req("Hukuk Fakültesi", "Tıp", null))) {
            ApiException e = assertThrows(ApiException.class, () -> service.update(1L, bad));
            assertEquals("ACADEMIC_INVALID", e.code());
            assertEquals(400, e.status().value());
        }
        assertNull(u.getFaculty());
        assertNull(u.getGrade());
    }

    @Test
    void legacyFreeTextValuesStayUntouchedWhenNotSent() {
        User u = user();
        u.setFaculty("Eski serbest metin");
        service.update(1L, new UpdateProfileRequest("Yeni Ad", null, null, null, null, null, null, null));
        assertEquals("Eski serbest metin", u.getFaculty());
    }
}
