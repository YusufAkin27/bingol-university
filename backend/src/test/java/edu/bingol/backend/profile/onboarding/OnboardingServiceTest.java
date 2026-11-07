package edu.bingol.backend.profile.onboarding;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.auth.oauth.OAuthProperties;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.FieldApiException;
import edu.bingol.backend.legal.LegalDtos.PendingConsent;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.legal.LegalType;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.OnboardingRequest;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.OnboardingResponse;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Profil tamamlama (H2 + gercek depolar): idempotency (mevcut veri EZILMEZ), kullanici adi kurallari/benzersizligi/yarisi,
 * katalog dogrulamasi (422), sinif eslemesi, sozlesme onayi, mevcut (eski) kullanicilarin etkilenmemesi.
 */
@SpringBootTest
class OnboardingServiceTest {

    @Autowired UserRepository users;
    @Autowired AccountCreator accounts;
    @Autowired CatalogService catalog;
    @Autowired PlatformTransactionManager tm;

    final LegalService legal = mock(LegalService.class);
    final ContentGuard guard = mock(ContentGuard.class);
    OnboardingService svc;
    String tag;

    @BeforeEach
    void setUp() {
        OAuthProperties props = new OAuthProperties(true, List.of("g"), List.of("a"), true, false);
        svc = new OnboardingService(users, catalog, props);
        svc.setTxManager(tm);
        ReflectionTestUtils.setField(svc, "legal", legal);
        ReflectionTestUtils.setField(svc, "guard", guard);
        tag = UUID.randomUUID().toString().replace("-", "").substring(0, 10);
    }

    private User newOauthUser(String name) {
        return accounts.createFromOAuth(name + "." + tag + "@gmail.com", "Gecici Ad", "G", "A", "tr");
    }

    private String uname(String base) {
        return base + "." + tag; // 24 sinirini asmaz: base kisa tutulur
    }

