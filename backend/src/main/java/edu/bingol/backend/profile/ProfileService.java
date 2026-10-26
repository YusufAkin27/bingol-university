package edu.bingol.backend.profile;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.media.StoredImage;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UpdateProfileRequest;
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

    private final UserRepository users;
    private final BlockService blocks;
    private final MediaService media;
    private final PasswordEncoder encoder;
    private final AppInfoService appInfo;
    private final ActivityRepository activity;

    public ProfileService(UserRepository users, BlockService blocks, MediaService media, PasswordEncoder encoder,
                          AppInfoService appInfo, ActivityRepository activity) {
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
        if (!u.isActive() || (!viewerId.equals(targetId) && blocks.isBlocked(viewerId, targetId))) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        return PublicProfile.of(u);
    }

    @Transactional
    public User update(Long id, UpdateProfileRequest r) {
        User u = get(id);
        if (r.displayName() != null) {
            u.setDisplayName(r.displayName().trim());
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
    public List<PublicProfile> search(Long viewerId, String q, int size) {
        String query = q == null ? "" : q.trim();
        if (query.length() < MIN_QUERY) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "QUERY_TOO_SHORT", "En az 2 karakter girin.");
        }
        Set<Long> excluded = new HashSet<>(blocks.hiddenFrom(viewerId));
        excluded.add(viewerId);
        excluded.add(-1L); // NOT IN () bos kalmasin
        return users.searchByName(escapeLike(query), excluded, Math.min(Math.max(size, 1), 20)).stream()
                .map(PublicProfile::of).toList();
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
        u.setEmail("deleted-" + u.getId() + "@deleted.invalid");
        u.setDisplayName("Silinmiş kullanıcı");
        u.setPasswordHash(encoder.encode(java.util.UUID.randomUUID().toString()));
        u.setDepartment(null);
        u.setFaculty(null);
        u.setClassYear(null);
        u.setBio(null);
        u.setAvatarUrl(null);
        u.setShowEmail(false);
        u.setStatus(UserStatus.DELETED);
        u.setDeletedAt(Instant.now());
        users.saveAndFlush(u);
        media.release(oldAvatar);
        // KVKK: kullanim izleri (gunluk acilis, olaylar) de silinir
        activity.purgeUser(u.getId());
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
