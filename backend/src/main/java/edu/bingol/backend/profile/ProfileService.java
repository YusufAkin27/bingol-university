package edu.bingol.backend.profile;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.media.StoredImage;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEventRepository;
import org.springframework.data.redis.core.StringRedisTemplate;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.naming.DisplayNamePolicy;
import edu.bingol.backend.profile.privacy.AvatarCleanups;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UpdateProfileRequest;
import edu.bingol.backend.profile.dto.ProfileDtos.UserSearchResult;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ProfileService {

    private static final int MIN_QUERY = 2;
    private static final int MAX_SEARCH_SIZE = 20;
    static final int MAX_SEARCH_OFFSET = 200;

    private final UserRepository users;
    private final BlockService blocks;
    private final MediaService media;
    private final PasswordEncoder encoder;
    private final AppInfoService appInfo;
    private final ActivityRepository activity;
    private final PublicProfileMapper mapper;
    private final AvatarCleanups avatarCleanups;
    private final EventRsvpRepository rsvps;
    private final UserEventRepository events;
    private final StringRedisTemplate redis;
    private final AccountDataPurger purger;
    private final CatalogService catalog;

    public ProfileService(UserRepository users, BlockService blocks, MediaService media, PasswordEncoder encoder,
                          AppInfoService appInfo, ActivityRepository activity, PublicProfileMapper mapper,
                          AvatarCleanups avatarCleanups, EventRsvpRepository rsvps, UserEventRepository events,
                          StringRedisTemplate redis, AccountDataPurger purger, CatalogService catalog) {
        this.catalog = catalog;
        this.purger = purger;
        this.mapper = mapper;
        this.avatarCleanups = avatarCleanups;
        this.rsvps = rsvps;
        this.events = events;
        this.redis = redis;
        this.appInfo = appInfo;
        this.activity = activity;
        this.users = users;
        this.blocks = blocks;
        this.media = media;
        this.encoder = encoder;
    }

    public User get(Long id) {
        return users.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
    }

    /** Baskasinin profili: silinmis/askidaki hesaplar ve engel iliskisi olanlar bulunamaz. */
    public PublicProfile publicProfile(Long viewerId, Long targetId) {
        User u = get(targetId);
        if (!u.isActive()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (!viewerId.equals(targetId) && blocks.isBlocked(viewerId, targetId)) {
            // Golge engel: 404 degil; sohbet gecmisinde ad gerekebilir. Tek tutarli "bos profil" (foto/bilgi/e-posta yok)
            return new PublicProfile(u.getId(), u.getDisplayName(), null, null, null, null, null, null);
        }
        PublicProfile view = mapper.map(viewerId, u);
        // Kendi e-postam showEmail ayarindan bagimsiz gorunur
        return viewerId.equals(targetId) ? withEmail(view, u.getEmail()) : view;
    }

    private static PublicProfile withEmail(PublicProfile p, String email) {
        return new PublicProfile(p.id(), p.displayName(), p.faculty(), p.department(), p.classYear(), p.bio(),
                p.avatarUrl(), email);
    }

    @Transactional
    public User update(Long id, UpdateProfileRequest r) {
        User u = get(id);
        if (r.displayName() != null) {
            u.setDisplayName(DisplayNamePolicy.normalize(r.displayName(), u.getRole() == Role.ADMIN));
        }
        // Akademik alanlar yazilirken katalogla dogrulanir; eski serbest metin degerlere dokunulmaz
        String newFaculty = r.faculty() != null ? blankToNull(r.faculty()) : null;
        String newDepartment = r.department() != null ? blankToNull(r.department()) : null;
        String newGrade = r.grade() != null ? blankToNull(r.grade()) : null;
        catalog.requireValid(newFaculty, null, newGrade);
        if (newDepartment != null) {
            catalog.requireValid(newFaculty != null ? newFaculty : u.getFaculty(), newDepartment, null);
        }
        if (r.grade() != null) {
            u.setGrade(newGrade);
        }
        if (r.faculty() != null) {
            u.setFaculty(validFaculty(blankToNull(r.faculty()), appInfo.faculties()));
        }
        if (r.department() != null) {
            u.setDepartment(blankToNull(r.department()));
        }
        if (r.classYear() != null) {
            u.setClassYear(r.classYear());
        }
        if (r.bio() != null) {
            u.setBio(blankToNull(r.bio()));
        }
        if (r.showEmail() != null) {
            u.setShowEmail(r.showEmail());
        }
        if (r.language() != null) {
            u.setLanguage(r.language());
        }
        return users.save(u);
    }

    /** Avatar medya hattindan gecer (dogrula, EXIF temizle, 512 px, sikistir); eski dosya serbest birakilir. */
    @Transactional
    public User setAvatar(Long id, MultipartFile file) {
        User u = get(id);
        StoredImage img = media.storeImage(file, ImageKind.AVATAR);
        String old = u.getAvatarUrl();
        u.setAvatarUrl(img.url());
        users.saveAndFlush(u);
        if (old != null && !old.equals(img.url())) {
            media.release(old);
        }
        return u;
    }

    /** Avatari kaldirir (yoksa sessizce basarili); profil bas harf avatarina duser. */
    @Transactional
    public User removeAvatar(Long id) {
        User u = get(id);
        String old = u.getAvatarUrl();
        u.setAvatarUrl(null);
        users.saveAndFlush(u);
        media.release(old);
        return u;
    }

    /** En az 2 harfli arama; kendisi, engel iliskisi olanlar, askidaki ve silinmis hesaplar donmez. */
    public UserSearchResult search(Long viewerId, String q, int size, Long cursor) {
        String query = q == null ? "" : q.trim();
        if (query.codePointCount(0, query.length()) < MIN_QUERY) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "QUERY_TOO_SHORT", "En az 2 karakter girin.");
        }
        int offset = searchOffset(cursor);
        int limit = Math.min(Math.max(size, 1), MAX_SEARCH_SIZE);
        Set<Long> excluded = new HashSet<>(blocks.hiddenFrom(viewerId));
        excluded.add(viewerId);
        excluded.add(-1L); // NOT IN () bos kalmasin
        // limit+1: devam olup olmadigini ek sorgu olmadan anlamak icin
        List<User> rows = users.searchByName(escapeLike(query), excluded, limit + 1, offset);
        boolean more = rows.size() > limit && offset + limit <= MAX_SEARCH_OFFSET;
        List<User> page = rows.size() > limit ? rows.subList(0, limit) : rows;
        return new UserSearchResult(mapper.mapAll(viewerId, page), more ? (long) offset + limit : null);
    }

    /** Imlec = atlanacak kayit sayisi; ust sinir toplu taramayi (kullanici dizinini dokmeyi) zorlastirir. */
    private static int searchOffset(Long cursor) {
        if (cursor == null) {
            return 0;
        }
        if (cursor < 0 || cursor > MAX_SEARCH_OFFSET) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sayfa imleci.");
        }
        return cursor.intValue();
    }

    /**
     * Hesap silme (KVKK): kisisel veriler anonimlestirilir, hesap DELETED olur ve giris/yenileme kapanir.
     * Satir silinmez: baskalarinin mesaj/topluluk gecmisi referans butunlugunu korur.
     */
    @Transactional
    public void deleteAccount(Long id, String password) {
        User u = get(id);
        if (!encoder.matches(password, u.getPasswordHash())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "WRONG_PASSWORD", "Şifre hatalı.");
        }
        anonymize(u);
    }

    /** Parolasiz anonimlestirme: yonetici silme akisi da ayni mantigi kullanir (parola kontrolu cagirana aittir). */
    @Transactional
    public void anonymizeAccount(Long id) {
        anonymize(get(id));
    }

    private void anonymize(User u) {
        String oldAvatar = u.getAvatarUrl();
        avatarCleanups.run(u.getId(), oldAvatar); // T11: gorsel referanslari + gizlilik satiri (KVKK)
        u.setEmail("deleted-" + u.getId() + "@deleted.invalid");
        u.setDisplayName("Silinmiş kullanıcı");
        u.setPasswordHash(encoder.encode(java.util.UUID.randomUUID().toString()));
        u.setDepartment(null);
        u.setFaculty(null);
        u.setClassYear(null);
        u.setGrade(null);
        u.setBio(null);
        u.setAvatarUrl(null);
        u.setShowEmail(false);
        u.setStatus(UserStatus.DELETED);
        u.setDeletedAt(Instant.now());
        users.saveAndFlush(u);
        media.release(oldAvatar);
        // KVKK: kullanim izleri (gunluk acilis, olaylar) de silinir
        activity.purgeUser(u.getId());
        // KVKK: cihaz/FCM, bildirim kutusu ve tercihleri, kayitli haberler, kulup yanitlari, uyelikler
        purger.purge(u.getId());
        // Silinen kullanicinin RSVP'leri kapasiteden yer tutmasin
        for (EventRsvp r : rsvps.findByUserId(u.getId())) {
            if (r.getStatus() == EventRsvp.Status.GOING) {
                events.decrementGoing(r.getEventId());
            }
            rsvps.delete(r);
        }
        // Eldeki access token'lar aninda gecersiz olsun (askiya almadaki mekanizma)
        redis.opsForValue().set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + u.getId(), "1");
    }

    public List<String> faculties() {
        return appInfo.faculties();
    }

    public List<String> departments() {
        return users.distinctDepartments();
    }

    /** Fakulte listesi tanimliysa deger listeden biri olmali; liste bos ise serbest metin kabul edilir. */
    static String validFaculty(String value, List<String> allowed) {
        if (value != null && !allowed.isEmpty() && !allowed.contains(value)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_FACULTY", "Geçersiz fakülte.");
        }
        return value;
    }

    private static String blankToNull(String s) {
        return s.isBlank() ? null : s.trim();
    }

    /** LIKE ozel karakterlerini kacirir (ESCAPE '\'). */
    static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
