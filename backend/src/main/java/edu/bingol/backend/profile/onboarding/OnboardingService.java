package edu.bingol.backend.profile.onboarding;

import edu.bingol.backend.auth.oauth.OAuthProperties;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.catalog.CatalogService.Department;
import edu.bingol.backend.catalog.CatalogService.Faculty;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.FieldApiException;
import edu.bingol.backend.common.ShortTx;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.profile.dto.ProfileDtos.ProfileView;
import edu.bingol.backend.profile.naming.DisplayNamePolicy;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.OnboardingRequest;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.OnboardingResponse;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.UsernameAvailability;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.text.Normalizer;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Profil tamamlama (onboarding) ve kullanici adi. Onboarding YALNIZ {@code profile_completed_at IS NULL} iken tam yazma
 * yapar; tamamlanmis hesapta ayni istek tekrari mevcut veriyi EZMEDEN ayni sonucu doner (idempotent; sonraki degisiklikler
 * PATCH /api/users/me ve PUT /api/users/me/username ile). Alanlar KULLANICI BEYANIDIR: "dogrulanmis ogrenci" degildir.
 */
@Service
public class OnboardingService {

    static final String DEFAULT_UNIVERSITY = "Bingöl Üniversitesi";
    static final int BIO_MAX = 300;
    static final int PART_MAX = 60;

    private final UserRepository users;
    private final CatalogService catalog;
    private final OAuthProperties props;
    private ShortTx tx = ShortTx.direct();

    @Autowired(required = false)
    private ContentGuard guard;

    @Autowired(required = false)
    private LegalService legal;

    /** Kullanici adi degisiminde en kisa bekleme (gun; ilk atama serbest); 0 = sinirsiz. */
    @Value("${app.profile.username-cooldown-days:30}")
    private int usernameCooldownDays = 30;

    public OnboardingService(UserRepository users, CatalogService catalog, OAuthProperties props) {
        this.users = users;
        this.catalog = catalog;
        this.props = props;
    }

    @Autowired(required = false)
    void setTxManager(PlatformTransactionManager tm) {
        this.tx = ShortTx.of(tm);
    }

    /** Bolum sohbeti (istege bagli: elle kurulan testler icin). */
    @Autowired(required = false)
    private edu.bingol.backend.messaging.room.dept.DepartmentChatService departmentChat;

    /** Ilk bolum atamasi (OAuth onboarding): bolum odasi kurulur + kullanici eklenir; hata onboarding'i bozmaz. */
    private void joinDepartmentChat(Long userId) {
        if (departmentChat == null) return;
        try {
            departmentChat.joinOnSignup(userId);
        } catch (RuntimeException e) {
            // sozlesme: sohbet katilimi onboarding'i asla bozmaz
        }
    }

    // ------------------------------------------------------------------ kullanici adi

    /** Musaitlik (yalniz oturumlu; hiz siniri controller'da). Kendi adi "musait" sayilir. */
    public UsernameAvailability availability(Long userId, String raw) {
        UsernamePolicy.Checked c = UsernamePolicy.check(raw);
        if (c.result() == UsernamePolicy.Result.INVALID) {
            return UsernameAvailability.no("INVALID");
        }
        if (c.result() == UsernamePolicy.Result.RESERVED) {
            return UsernameAvailability.no("RESERVED");
        }
        if (isProfane(userId, c.username())) {
            return UsernameAvailability.no("INVALID");
        }
        User other = users.findByUsername(c.username()).orElse(null);
        return other == null || other.getId().equals(userId) ? UsernameAvailability.yes() : UsernameAvailability.no("TAKEN");
    }

    private boolean isProfane(Long userId, String username) {
        if (guard == null) {
            return false;
        }
        try {
            guard.assertClean(Entity.PROFILE, "username", userId, username.replace('.', ' ').replace('_', ' '));
            return false;
        } catch (ApiException e) {
            return true;
        }
    }

