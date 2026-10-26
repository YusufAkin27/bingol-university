package edu.bingol.backend.profile;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.dto.ProfileDtos.DeleteAccountRequest;
import edu.bingol.backend.profile.dto.ProfileDtos.ProfileView;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UpdateProfileRequest;
import edu.bingol.backend.profile.dto.ProfileDtos.UserSearchResult;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api")
public class ProfileController {

    static final int DAILY_SEARCH_QUOTA = 500;

    private final ProfileService profiles;
    private final RateLimiter limiter;

    public ProfileController(ProfileService profiles, RateLimiter limiter) {
        this.profiles = profiles;
        this.limiter = limiter;
    }

    @GetMapping("/users/me")
    public ProfileView me() {
        return ProfileView.of(profiles.get(CurrentUser.id()));
    }

    @PatchMapping("/users/me")
    public ProfileView update(@Valid @RequestBody UpdateProfileRequest r) {
        return ProfileView.of(profiles.update(CurrentUser.id(), r));
    }

    /** multipart alani "file"; jpg/png/webp kabul, 512 px JPEG/PNG'ye yeniden kodlanir (app.media.avatar.*). */
    @PostMapping("/users/me/avatar")
    public ProfileView avatar(@RequestParam("file") MultipartFile file) {
        Long uid = CurrentUser.id();
        limiter.check("avatar:user:" + uid, 10, Duration.ofHours(1));
        return ProfileView.of(profiles.setAvatar(uid, file));
    }

    /** Avatari kaldirir (idempotent); eski dosya baska yerde kullanilmiyorsa silinir. */
    @DeleteMapping("/users/me/avatar")
    public ProfileView removeAvatar() {
        Long uid = CurrentUser.id();
        limiter.check("avatar:user:" + uid, 10, Duration.ofHours(1));
        return ProfileView.of(profiles.removeAvatar(uid));
    }

    @DeleteMapping("/users/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAccount(@Valid @RequestBody DeleteAccountRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("delete-account:user:" + uid, 5, Duration.ofHours(1));
        profiles.deleteAccount(uid, r.password());
    }

    @GetMapping("/users/search")
    public UserSearchResult search(@RequestParam String q, @RequestParam(defaultValue = "20") int size,
                                   @RequestParam(required = false) Long cursor) {
        Long uid = CurrentUser.id();
        limiter.check("user-search:user:" + uid, 60, Duration.ofMinutes(1));
        // Gunluk kota: kullanici dizinini toplu taramayi pahalilastirir
        limiter.check("user-search-day:user:" + uid, DAILY_SEARCH_QUOTA, Duration.ofDays(1));
        return profiles.search(uid, q, size, cursor);
    }

    @GetMapping("/users/{id}")
    public PublicProfile get(@PathVariable Long id) {
        return profiles.publicProfile(CurrentUser.id(), id);
    }

    /** Herkese acik fakulte listesi (yonetici `faculties` ayarindan; bos olabilir). */
    @GetMapping("/faculties")
    public List<String> faculties() {
        return profiles.faculties();
    }

    /** Profil formunda otomatik tamamlama icin sistemde kullanilan bolum adlari. */
    @GetMapping("/departments")
    public List<String> departments() {
        return profiles.departments();
    }
}