    private OnboardingRequest req(String username) {
        return new OnboardingRequest("  Ayşe  ", "Yılmaz", username, null, "muhendislik", null,
                "bilgisayar-muhendisligi", null, "Y3", "Merhaba!", true);
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    // ------------------------------------------------------------------ tamamlama

    @Test
    void onboardingCompletesTheProfileAndWritesAllFields() {
        User u = newOauthUser("tam");
        assertFalse(u.isProfileCompleted());

        OnboardingResponse r = svc.onboard(u.getId(), req(uname("ayse")));

        assertTrue(r.profileCompleted());
        User saved = users.findById(u.getId()).orElseThrow();
        assertTrue(saved.isProfileCompleted());
        assertEquals("Ayşe", saved.getFirstName());
        assertEquals("Yılmaz", saved.getLastName());
        assertEquals("Ayşe Yılmaz", saved.getDisplayName());
        assertEquals(uname("ayse"), saved.getUsername());
        assertEquals("Bingöl Üniversitesi", saved.getUniversityName());
        assertEquals("Mühendislik Fakültesi", saved.getFaculty());
        assertEquals("Bilgisayar Mühendisliği", saved.getDepartment());
        assertEquals("3", saved.getGrade());
        assertEquals((short) 3, saved.getClassYear());
        assertEquals("Merhaba!", saved.getBio());
        assertEquals(uname("ayse"), r.user().username());
        assertTrue(r.user().profileCompleted());
        verify(legal).recordSignupConsent(u.getId()); // acceptTerms=true: onay kaydi
    }

    @Test
    void secondOnboardingCallIsIdempotentAndNeverOverwritesExistingData() {
        User u = newOauthUser("idem");
        svc.onboard(u.getId(), req(uname("ilk")));

        // farkli verilerle tekrar: mevcut profil ezilmez, ayni sonuc doner
        OnboardingRequest other = new OnboardingRequest("Baska", "Kisi", uname("ikinci"), "Baska Uni", null, "Baska Fak",
                null, "Baska Bol", "Y1", "degisti", true);
        OnboardingResponse again = svc.onboard(u.getId(), other);

        assertTrue(again.profileCompleted());
        User saved = users.findById(u.getId()).orElseThrow();
        assertEquals("Ayşe", saved.getFirstName());
        assertEquals(uname("ilk"), saved.getUsername());
        assertEquals("Merhaba!", saved.getBio());
        assertEquals(uname("ilk"), again.user().username());
        verify(legal, org.mockito.Mockito.times(1)).recordSignupConsent(u.getId());
    }

    @Test
    void existingLegacyUsersAreAlreadyCompleteAndOnboardingDoesNotTouchThem() {
        User legacy = new User(); // eski yol: new User() varsayilan tamamlanmis
        legacy.setEmail("eski." + tag + "@bingol.edu.tr");
        legacy.setPasswordHash("$2a$04$abcdefghijklmnopqrstuuabcdefghijklmnopqrstuvwxyz01234");
        legacy.setDisplayName("Eski Kullanici");
        legacy.setEmailVerified(true);
        legacy.setBio("eski bio");
        legacy = users.save(legacy);
        assertTrue(legacy.isProfileCompleted());
        assertNull(legacy.getUsername());

        OnboardingResponse r = svc.onboard(legacy.getId(), req(uname("eski")));

        assertTrue(r.profileCompleted());
        User saved = users.findById(legacy.getId()).orElseThrow();
        assertEquals("Eski Kullanici", saved.getDisplayName());
        assertEquals("eski bio", saved.getBio());
        assertNull(saved.getUsername(), "tamamlanmis hesaba onboarding yazmaz");
    }

    // ------------------------------------------------------------------ kullanici adi

    @Test
    void usernameRulesAreEnforced() {
        User u = newOauthUser("kural");
        for (String bad : new String[] {"ab", "a".repeat(25), "1abc", "_abc", "abc..d", "ab__cd", "abc.", "ab c", "Ağa123",
                "abc-def", "abc@def", "ABC DEF", ""}) {
            ApiException e = assertThrows(ApiException.class, () -> svc.onboard(u.getId(), req(bad)), bad);
            assertTrue("USERNAME_INVALID".equals(e.code()) || "VALIDATION_ERROR".equals(e.code()), bad + " -> " + e.code());
        }
        for (String reserved : new String[] {"admin", "Admin", "bukampus", "destek", "support", "a.d.m.i.n", "admin2024", "bu_kampus"}) {
            assertEquals("USERNAME_RESERVED", code(() -> svc.onboard(u.getId(), req(reserved))), reserved);
        }
        assertFalse(users.findById(u.getId()).orElseThrow().isProfileCompleted(), "reddedilen istek hicbir sey yazmaz");
    }

    @Test
    void usernameIsCaseInsensitiveAndStoredLowercase() {
        User u = newOauthUser("kucuk");
        svc.onboard(u.getId(), req(("Ayse." + tag).toUpperCase()));
        assertEquals(("ayse." + tag).toLowerCase(), users.findById(u.getId()).orElseThrow().getUsername());
    }

    @Test
    void takenUsernameIsRejectedCaseInsensitively() {
        User first = newOauthUser("bir");
        User second = newOauthUser("iki");
        svc.onboard(first.getId(), req(uname("ortak")));

        FieldApiException e = assertThrows(FieldApiException.class, () -> svc.onboard(second.getId(), req(uname("ORTAK"))));
        assertEquals("USERNAME_TAKEN", e.code());
        assertEquals(409, e.status().value());
        assertFalse(users.findById(second.getId()).orElseThrow().isProfileCompleted());
    }

    @Test
    void concurrentOnboardingForTheSameUsernameLetsExactlyOneWin() throws Exception {
        User a = newOauthUser("yaris1");
        User b = newOauthUser("yaris2");
        String name = uname("yaris");
        CountDownLatch go = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<String> fa = pool.submit(() -> race(go, a.getId(), name));
            Future<String> fb = pool.submit(() -> race(go, b.getId(), name));
            go.countDown();
            List<String> results = List.of(fa.get(20, TimeUnit.SECONDS), fb.get(20, TimeUnit.SECONDS));
            assertEquals(1, results.stream().filter("OK"::equals).count(), results.toString());
            assertEquals(1, results.stream().filter("USERNAME_TAKEN"::equals).count(), results.toString());
        } finally {
            pool.shutdownNow();
        }
        long owners = List.of(a, b).stream().map(x -> users.findById(x.getId()).orElseThrow())
                .filter(x -> name.equals(x.getUsername())).count();
        assertEquals(1, owners);
        long completed = List.of(a, b).stream().map(x -> users.findById(x.getId()).orElseThrow())
                .filter(User::isProfileCompleted).count();
        assertEquals(1, completed, "kaybeden kullanici tamamlanmis sayilmaz, tekrar deneyebilir");
    }

    private String race(CountDownLatch go, Long uid, String name) throws Exception {
        go.await();
        try {
            svc.onboard(uid, req(name));
            return "OK";
        } catch (ApiException e) {
            return e.code();
        }
    }