    /** Tamamlanmis hesapta kullanici adi atar/degistirir (ilk atama serbest; degisim bekleme suresine tabidir). */
    public ProfileView setUsername(Long userId, String raw) {
        UsernamePolicy.Checked c = requireUsable(userId, raw);
        try {
            return tx.call(() -> {
                User u = load(userId);
                if (c.username().equals(u.getUsername())) {
                    return ProfileView.of(u); // ayni deger: idempotent
                }
                if (u.getUsername() != null && usernameCooldownDays > 0 && u.getUsernameSetAt() != null
                        && u.getUsernameSetAt().plus(Duration.ofDays(usernameCooldownDays)).isAfter(Instant.now())) {
                    throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "USERNAME_COOLDOWN",
                            "Kullanıcı adınızı " + usernameCooldownDays + " günde bir değiştirebilirsiniz.",
                            String.valueOf(usernameCooldownDays));
                }
                if (users.findByUsername(c.username()).isPresent()) {
                    throw taken();
                }
                u.setUsername(c.username());
                u.setUsernameSetAt(Instant.now());
                return ProfileView.of(users.saveAndFlush(u));
            });
        } catch (DataIntegrityViolationException race) {
            throw taken(); // eszamanli iki istek: benzersiz indeks ikincisini reddetti
        }
    }

    // ------------------------------------------------------------------ onboarding

    public OnboardingResponse onboard(Long userId, OnboardingRequest r) {
        User current = load(userId);
        if (current.isProfileCompleted()) {
            // Idempotent: tamamlanmis profil EZILMEZ; ayni sonuc doner
            return new OnboardingResponse(true, ProfileView.of(current));
        }
        // ---- dogrulama (yazmadan ONCE; hata alan hicbir sey yazmaz)
        String first = collapse(r.firstName());
        String last = collapse(r.lastName());
        requireField("firstName", first);
        requireField("lastName", last);
        requireMax("firstName", first, PART_MAX);
        requireMax("lastName", last, PART_MAX);
        String displayName = DisplayNamePolicy.normalize(first + " " + last, false);
        ContentGuard.clean(guard, Entity.PROFILE, "displayName", userId, displayName);

        UsernamePolicy.Checked u = requireUsable(userId, r.username());

        String universityIn = collapse(r.universityName());
        boolean bingol = universityIn == null || isBingol(universityIn);
        final String university = universityIn == null ? DEFAULT_UNIVERSITY : universityIn;
        requireMax("universityName", university, 120);
        if (!bingol) {
            ContentGuard.clean(guard, Entity.PROFILE, "universityName", userId, university);
        }

        Academic a = resolveAcademic(r, bingol, userId);

        String bio = r.bio() == null || r.bio().isBlank() ? null : r.bio().trim();
        if (bio != null) {
            requireMax("bio", bio, BIO_MAX);
            ContentGuard.clean(guard, Entity.PROFILE, "bio", userId, bio);
        }
        boolean recordTerms = requireTerms(userId, r.acceptTerms());

        try {
            OnboardingResponse res = tx.call(() -> {
                User user = load(userId);
                if (user.isProfileCompleted()) {
                    return new OnboardingResponse(true, ProfileView.of(user)); // yaris: baska istek tamamladi
                }
                user.setFirstName(first);
                user.setLastName(last);
                user.setDisplayName(displayName);
                user.setUsername(u.username());
                user.setUsernameSetAt(Instant.now());
                user.setUniversityName(university);
                user.setFaculty(a.faculty());
                user.setDepartment(a.department());
                user.setGrade(a.grade());
                user.setClassYear(a.classYear());
                user.setBio(bio);
                user.setProfileCompletedAt(Instant.now());
                User saved = users.saveAndFlush(user);
                if (recordTerms) {
                    legal.recordSignupConsent(userId);
                }
                return new OnboardingResponse(true, ProfileView.of(saved));
            });
            joinDepartmentChat(userId);
            return res;
        } catch (DataIntegrityViolationException race) {
            throw taken(); // eszamanli iki kisi ayni kullanici adini aldi: benzersiz indeks ikincisini reddetti
        }
    }

    // ------------------------------------------------------------------ yardimcilar

    private UsernamePolicy.Checked requireUsable(Long userId, String raw) {
        UsernamePolicy.Checked c = UsernamePolicy.check(raw);
        if (c.result() == UsernamePolicy.Result.INVALID) {
            throw new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "USERNAME_INVALID",
                    "Kullanıcı adı geçersiz.", "username");
        }
        if (c.result() == UsernamePolicy.Result.RESERVED) {
            throw new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "USERNAME_RESERVED",
                    "Bu kullanıcı adı kullanılamaz.", "username");
        }
        ContentGuard.clean(guard, Entity.PROFILE, "username", userId, c.username().replace('.', ' ').replace('_', ' '));
        User other = users.findByUsername(c.username()).orElse(null);
        if (other != null && !other.getId().equals(userId)) {
            throw taken();
        }
        return c;
    }

    private static ApiException taken() {
        return new FieldApiException(HttpStatus.CONFLICT, "USERNAME_TAKEN", "Bu kullanıcı adı alınmış.", "username");
    }

    /** Sozlesme kosulu: acceptTerms=true ise onay yazilacak (true doner); degilse bekleyen onay kalmamis olmali. */
    private boolean requireTerms(Long userId, Boolean acceptTerms) {
        if (!props.requireTermsConsent() || legal == null) {
            return false;
        }
        if (Boolean.TRUE.equals(acceptTerms)) {
            return true;
        }
        if (!legal.pending(userId, Lang.of(LocaleContextHolder.getLocale())).isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TERMS_REQUIRED",
                    "Devam etmek için kullanım koşullarını ve gizlilik metnini kabul etmelisiniz.");
        }
        return false;
    }

    private User load(Long userId) {
        return users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
    }

    private record Academic(String faculty, String department, String grade, Short classYear) {
    }

    private Academic resolveAcademic(OnboardingRequest r, boolean bingol, Long userId) {
        String grade;
        Short classYear;
        switch (r.classYear()) {
            case "PREP" -> {
                grade = "PREP";
                classYear = 0;
            }
            case "POSTGRAD", "MASTER" -> {
                grade = "MASTER";
                classYear = null;
            }
            case "PHD" -> {
                grade = "PHD";
                classYear = null;
            }
            case "OTHER" -> {
                grade = null;
                classYear = null;
            }
            default -> { // Y1..Y6 (desen dogrulandi)
                int n = r.classYear().charAt(1) - '0';
                grade = String.valueOf(n);
                classYear = (short) n;
            }
        }
        boolean required = !"OTHER".equals(r.classYear());
        String facultyIn = firstNonBlank(r.facultyId(), r.facultyName());
        String deptIn = firstNonBlank(r.departmentId(), r.departmentName());
        if (!bingol) {
            // Baska universite: Bingol katalogu anlamsiz; serbest metin (sinirli, uygunsuz ifade denetimli)
            String f = collapse(r.facultyName());
            String d = collapse(r.departmentName());
            requireMax("faculty", f, 120);
            requireMax("department", d, 120);
            ContentGuard.clean(guard, Entity.PROFILE, "faculty", userId, f);
            ContentGuard.clean(guard, Entity.PROFILE, "department", userId, d);
            return new Academic(f, d, grade, classYear);
        }
        if (facultyIn == null) {
            if (required) {
                throw new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PROFILE_FIELD_REQUIRED",
                        "Bu alan zorunlu.", "faculty");
            }
            if (deptIn != null) {
                throw academicInvalid();
            }
            return new Academic(null, null, grade, classYear);
        }
        Faculty faculty = findFaculty(r.facultyId(), r.facultyName());
        if (faculty == null) {
            throw academicInvalid();
        }
        String department = null;
        if (deptIn == null) {
            if (required) {
                throw new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PROFILE_FIELD_REQUIRED",
                        "Bu alan zorunlu.", "department");
            }
        } else {
            Department d = findDepartment(faculty, r.departmentId(), r.departmentName());
            if (d == null) {
                throw academicInvalid();
            }
            department = d.name();
        }
        return new Academic(faculty.name(), department, grade, classYear);
    }

    private static ApiException academicInvalid() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ACADEMIC_INVALID",
                "Fakülte, bölüm veya sınıf bilgisi geçersiz.");
    }

    private Faculty findFaculty(String id, String name) {
        for (Faculty f : catalog.catalog().faculties()) {
            if (notBlank(id) ? id.trim().equals(f.id()) : sameName(name, f.name(), f.nameEn(), f.nameAr())) {
                return f;
            }
        }
        return null;
    }

    private static Department findDepartment(Faculty f, String id, String name) {
        for (Department d : f.departments()) {
            if (notBlank(id) ? id.trim().equals(d.id()) : sameName(name, d.name(), d.nameEn(), d.nameAr())) {
                return d;
            }
        }
        return null;
    }

    private static boolean sameName(String input, String... names) {
        if (!notBlank(input)) {
            return false;
        }
        String x = fold(input);
        for (String n : names) {
            if (n != null && fold(n).equals(x)) {
                return true;
            }
        }
        return false;
    }

    /** Turkce i/I/İ/ı esitlenir, aksanlar atilir, kucuk harfe cevrilir (CatalogService.fold ile ayni mantik). */
    static String fold(String s) {
        String t = s.trim().replace('İ', 'i').replace('I', 'i').replace('ı', 'i');
        t = Normalizer.normalize(t.toLowerCase(Locale.ROOT), Normalizer.Form.NFD);
        return t.replaceAll("\\p{M}+", "");
    }

    static boolean isBingol(String university) {
        return fold(university).contains("bingol");
    }

    private static String firstNonBlank(String a, String b) {
        return notBlank(a) ? a : notBlank(b) ? b : null;
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }

    /** NFC + bosluk sadelestirme; bos ise null. */
    static String collapse(String s) {
        if (s == null) {
            return null;
        }
        String t = Normalizer.normalize(s, Normalizer.Form.NFC).trim().replaceAll("\\s+", " ");
        return t.isEmpty() ? null : t;
    }

    private static void requireField(String field, String value) {
        if (value == null) {
            throw new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PROFILE_FIELD_REQUIRED", "Bu alan zorunlu.", field);
        }
    }

    /** Kod noktasi sayisi siniri; asilirsa 400 PROFILE_FIELD_TOO_LONG ({0} = sinir). */
    private static void requireMax(String field, String value, int max) {
        if (value != null && value.codePointCount(0, value.length()) > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PROFILE_FIELD_TOO_LONG",
                    field + " en fazla " + max + " karakter olabilir.", String.valueOf(max));
        }
    }
}
