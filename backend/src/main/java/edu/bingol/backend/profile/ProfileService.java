package edu.bingol.backend.profile;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ShortTx;
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

    /** Kisa DB islemi (T-068: gorsel isleme islem disinda); yoksa dogrudan calisir (elle kurulan testler). */
    private ShortTx tx = ShortTx.direct();

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTxManager(org.springframework.transaction.PlatformTransactionManager tm) {
        this.tx = ShortTx.of(tm);
    }

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
            // Sayaclar sabit 0/false: null, engelli cift ile normal profili ayirt ettirirdi (T-029).
            return new PublicProfile(u.getId(), u.getDisplayName(), null, null, null, null, null, null)
                    .withFollow(0, 0, false, false)
                    .withBlockedByMe(blocks.hasBlocked(viewerId, targetId));
        }
        PublicProfile view = mapper.map(viewerId, u);
        // Kendi e-postam showEmail ayarindan bagimsiz gorunur
        view = self ? withEmail(view, u.getEmail()) : view;
        view = withFollow(view, viewerId, targetId);
        view = withRelation(view, viewerId, targetId);
        view = withPopularity(view, targetId);
        return self ? view : view.withBlockedByMe(false);
    }

    /** Populerlik puani (post.popularity; yoksa/gizli hesapta kilitliyse alanlar eklenmez). Hata profil yanitini bozmaz. */
    private edu.bingol.backend.post.popularity.UserPopularityService popularity;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPopularity(edu.bingol.backend.post.popularity.UserPopularityService popularity) {
        this.popularity = popularity;
    }

    /** Kendi profilim icin populerlik (GET /users/me); hata/modul yoksa null. */
    public edu.bingol.backend.post.popularity.UserPopularityService.Snapshot popularityOf(Long userId) {
        if (popularity == null) {
            return null;
        }
        try {
            return popularity.of(userId);
        } catch (RuntimeException e) {
            return null;
        }
    }

    private PublicProfile withPopularity(PublicProfile p, Long targetId) {
        if (popularity == null || Boolean.TRUE.equals(p.locked())) {
            return p; // kilitli (gizli) hesapta sayaclar gibi populerlik de gizli
        }
        try {
            edu.bingol.backend.post.popularity.UserPopularityService.Snapshot s = popularity.of(targetId);
            return p.withPopularity(s.score(), s.likesReceived(), s.postCount());
        } catch (RuntimeException e) {
            return p;
        }
    }

    /** Gizli hesap kapisi (post.follow; yoksa alanlar eklenmez). */
    private edu.bingol.backend.post.follow.PrivateAccountGate gate;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setGate(edu.bingol.backend.post.follow.PrivateAccountGate gate) {
        this.gate = gate;
    }

    /** isPrivate / followState / locked (locked iken sayaclar gizlenir). Hata profil yanitini bozmaz. */
    private PublicProfile withRelation(PublicProfile p, Long viewerId, Long targetId) {
        if (gate == null) {
            return p;
        }
        try {
            edu.bingol.backend.post.follow.PrivateAccountGate.Relation r = gate.relation(viewerId, targetId);
            return r == null ? p : p.withRelation(r.isPrivate(), r.followState(), r.locked());
        } catch (RuntimeException e) {
            return p;
        }
    }

    /** Arama satirlari icin toplu iliski (tek turda en cok 3 sorgu). */
    private List<PublicProfile> withRelations(Long viewerId, List<PublicProfile> rows) {
        if (gate == null || rows.isEmpty()) {
            return rows;
        }
        try {
            java.util.Map<Long, edu.bingol.backend.post.follow.PrivateAccountGate.Relation> rel =
                    gate.relations(viewerId, rows.stream().map(PublicProfile::id).toList());
            return rows.stream().map(p -> {
                edu.bingol.backend.post.follow.PrivateAccountGate.Relation r = rel.get(p.id());
                return r == null ? p : p.withRelation(r.isPrivate(), r.followState(), r.locked());
            }).toList();
        } catch (RuntimeException e) {
            return rows;
        }
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
        // T-055: sinirlar KOD NOKTASI ile sayilir (mesaj ve mobil sayac ile ayni); @Size UTF-16 saydigindan 300 emoji reddediliyordu
        requireMaxCodePoints("displayName", r.displayName(), DisplayNamePolicy.MAX_LEN);
        requireMaxCodePoints("faculty", r.faculty(), 120);
        requireMaxCodePoints("department", r.department(), 120);
        requireMaxCodePoints("bio", r.bio(), BIO_MAX);
        User u = get(id);
        if (r.displayName() != null) {
            String newName = DisplayNamePolicy.normalize(r.displayName(), u.getRole() == Role.ADMIN);
            ContentGuard.changed(guard, Entity.PROFILE, "displayName", id, u.getDisplayName(), newName);
            if (!newName.equals(u.getDisplayName()) && !isTemporaryName(u)) {
                // Kayitta atanan gecici ad (profil tamamlama adimi) kotaya/bekleme suresine sayilmaz
                requireNameCooldown(u);
                recordNameChange(u, newName);
            }
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
        // T-055: sinif yili ile sinif (grade) birbirinden bagimsiz guncellenemez: grade verilirse classYear ondan turetilir
        // (cakisan classYear 400 ACADEMIC_INVALID); yalniz classYear verilirse grade ondan turetilir.
        Short newClassYear = r.classYear();
        if (r.grade() != null && newGrade != null) {
            Short derived = classYearOfGrade(newGrade);
            if (newClassYear != null && derived != null && !newClassYear.equals(derived)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "ACADEMIC_INVALID",
                        "Fakülte, bölüm veya sınıf bilgisi geçersiz.");
            }
            u.setClassYear(derived);
            newClassYear = null;
        } else if (newClassYear != null && r.grade() == null) {
            String g = gradeOfClassYear(newClassYear);
            if (g != null) {
                u.setGrade(g);
            }
        }
        if (r.faculty() != null) {
            String oldFaculty = u.getFaculty();
            u.setFaculty(validFaculty(blankToNull(r.faculty()), appInfo.faculties()));
            // T-055: fakulte degisince eski bolum yeni fakulteye ait degilse temizlenir (Muhendislik + Fen-Edebiyat bolumu olmaz)
            if (r.department() == null && u.getDepartment() != null && !java.util.Objects.equals(oldFaculty, u.getFaculty())
                    && (u.getFaculty() == null || !catalog.isValid(u.getFaculty(), u.getDepartment()))) {
                u.setDepartment(null);
            }
        }
        if (r.department() != null) {
            ContentGuard.changed(guard, Entity.PROFILE, "department", id, u.getDepartment(), blankToNull(r.department()));
            u.setDepartment(blankToNull(r.department()));
        }
        if (newClassYear != null) {
            u.setClassYear(newClassYear);
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

    /**
     * Avatar medya hattindan gecer (dogrula, EXIF temizle, 512 px, sikistir); eski dosya serbest birakilir.
     * Gorsel isleme islem DISINDA (T-068): yalniz URL yazimi kisa islemdedir.
     */
    public User setAvatar(Long id, MultipartFile file) {
        get(id); // yoksa gorsel islenmeden 404
        StoredImage img = media.storeImage(file, ImageKind.AVATAR);
        ShortTx.Replaced<User> r = tx.call(() -> {
            User u = get(id);
            String old = u.getAvatarUrl();
            u.setAvatarUrl(img.url());
            users.saveAndFlush(u);
            return new ShortTx.Replaced<>(u, old);
        });
        if (r.old() != null && !r.old().equals(img.url())) {
            media.release(r.old());
        }
        return r.value();
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
        return new UserSearchResult(withRelations(viewerId, mapper.mapAll(viewerId, page)),
                more ? (long) offset + limit : null);
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
        // Hakkinda acik sikayet varsa silme 7 gun bekler (T-058): sikayet yaptirimdan kacmak icin silme kullanilamaz.
        if (ledger != null) {
            ledger.requireDeletionAllowed(u.getId());
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

    /** Gorunen ad gecmisi (T-060, istege bagli: birim testlerinde yok). */
    private DisplayNameChangeRepository nameHistory;
    /** Ihlal defteri + silme bekletmesi (T-058, istege bagli). */
    private edu.bingol.backend.moderation.ViolationLedgerService ledger;
    /** Iki gorunen ad degisimi arasindaki en kisa sure (gun); 0 = sinirsiz. */
    @org.springframework.beans.factory.annotation.Value("${app.profile.display-name-cooldown-days:7}")
    private int nameCooldownDays = 7;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setNameHistory(DisplayNameChangeRepository nameHistory) {
        this.nameHistory = nameHistory;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setLedger(edu.bingol.backend.moderation.ViolationLedgerService ledger) {
        this.ledger = ledger;
    }

    /** Raporlanan kisinin adi surekli degisip iz kaybettirmesin: son degisimden bu yana N gun gecmeli. */
    /** Gecici ad (kayitta verilmedi) hic degistirilmemisse: ilk gercek ad atamasi bekleme suresi baslatmaz. */
    private boolean isTemporaryName(User u) {
        String cur = u.getDisplayName();
        if (cur == null || nameHistory == null) {
            return false;
        }
        boolean temp = cur.equals(DisplayNamePolicy.TEMPORARY_NAME) || cur.equals(DisplayNamePolicy.temporaryFor(u.getEmail()));
        return temp && nameHistory.findFirstByUserIdOrderByChangedAtDesc(u.getId()).isEmpty();
    }

    private void requireNameCooldown(User u) {
        if (nameHistory == null || nameCooldownDays <= 0) {
            return;
        }
        nameHistory.findFirstByUserIdOrderByChangedAtDesc(u.getId()).ifPresent(last -> {
            Instant next = last.getChangedAt().plus(java.time.Duration.ofDays(nameCooldownDays));
            if (next.isAfter(Instant.now())) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "DISPLAY_NAME_COOLDOWN",
                        "Görünen adınızı " + nameCooldownDays + " günde bir değiştirebilirsiniz.",
                        String.valueOf(nameCooldownDays));
            }
        });
    }

    private void recordNameChange(User u, String newName) {
        if (nameHistory == null) {
            return;
        }
        DisplayNameChange c = new DisplayNameChange();
        c.setUserId(u.getId());
        c.setOldName(u.getDisplayName());
        c.setNewName(newName);
        nameHistory.save(c);
    }

    /** Parolasiz anonimlestirme: yonetici silme akisi da ayni mantigi kullanir (parola kontrolu cagirana aittir). */
    @Transactional
    public void anonymizeAccount(Long id) {
        anonymize(get(id));
    }

    private void anonymize(User u) {
        // Ihlal defteri (T-058): e-posta degismeden ONCE ozet + strike sayisi; ad gecmisi silinir (KVKK)
        if (ledger != null) {
            ledger.recordOnDeletion(u.getId(), u.getEmail(), u.getStatus());
        }
        if (nameHistory != null) {
            nameHistory.deleteByUser(u.getId());
        }
        // Eski adres anonimlestirmeden ONCE alinir: mail kuyrugunda adresle eslesen bekleyen kayitlar silinir (W2-F)
        String oldEmail = u.getEmail();
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
        purger.purge(u.getId(), oldEmail);
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
    /** Profil biyografisi ust siniri (kod noktasi). */
    static final int BIO_MAX = 300;

    /** Kod noktasi sayisi siniri asilirsa 400 PROFILE_FIELD_TOO_LONG (istek dilinde; {0} = sinir). null/kisa sorun degil. */
    static void requireMaxCodePoints(String field, String value, int max) {
        if (value != null && value.codePointCount(0, value.length()) > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PROFILE_FIELD_TOO_LONG",
                    field + " en fazla " + max + " karakter olabilir.", String.valueOf(max));
        }
    }

    /** Sinif kimliginden sinif yili: PREP=0, "1".."6"=n, yuksek lisans/doktora=null. */
    static Short classYearOfGrade(String grade) {
        if ("PREP".equals(grade)) {
            return 0;
        }
        return grade.length() == 1 && grade.charAt(0) >= '1' && grade.charAt(0) <= '6'
                ? Short.valueOf((short) (grade.charAt(0) - '0')) : null;
    }

    /** Sinif yilindan sinif kimligi (0=PREP, 1..6); digerlerinde null (grade degismez). */
    static String gradeOfClassYear(short classYear) {
        if (classYear == 0) {
            return "PREP";
        }
        return classYear >= 1 && classYear <= 6 ? String.valueOf(classYear) : null;
    }

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