    @Test
    void usernameAvailabilityReportsTakenInvalidReservedAndOwn() {
        User me = newOauthUser("musait");
        User other = newOauthUser("musait2");
        svc.onboard(other.getId(), req(uname("dolu")));

        assertTrue(svc.availability(me.getId(), uname("bos")).available());
        var taken = svc.availability(me.getId(), uname("DOLU"));
        assertFalse(taken.available());
        assertEquals("TAKEN", taken.reason());
        assertEquals("INVALID", svc.availability(me.getId(), "a!").reason());
        assertEquals("RESERVED", svc.availability(me.getId(), "admin").reason());
        assertEquals("INVALID", svc.availability(me.getId(), null).reason());
        // kendi adi musait
        assertTrue(svc.availability(other.getId(), uname("dolu")).available());
    }

    @Test
    void profaneUsernameIsRejected() {
        User u = newOauthUser("kufur");
        doThrow(new FieldApiException(org.springframework.http.HttpStatus.UNPROCESSABLE_ENTITY, "CONTENT_PROFANITY", "x", "username"))
                .when(guard).assertClean(any(), eq("username"), any(), anyString());

        assertEquals("CONTENT_PROFANITY", code(() -> svc.onboard(u.getId(), req(uname("kotu")))));
        assertEquals("INVALID", svc.availability(u.getId(), uname("kotu")).reason());
        assertFalse(users.findById(u.getId()).orElseThrow().isProfileCompleted());
    }

    @Test
    void legacyUserCanSetAnOptionalUsernameWithCooldownOnChanges() {
        User legacy = newOauthUser("eskiad");
        svc.onboard(legacy.getId(), req(uname("ilkad")));
        User saved = users.findById(legacy.getId()).orElseThrow();

        // ayni deger: idempotent
        assertEquals(uname("ilkad"), svc.setUsername(legacy.getId(), uname("ilkad")).username());
        // degisim: bekleme suresi (varsayilan 30 gun) icinde 429
        ApiException cd = assertThrows(ApiException.class, () -> svc.setUsername(legacy.getId(), uname("yeniad")));
        assertEquals("USERNAME_COOLDOWN", cd.code());
        assertEquals(429, cd.status().value());

        // bekleme suresi dolmus: degisir
        saved.setUsernameSetAt(java.time.Instant.now().minus(java.time.Duration.ofDays(31)));
        users.save(saved);
        assertEquals(uname("yeniad"), svc.setUsername(legacy.getId(), uname("yeniad")).username());

        // username'i hic olmayan eski hesap: ilk atama serbest
        User bare = new User();
        bare.setEmail("bare." + tag + "@bingol.edu.tr");
        bare.setPasswordHash("x");
        bare.setDisplayName("Bare");
        bare.setEmailVerified(true);
        bare = users.save(bare);
        assertEquals(uname("bare"), svc.setUsername(bare.getId(), uname("bare")).username());
    }

    // ------------------------------------------------------------------ akademik dogrulama

    @Test
    void invalidCatalogDataIs422AcademicInvalid() {
        User u = newOauthUser("katalog");
        for (OnboardingRequest bad : new OnboardingRequest[] {
                new OnboardingRequest("Ali", "Veli", uname("kat1"), null, "yok-fakulte", null, "x", null, "Y1", null, true),
                new OnboardingRequest("Ali", "Veli", uname("kat2"), null, "muhendislik", null, "hukuk-bolumu", null, "Y1", null, true),
                // bolum baska fakultenin
                new OnboardingRequest("Ali", "Veli", uname("kat3"), null, null, "Hukuk Fakültesi", null, "Bilgisayar Mühendisliği", "Y1", null, true)}) {
            ApiException e = assertThrows(ApiException.class, () -> svc.onboard(u.getId(), bad));
            assertEquals("ACADEMIC_INVALID", e.code());
            assertEquals(422, e.status().value());
        }
        assertFalse(users.findById(u.getId()).orElseThrow().isProfileCompleted());
    }

    @Test
    void facultyAndDepartmentAreRequiredExceptForOtherClass() {
        User u = newOauthUser("zorunlu");
        FieldApiException f = assertThrows(FieldApiException.class, () -> svc.onboard(u.getId(),
                new OnboardingRequest("Ali", "Veli", uname("zor1"), null, null, null, null, null, "Y1", null, true)));
        assertEquals("PROFILE_FIELD_REQUIRED", f.code());
        assertEquals("faculty", f.field());
        FieldApiException d = assertThrows(FieldApiException.class, () -> svc.onboard(u.getId(),
                new OnboardingRequest("Ali", "Veli", uname("zor2"), null, "muhendislik", null, null, null, "Y1", null, true)));
        assertEquals("department", d.field());

        // sinif "Diger": fakulte/bolum yok kabul
        svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", uname("zor3"), null, null, null, null, null, "OTHER", null, true));
        User saved = users.findById(u.getId()).orElseThrow();
        assertNull(saved.getFaculty());
        assertNull(saved.getGrade());
        assertTrue(saved.isProfileCompleted());
    }

