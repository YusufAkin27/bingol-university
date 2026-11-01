package edu.bingol.backend.notification.campaign;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** P04 (A07#7): push kitlesi duyuru/anket ile AYNI eslesmeyi kullanir (buyuk-kucuk harf, Turkce I/İ; sinif = class_year VEYA grade). */
@SpringBootTest
class AudienceResolverGradeTest {

    @Autowired AudienceResolver resolver;
    @Autowired UserRepository users;

    private User user(String faculty, String department, Short classYear, String grade) {
        User u = new User();
        u.setEmail("g" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi");
        u.setEmailVerified(true);
        u.setFaculty(faculty);
        u.setDepartment(department);
        u.setClassYear(classYear);
        u.setGrade(grade);
        u.setLanguage("tr");
        return users.saveAndFlush(u);
    }

    @Test
    void departmentAndFacultyMatchIgnoringCaseAndTurkishDottedI() {
        String tag = UUID.randomUUID().toString().substring(0, 6);
        User a = user("Mühendislik " + tag, "Bilgisayar Mühendisliği " + tag, null, null);
        User b = user("Mühendislik " + tag, "Elektrik " + tag, null, null);

        var byDept = resolver.resolve(PushCampaign.AudienceType.DEPARTMENT,
                "BİLGİSAYAR MÜHENDİSLİĞİ " + tag.toUpperCase(java.util.Locale.ROOT), 1L);
        assertEquals(1, byDept.members().size());
        assertEquals(a.getId(), byDept.members().get(0).id());

        var byFaculty = resolver.resolve(PushCampaign.AudienceType.FACULTY, "mühendislik " + tag, 1L);
        assertEquals(2, byFaculty.members().size());
        assertTrue(byFaculty.members().stream().anyMatch(m -> m.id().equals(b.getId())));
    }

    @Test
    void classYearMatchesLegacyClassYearOrNewGradeCatalog() {
        String f = "Fak-" + UUID.randomUUID().toString().substring(0, 8);
        User legacy = user(f, "A", (short) 2, null);
        User catalog = user(f, "A", null, "2");
        User other = user(f, "A", (short) 3, "3");
        User prep = user(f, "A", null, "PREP");

        var two = resolver.resolve(PushCampaign.AudienceType.CLASS_YEAR, "2", 1L);
        var ids = two.members().stream().map(AudienceResolver.Member::id).toList();
        assertTrue(ids.contains(legacy.getId()));
        assertTrue(ids.contains(catalog.getId()));
        assertFalse(ids.contains(other.getId()));

        var zero = resolver.resolve(PushCampaign.AudienceType.CLASS_YEAR, "0", 1L);
        assertTrue(zero.members().stream().anyMatch(m -> m.id().equals(prep.getId())));
    }
}
