package edu.bingol.backend.profile;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
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

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

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
        boolean self = viewerId.equals(targetId);
        if (!self && blocks.isBlocked(viewerId, targetId)) {
            // Golge engel: 404 degil; sohbet gecmisinde ad gerekebilir. Tek tutarli "bos profil" (foto/bilgi/e-posta yok).
            // blockedByMe yalniz benim engelimi gosterir; karsi tarafin beni engellemesi sizdirilmaz (false).
            return new PublicProfile(u.getId(), u.getDisplayName(), null, null, null, null, null, null)
                    .withBlockedByMe(blocks.hasBlocked(viewerId, targetId));
        }
        PublicProfile view = mapper.map(viewerId, u);
        // Kendi e-postam showEmail ayarindan bagimsiz gorunur
        view = self ? withEmail(view, u.getEmail()) : view;
        view = withFollow(view, viewerId, targetId);
        return self ? view : view.withBlockedByMe(false);
    }

    private static PublicProfile withEmail(PublicProfile p, String email) {
        return new PublicProfile(p.id(), p.displayName(), p.faculty(), p.department(), p.classYear(), p.bio(),
                p.avatarUrl(), email);
    }

    /** Takip sayaclari (post.follow; modul yoksa alanlar null kalir). */
    private edu.bingol.backend.post.follow.FollowService followService;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setFollowService(edu.bingol.backend.post.follow.FollowService followService) {
        this.followService = followService;
    }

    private PublicProfile withFollow(PublicProfile p, Long viewerId, Long targetId) {
        if (followService == null) {
            return p;
        }
        try {
            edu.bingol.backend.post.follow.FollowService.Stats s = followService.stats(viewerId, targetId);
            return p.withFollow(s.followerCount(), s.followingCount(), s.followedByMe(), s.followsMe());
        } catch (RuntimeException e) {
            return p; // sayaclar profil yanitini asla bozmaz
        }
    }

    @Transactional
    public User update(Long id, UpdateProfileRequest r) {
        User u = get(id);
        if (r.displayName() != null) {
            String newName = DisplayNamePolicy.normalize(r.displayName(), u.getRole() == Role.ADMIN);
            ContentGuard.changed(guard, Entity.PROFILE, "displayName", id, u.getDisplayName(), newName);
            u.setDisplayName(newName);
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
            ContentGuard.changed(guard, Entity.PROFILE, "department", id, u.getDepartment(), blankToNull(r.department()));
            u.setDepartment(blankToNull(r.department()));
        }
        if (r.classYear() != null) {
            u.setClassYear(r.classYear());
        }
        if (r.bio() != null) {
            ContentGuard.changed(guard, Entity.PROFILE, "bio", id, u.getBio(), blankToNull(r.bio()));
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
        // Yonetici kendini silemez (T-002): once baska bir yonetici rolunu dusurmeli (panelde son yonetici/son FULL
        // korumasi orada isler); ADMIN_EMAILS hesaplari rol dusurulemedigi icin hic silemez.
        if (u.getRole() == Role.ADMIN || (adminProps != null && adminProps.isAdminEmail(u.getEmail()))) {
            throw new ApiException(HttpStatus.CONFLICT, "ADMIN_CANNOT_SELF_DELETE",
                    "Yönetici hesabı kendi kendini silemez; önce başka bir yönetici rolünüzü kaldırmalıdır.");
        }
        anonymize(u);
    }

    /** Yapilandirilmis yonetici adresleri (istege bagli: birim testlerinde yok). */
    private edu.bingol.backend.config.AdminProperties adminProps;
    /** Oturum iptali (istege bagli: birim testlerinde yok). */
    private edu.bingol.backend.auth.token.SessionService sessions;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAdminProperties(edu.bingol.backend.config.AdminProperties adminProps) {
        this.adminProps = adminProps;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSessions(edu.bingol.backend.auth.token.SessionService sessions) {
        this.sessions = sessions;
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
        // Silinen hesapta yonetici yetkisi kalmasin (T-002): panelden/yanlis geri aciliste bile rol tasinmaz.
        u.setRole(Role.USER);
        u.setAdminProfile(null);
        u.setStatus(UserStatus.DELETED);
        u.setDeletedAt(Instant.now());
        users.saveAndFlush(u);
        media.release(oldAvatar);
        // KVKK: kullanim izleri (gunluk acilis, olaylar) de silinir
        activity.purgeUser(u.getId());
        // KVKK: cihaz/FCM, bildirim kutusu ve tercihleri, kayitli haberler, kulup yanitlari, uyelikler
        purger.purge(u.getId());
        // Silinen kullanicinin RSVP'leri kapasiteden yer tutmasin
        List<Long> freedEvents = new java.util.ArrayList<>();
        for (EventRsvp r : rsvps.findByUserId(u.getId())) {
            if (r.getStatus() == EventRsvp.Status.GOING) {
                events.decrementGoing(r.getEventId());
                freedEvents.add(r.getEventId());
            }
            rsvps.delete(r);
        }
        // Eldeki access token'lar aninda gecersiz olsun (askiya almadaki mekanizma) + refresh oturumlari kapansin.
        // COMMIT SONRASI: islem geri alinirsa hesap yanlisla kilitli kalmaz (T-009); refresh kumesi (rtu:<id>) temizlenir.
        Long uid = u.getId();
        edu.bingol.backend.common.AfterCommit.run(() -> {
            redis.opsForValue().set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + uid, "1");
            if (sessions != null) {
                sessions.revokeAll(uid);
            }
        });
        // Sahipsiz kulup, yetim basvuru/bekleme listesi, gonderi gorselleri: commit sonrasi dinleyicilerde
        if (publisher != null) {
            publisher.publishEvent(new UserAccountDeletedEvent(u.getId(), List.copyOf(freedEvents)));
        }
    }

    /** Hesap silme sonrasi toparlayicilar (testlerde yoksa atlanir). */
    private org.springframework.context.ApplicationEventPublisher publisher;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPublisher(org.springframework.context.ApplicationEventPublisher publisher) {
        this.publisher = publisher;
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