    @Test
    void catalogNamesInAnyLanguageAreAccepted() {
        User u = newOauthUser("ad");
        svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", uname("adlar"), null, null, "faculty of engineering",
                null, "COMPUTER ENGINEERING", "Y2", null, true));
        User saved = users.findById(u.getId()).orElseThrow();
        assertEquals("Mühendislik Fakültesi", saved.getFaculty()); // kanonik TR ad saklanir
        assertEquals("Bilgisayar Mühendisliği", saved.getDepartment());
    }

    @Test
    void classYearValuesMapToTheExistingGradeModel() {
        String[][] cases = {{"PREP", "PREP", "0"}, {"Y1", "1", "1"}, {"Y6", "6", "6"}, {"POSTGRAD", "MASTER", null},
                {"MASTER", "MASTER", null}, {"PHD", "PHD", null}};
        for (String[] c : cases) {
            User u = newOauthUser("sinif" + c[0].toLowerCase());
            svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", "s" + c[0].toLowerCase() + "." + tag, null,
                    "muhendislik", null, "bilgisayar-muhendisligi", null, c[0], null, true));
            User saved = users.findById(u.getId()).orElseThrow();
            assertEquals(c[1], saved.getGrade(), c[0]);
            assertEquals(c[2] == null ? null : Short.valueOf(c[2]), saved.getClassYear(), c[0]);
        }
    }

    @Test
    void otherUniversityTakesFreeTextAndSkipsTheBingolCatalog() {
        User u = newOauthUser("baskauni");
        svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", uname("uni"), "Ankara Üniversitesi", null, "Tıp Fakültesi",
                null, "Tıp", "Y4", null, true));
        User saved = users.findById(u.getId()).orElseThrow();
        assertEquals("Ankara Üniversitesi", saved.getUniversityName());
        assertEquals("Tıp Fakültesi", saved.getFaculty());
        assertEquals("Tıp", saved.getDepartment());
    }

    // ------------------------------------------------------------------ ad / biyografi / sozlesme

    @Test
    void invalidNamesAndLongBioAreRejected() {
        User u = newOauthUser("isim");
        // gorunmez karakter / ayrilmis ad
        assertEquals("RESERVED_DISPLAY_NAME", code(() -> svc.onboard(u.getId(), new OnboardingRequest("Admin", "Destek", uname("isim1"), null,
                "muhendislik", null, "bilgisayar-muhendisligi", null, "Y1", null, true))));
        assertEquals("PROFILE_FIELD_TOO_LONG", code(() -> svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", uname("isim2"), null,
                "muhendislik", null, "bilgisayar-muhendisligi", null, "Y1", "x".repeat(301), true))));
        assertFalse(users.findById(u.getId()).orElseThrow().isProfileCompleted());
    }

    @Test
    void termsAreRequiredUnlessAlreadyAcceptedAndConsentIsRecorded() {
        User u = newOauthUser("sozlesme");
        when(legal.pending(eq(u.getId()), any())).thenReturn(List.of(new PendingConsent(LegalType.TERMS, 2, "Kullanim")));

        // acceptTerms yok/false + bekleyen onay: reddedilir, hicbir sey yazilmaz
        assertEquals("TERMS_REQUIRED", code(() -> svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", uname("soz1"), null,
                "muhendislik", null, "bilgisayar-muhendisligi", null, "Y1", null, null))));
        assertFalse(users.findById(u.getId()).orElseThrow().isProfileCompleted());
        verify(legal, never()).recordSignupConsent(any());

        // onceden /api/legal/accept ile onaylandi (bekleyen yok): acceptTerms olmadan da tamamlanir
        when(legal.pending(eq(u.getId()), any())).thenReturn(List.of());
        OnboardingResponse r = svc.onboard(u.getId(), new OnboardingRequest("Ali", "Veli", uname("soz2"), null,
                "muhendislik", null, "bilgisayar-muhendisligi", null, "Y1", null, null));
        assertTrue(r.profileCompleted());
        verify(legal, never()).recordSignupConsent(any());
    }

    @Test
    void completedProfileIsVisibleInTheViewOnly() {
        User u = newOauthUser("gorunum");
        OnboardingResponse r = svc.onboard(u.getId(), req(uname("gorunum")));
        assertNotNull(r.user());
        assertEquals(u.getId(), r.user().id());
        assertTrue(r.user().emailVerified());
    }
}
