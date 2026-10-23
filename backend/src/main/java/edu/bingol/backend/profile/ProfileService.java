package edu.bingol.backend.profile;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
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

    private static final Set<String> IMAGE_TYPES = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long AVATAR_MAX_BYTES = 2L * 1024 * 1024;
    private static final int MIN_QUERY = 2;

    private final UserRepository users;
    private final BlockService blocks;
    private final FileStorage storage;
    private final PasswordEncoder encoder;

    public ProfileService(UserRepository users, BlockService blocks, FileStorage storage, PasswordEncoder encoder) {
        this.users = users;
        this.blocks = blocks;
        this.storage = storage;
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
        return users.save(u);
    }

    @Transactional
    public User setAvatar(Long id, MultipartFile file) {
        User u = get(id);
        String url = storage.save("avatars", file, IMAGE_TYPES, AVATAR_MAX_BYTES);
        String old = u.getAvatarUrl();
        u.setAvatarUrl(url);
        users.save(u);
        storage.delete(old);
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
        storage.delete(u.getAvatarUrl());
        u.setEmail("deleted-" + u.getId() + "@deleted.invalid");
        u.setDisplayName("Silinmiş kullanıcı");
        u.setPasswordHash(encoder.encode(java.util.UUID.randomUUID().toString()));
        u.setDepartment(null);
        u.setClassYear(null);
        u.setBio(null);
        u.setAvatarUrl(null);
        u.setShowEmail(false);
        u.setStatus(UserStatus.DELETED);
        u.setDeletedAt(Instant.now());
        users.save(u);
    }

    public List<String> departments() {
        return users.distinctDepartments();
    }

    private static String blankToNull(String s) {
        return s.isBlank() ? null : s.trim();
    }

    /** LIKE ozel karakterlerini kacirir (ESCAPE '\'). */
    static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
